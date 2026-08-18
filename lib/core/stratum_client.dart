import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stratum_job.dart';

/// Client Stratum V1 minimal : subscribe, authorize, notify, submit.
class StratumClient {
  Socket? _socket;
  StreamSubscription<String>? _sub;
  int _nextId = 10;
  final Set<int> _submitIds = <int>{};

  void Function(String line)? onLog;
  void Function(String extranonce1, int extranonce2Size)? onSubscribed;
  void Function(bool authorized)? onAuthorized;
  void Function(double difficulty)? onDifficulty;
  void Function(StratumJob job)? onJob;
  void Function(bool accepted, String? reason)? onSubmitResult;
  void Function(String message)? onDisconnected;

  bool get isConnected => _socket != null;

  Future<void> connect({
    required String host,
    required int port,
    required String user,
    required String password,
  }) async {
    onLog?.call('Connexion a $host:$port...');
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 20));
    _socket = socket;
    socket.setOption(SocketOption.tcpNoDelay, true);

    _sub = utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: (Object e) {
      onDisconnected?.call('Erreur reseau : $e');
      _cleanup();
    }, onDone: () {
      onDisconnected?.call('Le pool a ferme la connexion.');
      _cleanup();
    });

    onLog?.call('Connecte. Envoi de mining.subscribe.');
    _send({
      'id': 1,
      'method': 'mining.subscribe',
      'params': ['btc-miner-fun/0.1'],
    });
    _send({
      'id': 2,
      'method': 'mining.authorize',
      'params': [user, password],
    });
  }

  void submit({
    required String worker,
    required FoundShare share,
  }) {
    final id = _nextId++;
    _submitIds.add(id);
    _send({
      'id': id,
      'method': 'mining.submit',
      'params': [
        worker,
        share.jobId,
        share.extranonce2,
        share.nTime,
        share.nonceHex,
      ],
    });
  }

  void _send(Map<String, dynamic> payload) {
    final socket = _socket;
    if (socket == null) return;
    socket.write('${jsonEncode(payload)}\n');
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      onLog?.call('Reponse illisible du pool.');
      return;
    }

    final method = msg['method'] as String?;
    if (method != null) {
      final params = (msg['params'] as List?) ?? const [];
      switch (method) {
        case 'mining.notify':
          if (params.length >= 8) {
            final job = StratumJob.fromNotify(params);
            onLog?.call('Nouveau job ${job.jobId}');
            onJob?.call(job);
          }
          break;
        case 'mining.set_difficulty':
          if (params.isNotEmpty) {
            final d = (params[0] as num).toDouble();
            onLog?.call('Difficulte du pool : $d');
            onDifficulty?.call(d);
          }
          break;
        default:
          break;
      }
      return;
    }

    final id = msg['id'];
    final result = msg['result'];
    final error = msg['error'];

    if (id == 1) {
      if (result is List && result.length >= 3) {
        final extranonce1 = result[1].toString();
        final size = (result[2] as num).toInt();
        onLog?.call('Abonne au pool (extranonce1 = $extranonce1).');
        onSubscribed?.call(extranonce1, size);
      } else {
        onLog?.call('Abonnement refuse par le pool.');
      }
      return;
    }

    if (id == 2) {
      final ok = result == true;
      onLog?.call(ok
          ? 'Worker autorise par le pool.'
          : 'Autorisation refusee : verifie ton adresse de portefeuille.');
      onAuthorized?.call(ok);
      return;
    }

    if (id is int && _submitIds.remove(id)) {
      final accepted = result == true;
      String? reason;
      if (error is List && error.length >= 2) reason = error[1].toString();
      onSubmitResult?.call(accepted, reason);
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _socket?.destroy();
    _socket = null;
    _submitIds.clear();
  }
}
