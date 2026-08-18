import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'bitcoin_utils.dart';
import 'stratum_job.dart';

/// Le moteur tourne dans un isolate separe pour ne jamais figer l'interface.
class MinerEngine {
  Isolate? _isolate;
  SendPort? _tx;
  ReceivePort? _rx;
  Completer<void>? _ready;

  void Function(double hashrate, int totalHashes)? onStats;
  void Function(FoundShare share)? onShare;

  bool get isStarted => _isolate != null;

  Future<void> start() async {
    if (_isolate != null) return;
    final ready = Completer<void>();
    _ready = ready;
    _rx = ReceivePort();
    _isolate = await Isolate.spawn(_minerEntryPoint, _rx!.sendPort);
    _rx!.listen((msg) {
      if (msg is SendPort) {
        _tx = msg;
        if (!ready.isCompleted) ready.complete();
        _tx!.send({'type': 'start'});
        return;
      }
      if (msg is Map) {
        switch (msg['type']) {
          case 'stats':
            onStats?.call(
                (msg['hps'] as num).toDouble(), msg['total'] as int);
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
      }
    });
    await ready.future;
  }

  Future<void> setWork(WorkPackage work) async {
    final ready = _ready;
    if (ready == null) return;
    await ready.future;
    _tx?.send(work.toMap());
  }

  void pause() => _tx?.send({'type': 'pause'});

  Future<void> stop() async {
    _tx?.send({'type': 'stop'});
    await Future<void>.delayed(const Duration(milliseconds: 60));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _rx?.close();
    _rx = null;
    _tx = null;
    _ready = null;
  }
}

/// ---------------------------------------------------------------------------
/// Code execute dans l'isolate : la boucle de hachage.
/// ---------------------------------------------------------------------------
void _minerEntryPoint(SendPort mainPort) {
  final rx = ReceivePort();
  mainPort.send(rx.sendPort);

  Uint8List? header;
  Uint8List? target;
  var jobId = '';
  var extranonce2 = '';
  var nTime = '';
  var nonce = 0;
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
            'jobId': jobId,
            'extranonce2': extranonce2,
            'ntime': nTime,
            'nonce': nonce,
            'hash': hash,
          });
        }
        nonce = (nonce + 1) & 0xFFFFFFFF;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastTick >= 1000) {
        mainPort.send({
          'type': 'stats',
          'total': totalHashes,
          'hps': (totalHashes - lastHashes) * 1000 / (now - lastTick),
        });
        lastHashes = totalHashes;
        lastTick = now;
      }
      // Laisse respirer la boucle d'evenements de l'isolate.
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
        nonce = (msg['startNonce'] as int?) ?? 0;
        break;
      case 'start':
        running = true;
        if (!looping) loop();
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
