import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'stratum_job.dart';

/// Client Stratum V1 : subscribe, authorize, notify, difficulte, extranonce,
/// submit. Les messages du pool sont valides avant d'etre transmis au reste de
/// l'application afin qu'une reponse mal formee ne fasse pas tomber le mineur.
class StratumClient {
  Socket? _socket;
  StreamSubscription<String>? _sub;
  int _nextId = 10;
  final Set<int> _submitIds = <int>{};
  bool _disconnectNotified = false;
  bool _closedByUser = false;

  void Function(String line)? onLog;

  /// Chaque ligne JSON echangee avec le pool, telle quelle. Sert la console du
  /// labo : voir le protocole reel plutot qu'un resume.
  void Function(bool outgoing, String line)? onRaw;
  void Function(String extranonce1, int extranonce2Size)? onSubscribed;
  void Function(String extranonce1, int extranonce2Size)? onExtranonce;
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
    _disconnectNotified = false;
    _closedByUser = false;
    _submitIds.clear();

    onLog?.call('Connexion a $host:$port...');
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 20),
    );
    _socket = socket;
    socket.setOption(SocketOption.tcpNoDelay, true);

    _sub = utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: (Object e) {
      _notifyDisconnected('Erreur reseau : $e');
      _cleanup();
    }, onDone: () {
      _notifyDisconnected('Le pool a ferme la connexion.');
      _cleanup();
    });

    onLog?.call('Connecte. Envoi de mining.subscribe.');
    _send({
      'id': 1,
      'method': 'mining.subscribe',
      'params': ['btc-miner-fun/0.11'],
    });
    _send({
      'id': 2,
      'method': 'mining.authorize',
      'params': [user, password],
    });
    // Extension Stratum V1 : annonce que le client sait traiter
    // mining.set_extranonce. Un pool qui ne la connait pas peut simplement
    // repondre "method not found" sans interrompre la session.
    _send({
      'id': 3,
      'method': 'mining.extranonce.subscribe',
      'params': const [],
    });
  }

  void submit({
    required String worker,
    required FoundShare share,
  }) {
    if (_socket == null) return;
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
    try {
      final line = jsonEncode(payload);
    onRaw?.call(true, line);
    socket.write('$line\n');
    } catch (e) {
      _notifyDisconnected('Ecriture vers le pool impossible : $e');
      _cleanup();
    }
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    onRaw?.call(false, line.trim());

    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        onLog?.call('Reponse illisible du pool : objet JSON inattendu.');
        return;
      }
      msg = Map<String, dynamic>.from(decoded);
    } catch (_) {
      onLog?.call('Reponse illisible du pool.');
      return;
    }

    final method = msg['method'];
    if (method is String) {
      final rawParams = msg['params'];
      final params = rawParams is List ? rawParams : const <dynamic>[];
      try {
        switch (method) {
          case 'mining.notify':
            if (params.length < 8) {
              onLog?.call('Job Stratum incomplet ignore.');
              return;
            }
            final job = StratumJob.fromNotify(List<dynamic>.from(params));
            onLog?.call('Nouveau job ${job.jobId}');
            onJob?.call(job);
            return;

          case 'mining.set_difficulty':
            if (params.isEmpty || params[0] is! num) {
              onLog?.call('Difficulte Stratum invalide ignoree.');
              return;
            }
            final d = (params[0] as num).toDouble();
            if (!d.isFinite || d <= 0) {
              onLog?.call('Difficulte Stratum invalide ignoree : $d');
              return;
            }
            onLog?.call('Difficulte annoncee par le pool : $d');
            onDifficulty?.call(d);
            return;

          case 'mining.set_extranonce':
            if (params.length < 2 || params[0] is! String || params[1] is! num) {
              onLog?.call('Changement d\'extranonce mal forme ignore.');
              return;
            }
            final e1 = params[0] as String;
            final size = (params[1] as num).toInt();
            if (!_isEvenHex(e1) || size <= 0 || size > 32) {
              onLog?.call('Changement d\'extranonce invalide ignore.');
              return;
            }
            onLog?.call('Nouvel extranonce annonce pour le prochain job.');
            onExtranonce?.call(e1, size);
            return;

          case 'client.show_message':
            if (params.isNotEmpty) {
              onLog?.call('Message du pool : ${params.first}');
            }
            return;

          default:
            return;
        }
      } catch (e) {
        onLog?.call('Message Stratum mal forme ($method) ignore : $e');
        return;
      }
    }

    final id = msg['id'];
    final result = msg['result'];
    final error = msg['error'];

    if (id == 1) {
      if (result is List &&
          result.length >= 3 &&
          result[1] != null &&
          result[2] is num) {
        final extranonce1 = result[1].toString();
        final size = (result[2] as num).toInt();
        if (_isEvenHex(extranonce1) && size > 0 && size <= 32) {
          onLog?.call('Abonne au pool (extranonce1 = $extranonce1).');
          onSubscribed?.call(extranonce1, size);
        } else {
          onLog?.call('Parametres d\'abonnement invalides recus du pool.');
        }
      } else {
        onLog?.call('Abonnement refuse ou reponse invalide du pool.');
      }
      return;
    }

    if (id == 2) {
      final ok = result == true;
      onLog?.call(ok
          ? 'Worker autorise par le pool.'
          : 'Autorisation refusee : verifie l\'adresse et le nom du worker.');
      onAuthorized?.call(ok);
      return;
    }

    // Reponse a mining.extranonce.subscribe : certains pools renvoient une
    // erreur car l'extension n'est pas implementee. Ce n'est pas bloquant.
    if (id == 3) {
      if (error != null) {
        onLog?.call('Le pool n\'utilise pas l\'extension set_extranonce.');
      }
      return;
    }

    if (id is int && _submitIds.remove(id)) {
      final accepted = result == true;
      onSubmitResult?.call(accepted, _errorReason(error));
    }
  }

  bool _isEvenHex(String value) =>
      value.isNotEmpty &&
      value.length.isEven &&
      RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);

  String? _errorReason(Object? error) {
    if (error == null) return null;
    if (error is List && error.length >= 2) return error[1]?.toString();
    if (error is Map) {
      final message = error['message'];
      if (message != null) return message.toString();
    }
    return error.toString();
  }

  void _notifyDisconnected(String message) {
    if (_closedByUser || _disconnectNotified) return;
    _disconnectNotified = true;
    onDisconnected?.call(message);
  }

  Future<void> disconnect() async {
    _closedByUser = true;
    final sub = _sub;
    _sub = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await _socket?.close();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _submitIds.clear();
  }
}
