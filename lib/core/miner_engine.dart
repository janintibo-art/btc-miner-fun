import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'bitcoin_utils.dart';
import 'hash_mode.dart';
import 'nonce_walker.dart';
import 'sha256_fast.dart';
import 'stratum_job.dart';

/// Le moteur repartit le travail sur plusieurs isolates : un par coeur
/// demande. Chacun explore les nonces avec un pas different, ils ne se
/// marchent donc jamais dessus.
class MinerEngine {
  final List<Isolate> _isolates = <Isolate>[];
  final Map<int, SendPort> _ports = <int, SendPort>{};
  final Map<int, int> _totals = <int, int>{};
  final Map<int, double> _rates = <int, double>{};
  ReceivePort? _rx;
  Completer<void>? _ready;
  int _workerCount = 1;
  int _intensity = 100;
  HashMode _mode = HashMode.midstate;
  NonceStrategy _strategy = NonceStrategy.signature;
  int _observeBits = 24;
  NonceSignature _signature = NonceSignature.fromPhrase('btc-miner-fun');

  void Function(double hashrate, int totalHashes)? onStats;
  void Function(FoundShare share)? onShare;

  /// Tentative remarquable mais insuffisante pour le pool : (difficulte, nonce).
  void Function(double difficulty, int nonce)? onSighting;

  /// Dernier nonce essaye, pour l'affichage en direct du decodeur d'en-tete.
  void Function(int nonce)? onNonce;

  int get workerCount => _workerCount;
  bool get isStarted => _isolates.isNotEmpty;

  HashMode get mode => _mode;

  NonceStrategy get strategy => _strategy;

  void configureWalk(NonceStrategy strategy, NonceSignature signature) {
    _strategy = strategy;
    _signature = signature;
  }

  Future<void> start(int workers, {HashMode mode = HashMode.midstate}) async {
    _mode = mode;
    if (_isolates.isNotEmpty) return;
    _workerCount = workers.clamp(1, 16);
    _totals.clear();
    _rates.clear();

    final ready = Completer<void>();
    _ready = ready;
    final rx = ReceivePort();
    _rx = rx;

    rx.listen((msg) {
      if (msg is! Map) return;
      final index = (msg['index'] as int?) ?? 0;
      switch (msg['type']) {
        case 'hello':
          _ports[index] = msg['port'] as SendPort;
          _ports[index]!.send({'type': 'intensity', 'value': _intensity});
          _ports[index]!.send({'type': 'observe', 'value': _observeBits});
          _ports[index]!.send({'type': 'start'});
          if (_ports.length == _workerCount && !ready.isCompleted) {
            ready.complete();
          }
          break;
        case 'sighting':
          onSighting?.call(
              (msg['difficulty'] as num).toDouble(), msg['nonce'] as int);
          break;
        case 'stats':
          _totals[index] = msg['total'] as int;
          _rates[index] = (msg['hps'] as num).toDouble();
          final nonce = msg['nonce'];
          if (nonce is int) onNonce?.call(nonce);
          onStats?.call(
            _rates.values.fold(0.0, (a, b) => a + b),
            _totals.values.fold(0, (a, b) => a + b),
          );
          break;
        case 'share':
          final hash = Uint8List.fromList(List<int>.from(msg['hash'] as List));
          onShare?.call(FoundShare(
            jobId: msg['jobId'] as String,
            extranonce2: msg['extranonce2'] as String,
            nTime: msg['ntime'] as String,
            nonce: msg['nonce'] as int,
            hashHex: bytesToHex(reverseBytes(hash)),
            difficulty: difficultyOfHash(hash),
          ));
          break;
      }
    });

    try {
      for (var i = 0; i < _workerCount; i++) {
        _isolates.add(
            await Isolate.spawn(_minerEntryPoint, [rx.sendPort, i, _mode.index]));
      }
      await ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      // Ne jamais laisser des isolates partiellement demarres si l'un d'eux
      // echoue ou n'envoie pas son message de disponibilite.
      await stop();
      rethrow;
    }
  }

  Future<void> setWork(WorkPackage work) async {
    final ready = _ready;
    if (ready == null) return;
    await ready.future;
    for (final entry in _ports.entries) {
      final message = work.toMap(offset: entry.key, stride: _workerCount);
      message['strategy'] = _strategy.index;
      message['signature'] = _signature.toMap();
      entry.value.send(message);
    }
  }

  /// Intensite de 10 a 100 % : en dessous de 100, chaque isolate marque une
  /// pause proportionnelle apres chaque lot de hachages. Moins de chaleur,
  /// moins de batterie.
  /// Seuil d'observation : nombre de bits a zero a partir duquel une tentative
  /// est signalee a l'interface, meme si elle ne vaut pas une part. C'est ce
  /// qui rend le hasard visible sans rien simuler.
  void setObserveBits(int bits) {
    _observeBits = bits.clamp(8, 40);
    for (final p in _ports.values) {
      p.send({'type': 'observe', 'value': _observeBits});
    }
  }

  void setIntensity(int percent) {
    _intensity = percent.clamp(10, 100);
    for (final p in _ports.values) {
      p.send({'type': 'intensity', 'value': _intensity});
    }
  }

  void pause() {
    for (final p in _ports.values) {
      p.send({'type': 'pause'});
    }
  }

  Future<void> stop() async {
    for (final p in _ports.values) {
      p.send({'type': 'stop'});
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (final iso in _isolates) {
      iso.kill(priority: Isolate.immediate);
    }
    _isolates.clear();
    _ports.clear();
    _totals.clear();
    _rates.clear();
    _rx?.close();
    _rx = null;
    _ready = null;
  }
}

/// ---------------------------------------------------------------------------
/// Code execute dans chaque isolate : la boucle de hachage.
/// ---------------------------------------------------------------------------
void _minerEntryPoint(List<dynamic> args) {
  final mainPort = args[0] as SendPort;
  final index = args[1] as int;
  final mode = HashMode.values[args[2] as int];
  final fast = Sha256Fast();

  final rx = ReceivePort();
  mainPort.send({'type': 'hello', 'index': index, 'port': rx.sendPort});

  Uint8List? header;
  Uint8List? target;
  var jobId = '';
  var extranonce2 = '';
  var nTime = '';
  var nonce = 0;
  var stride = 1;
  NonceWalker? walker;
  var intensity = 100;
  var targetHead = 0;
  var observeBits = 24;
  var observeHead = 0xFFFFFFFF >> 24;
  var lastSighting = 0;
  var totalHashes = 0;
  var running = false;
  var looping = false;

  Future<void> loop() async {
    looping = true;
    var lastTick = DateTime.now().millisecondsSinceEpoch;
    var lastHashes = totalHashes;

    while (running) {
      final h = header;
      final t = target;
      if (h == null || t == null) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        continue;
      }

      final batchStart = DateTime.now().microsecondsSinceEpoch;
      for (var i = 0; i < 1000; i++) {
        Uint8List? hash;

        switch (mode) {
          case HashMode.midstate:
            // Rejet precoce : les 4 premiers octets du hash retourne suffisent
            // presque toujours a condamner la tentative, sans rien serialiser.
            final head = _swap32(fast.hashNonce(nonce));
            if (head <= observeHead) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - lastSighting > 250) {
                lastSighting = now;
                mainPort.send({
                  'type': 'sighting',
                  'index': index,
                  'nonce': nonce,
                  'difficulty': head == 0 ? 4294967296.0 : 4294967296.0 / head,
                });
              }
            }
            if (head < targetHead) {
              hash = fast.digest();
            } else if (head == targetHead) {
              final candidate = fast.digest();
              if (hashMeetsTarget(candidate, t)) hash = candidate;
            }
            break;
          case HashMode.maison:
            h[76] = nonce & 0xff;
            h[77] = (nonce >> 8) & 0xff;
            h[78] = (nonce >> 16) & 0xff;
            h[79] = (nonce >> 24) & 0xff;
            final candidate = fast.doubleHashFull(h);
            if (hashMeetsTarget(candidate, t)) hash = candidate;
            break;
          case HashMode.compatible:
            h[76] = nonce & 0xff;
            h[77] = (nonce >> 8) & 0xff;
            h[78] = (nonce >> 16) & 0xff;
            h[79] = (nonce >> 24) & 0xff;
            final candidate = sha256d(h);
            if (hashMeetsTarget(candidate, t)) hash = candidate;
            break;
        }

        totalHashes++;
        if (hash != null) {
          mainPort.send({
            'type': 'share',
            'index': index,
            'jobId': jobId,
            'extranonce2': extranonce2,
            'ntime': nTime,
            'nonce': nonce,
            // Le moteur rapide reutilise ses buffers : ne copier que lorsqu'une
            // vraie part est trouvee, jamais a chaque tentative.
            'hash': Uint8List.fromList(hash),
          });
        }
        nonce = walker?.next() ?? ((nonce + stride) & 0xFFFFFFFF);
      }

      if (intensity < 100) {
        final elapsed = DateTime.now().microsecondsSinceEpoch - batchStart;
        var remaining = (elapsed * (100 - intensity) / intensity).round();
        // Ne pas plafonner artificiellement la pause : sur un appareil lent,
        // cela faisait depasser largement l'intensite choisie. Les pauses sont
        // decoupees pour rester reactif a un nouveau job ou a un arret.
        while (remaining > 0 && running && identical(header, h)) {
          final slice = remaining > 100000 ? 100000 : remaining;
          await Future<void>.delayed(Duration(microseconds: slice));
          remaining -= slice;
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastTick >= 1000) {
        mainPort.send({
          'type': 'stats',
          'index': index,
          'nonce': nonce,
          'total': totalHashes,
          'hps': (totalHashes - lastHashes) * 1000 / (now - lastTick),
        });
        lastHashes = totalHashes;
        lastTick = now;
      }
      await Future<void>.delayed(Duration.zero);
    }
    looping = false;
  }

  rx.listen((msg) {
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'work':
        header = Uint8List.fromList(List<int>.from(msg['header'] as List));
        target = Uint8List.fromList(List<int>.from(msg['target'] as List));
        jobId = msg['jobId'] as String;
        extranonce2 = msg['extranonce2'] as String;
        nTime = msg['ntime'] as String;
        stride = (msg['stride'] as int?) ?? 1;
        walker = NonceWalker.create(
          strategy: NonceStrategy.values[(msg['strategy'] as int?) ?? 0],
          signature: NonceSignature.fromMap(
              (msg['signature'] as Map?) ?? const {'a': 1, 'c': 1, 's': 0}),
          startNonce: (msg['startNonce'] as int?) ?? 0,
          offset: (msg['offset'] as int?) ?? 0,
          stride: stride,
        );
        nonce = walker!.next();
        targetHead = (target![0] << 24) |
            (target![1] << 16) |
            (target![2] << 8) |
            target![3];
        if (mode == HashMode.midstate) fast.prepare(header!);

        break;
      case 'start':
        running = true;
        if (!looping) loop();
        break;
      case 'observe':
        observeBits = (msg['value'] as int).clamp(8, 40);
        observeHead = observeBits >= 32 ? 0 : (0xFFFFFFFF >> observeBits);
        break;
      case 'intensity':
        intensity = (msg['value'] as int).clamp(10, 100);
        break;
      case 'pause':
        header = null;
        break;
      case 'stop':
        running = false;
        rx.close();
        break;
    }
  });
}


/// Inverse l'ordre des octets d'un mot de 32 bits.
int _swap32(int v) =>
    ((v & 0xff) << 24) |
    (((v >> 8) & 0xff) << 16) |
    (((v >> 16) & 0xff) << 8) |
    ((v >> 24) & 0xff);
