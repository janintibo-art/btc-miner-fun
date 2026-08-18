import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bitcoin_utils.dart';
import '../core/miner_engine.dart';
import '../core/stratum_client.dart';
import '../core/stratum_job.dart';

enum MinerMode { demo, pool }

enum MinerStatus { stopped, connecting, running, error }

class MinerController extends ChangeNotifier {
  final MinerEngine _engine = MinerEngine();
  final Random _random = Random();
  StratumClient? _client;
  StratumJob? _job;
  Timer? _ticker;

  String _extranonce1 = '';
  int _extranonce2Size = 4;
  int _extranonce2Counter = 0;

  // ---- Reglages ----
  MinerMode mode = MinerMode.demo;
  String poolHost = 'public-pool.io';
  int poolPort = 21496;
  String wallet = '';
  String workerName = 'telephone';
  String poolPassword = 'x';
  int demoZeroBits = 20;

  // ---- Etat ----
  MinerStatus status = MinerStatus.stopped;
  String statusMessage = 'A l\'arret';
  double hashrate = 0;
  double bestDifficulty = 0;
  int totalHashes = 0;
  int accepted = 0;
  int rejected = 0;
  double poolDifficulty = 1;
  DateTime? startedAt;
  final List<double> history = <double>[];
  final List<String> logs = <String>[];

  bool get isBusy =>
      status == MinerStatus.running || status == MinerStatus.connecting;
  Duration get uptime =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  // ---------------------------------------------------------------------------

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    mode = (p.getString('mode') ?? 'demo') == 'pool'
        ? MinerMode.pool
        : MinerMode.demo;
    poolHost = p.getString('poolHost') ?? poolHost;
    poolPort = p.getInt('poolPort') ?? poolPort;
    wallet = p.getString('wallet') ?? '';
    workerName = p.getString('workerName') ?? workerName;
    poolPassword = p.getString('poolPassword') ?? poolPassword;
    demoZeroBits = p.getInt('demoZeroBits') ?? demoZeroBits;

    _engine.onStats = (hps, total) {
      hashrate = hps;
      totalHashes = total;
      notifyListeners();
    };
    _engine.onShare = _onShareFound;

    log('Bienvenue. Le mode demo mine dans le vide, sans reseau.');
    notifyListeners();
  }

  void setMode(MinerMode value) {
    mode = value;
    notifyListeners();
  }

  void setDemoZeroBits(int value) {
    demoZeroBits = value;
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('mode', mode == MinerMode.pool ? 'pool' : 'demo');
    await p.setString('poolHost', poolHost);
    await p.setInt('poolPort', poolPort);
    await p.setString('wallet', wallet);
    await p.setString('workerName', workerName);
    await p.setString('poolPassword', poolPassword);
    await p.setInt('demoZeroBits', demoZeroBits);
    log('Reglages enregistres.');
    notifyListeners();
  }

  void log(String line) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    logs.insert(0, '[$stamp] $line');
    if (logs.length > 200) logs.removeLast();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (isBusy) return;
    accepted = 0;
    rejected = 0;
    totalHashes = 0;
    bestDifficulty = 0;
    history.clear();
    startedAt = DateTime.now();

    await _engine.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      history.add(hashrate);
      if (history.length > 60) history.removeAt(0);
      notifyListeners();
    });

    if (mode == MinerMode.demo) {
      status = MinerStatus.running;
      statusMessage = 'Mode demo en cours';
      log('Demarrage du mode demo (cible : $demoZeroBits bits a zero).');
      _pushDemoWork();
      notifyListeners();
      return;
    }

    if (wallet.trim().isEmpty) {
      status = MinerStatus.error;
      statusMessage = 'Adresse de portefeuille manquante';
      log('Ajoute ton adresse Bitcoin dans l\'onglet Reglages.');
      notifyListeners();
      return;
    }

    status = MinerStatus.connecting;
    statusMessage = 'Connexion au pool';
    notifyListeners();

    final client = StratumClient();
    _client = client;
    client.onLog = log;
    client.onSubscribed = (e1, size) {
      _extranonce1 = e1;
      _extranonce2Size = size;
    };
    client.onAuthorized = (ok) {
      if (ok) {
        status = MinerStatus.running;
        statusMessage = 'Connecte a $poolHost';
      } else {
        status = MinerStatus.error;
        statusMessage = 'Refuse par le pool';
      }
      notifyListeners();
    };
    client.onDifficulty = (d) {
      poolDifficulty = d;
      _pushPoolWork();
    };
    client.onJob = (job) {
      _job = job;
      _pushPoolWork();
    };
    client.onSubmitResult = (ok, reason) {
      if (ok) {
        accepted++;
        log('Part acceptee par le pool.');
      } else {
        rejected++;
        log('Part refusee${reason == null ? '' : ' : $reason'}');
      }
      notifyListeners();
    };
    client.onDisconnected = (msg) {
      log(msg);
      if (isBusy) {
        status = MinerStatus.error;
        statusMessage = 'Deconnecte';
        notifyListeners();
      }
    };

    try {
      await client.connect(
        host: poolHost,
        port: poolPort,
        user: '${wallet.trim()}.${workerName.trim()}',
        password: poolPassword,
      );
    } catch (e) {
      status = MinerStatus.error;
      statusMessage = 'Connexion impossible';
      log('Connexion impossible : $e');
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    await _client?.disconnect();
    _client = null;
    await _engine.stop();
    status = MinerStatus.stopped;
    statusMessage = 'A l\'arret';
    hashrate = 0;
    startedAt = null;
    log('Minage arrete.');
    notifyListeners();
  }

  Future<void> toggle() => isBusy ? stop() : start();

  // ---------------------------------------------------------------------------

  void _pushPoolWork() {
    final job = _job;
    if (job == null || _extranonce1.isEmpty) return;
    _extranonce2Counter = (_extranonce2Counter + 1) & 0x7fffffff;
    final en2 = _extranonce2Counter
        .toRadixString(16)
        .padLeft(_extranonce2Size * 2, '0');
    final header = job.buildHeader(_extranonce1, en2);
    _engine.setWork(WorkPackage(
      jobId: job.jobId,
      header: header,
      target: targetFromDifficulty(poolDifficulty),
      extranonce2: en2,
      nTime: job.nTime,
      startNonce: _random.nextInt(0x7fffffff),
    ));
  }

  void _pushDemoWork() {
    final header = Uint8List(80);
    for (var i = 0; i < 76; i++) {
      header[i] = _random.nextInt(256);
    }
    _engine.setWork(WorkPackage(
      jobId: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      header: header,
      target: targetFromLeadingZeroBits(demoZeroBits),
      extranonce2: '00000000',
      nTime: '00000000',
      startNonce: 0,
    ));
  }

  void _onShareFound(FoundShare share) {
    if (share.difficulty > bestDifficulty) bestDifficulty = share.difficulty;

    if (mode == MinerMode.demo) {
      accepted++;
      log('Solution demo trouvee : ${share.hashHex.substring(0, 24)}...');
      _pushDemoWork();
      notifyListeners();
      return;
    }

    log('Part trouvee (difficulte ${share.difficulty.toStringAsFixed(3)}), envoi au pool.');
    _client?.submit(worker: '${wallet.trim()}.${workerName.trim()}', share: share);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _client?.disconnect();
    _engine.stop();
    super.dispose();
  }
}
