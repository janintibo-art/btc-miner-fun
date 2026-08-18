import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'bitcoin_utils.dart';
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

  void Function(double hashrate, int totalHashes)? onStats;
  void Function(FoundShare share)? onShare;

  int get workerCount => _workerCount;
  bool get isStarted => _isolates.isNotEmpty;

  Future<void> start(int workers) async {
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
          _ports[index]!.send({'type': 'start'});
          if (_ports.length == _workerCount && !ready.isCompleted) {
            ready.complete();
          }
          break;
        case 'stats':
          _totals[index] = msg['total'] as int;
          _rates[index] = (msg['hps'] as num).toDouble();
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

    for (var i = 0; i < _workerCount; i++) {
      _isolates.add(await Isolate.spawn(_minerEntryPoint, [rx.sendPort, i]));
    }
    await ready.future;
  }

  Future<void> setWork(WorkPackage work) async {
    final ready = _ready;
    if (ready == null) return;
    await ready.future;
    for (final entry in _ports.entries) {
      entry.value.send(work.toMap(
        offset: entry.key,
        stride: _workerCount,
      ));
    }
  }

  /// Intensite de 10 a 100 % : en dessous de 100, chaque isolate marque une
  /// pause proportionnelle apres chaque lot de hachages. Moins de chaleur,
  /// moins de batterie.
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

  final rx = ReceivePort();
  mainPort.send({'type': 'hello', 'index': index, 'port': rx.sendPort});

  Uint8List? header;
  Uint8List? target;
  var jobId = '';
  var extranonce2 = '';
  var nTime = '';
  var nonce = 0;
  var stride = 1;
  var intensity = 100;
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
        h[76] = nonce & 0xff;
        h[77] = (nonce >> 8) & 0xff;
        h[78] = (nonce >> 16) & 0xff;
        h[79] = (nonce >> 24) & 0xff;
        final hash = sha256d(h);
        totalHashes++;
        if (hashMeetsTarget(hash, t)) {
          mainPort.send({
            'type': 'share',
            'index': index,
            'jobId': jobId,
            'extranonce2': extranonce2,
            'ntime': nTime,
            'nonce': nonce,
            'hash': hash,
          });
        }
        nonce = (nonce + stride) & 0xFFFFFFFF;
      }

      if (intensity < 100) {
        final elapsed = DateTime.now().microsecondsSinceEpoch - batchStart;
        final rest = (elapsed * (100 - intensity) / intensity).round();
        await Future<void>.delayed(
            Duration(microseconds: rest.clamp(0, 400000)));
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastTick >= 1000) {
        mainPort.send({
          'type': 'stats',
          'index': index,
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
        nonce = (((msg['startNonce'] as int?) ?? 0) + ((msg['offset'] as int?) ?? 0)) &
            0xFFFFFFFF;
        break;
      case 'start':
        running = true;
        if (!looping) loop();
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
