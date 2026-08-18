import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bitcoin_utils.dart';
import '../core/foreground_service.dart';
import '../core/miner_engine.dart';
import '../core/session.dart';
import '../core/stratum_client.dart';
import '../core/stratum_job.dart';

enum MinerStatus { stopped, connecting, waitingJob, mining, error }

/// Pools connus pour accepter des difficultes tres basses, donc adaptes aux
/// tres petites machines. Le port est indique par le pool lui-meme.
class PoolPreset {
  const PoolPreset(this.name, this.host, this.port, this.note);
  final String name;
  final String host;
  final int port;
  final String note;
}

const kPoolPresets = <PoolPreset>[
  PoolPreset('Public Pool (solo)', 'public-pool.io', 21496,
      'Pool solo pense pour les petits mineurs. Difficulte tres basse.'),
  PoolPreset('CKPool solo', 'solo.ckpool.org', 3333,
      'Solo historique. Difficulte plus elevee, parts beaucoup plus rares.'),
];

class MinerController extends ChangeNotifier {
  final MinerEngine _engine = MinerEngine();
  final Random _random = Random();
  StratumClient? _client;
  StratumJob? _job;
  Timer? _ticker;
  Timer? _reconnectTimer;

  String _extranonce1 = '';
  int _extranonce2Size = 4;
  int _extranonce2Counter = 0;
  bool _wantsMining = false;
  int _reconnectAttempts = 0;

  // ---- Reglages ----
  String poolHost = kPoolPresets.first.host;
  int poolPort = kPoolPresets.first.port;
  String wallet = '';
  String workerName = 'telephone';
  String poolPassword = 'x';
  int threads = 0; // 0 = valeur conseillee, calculee au premier lancement
  int intensity = 100; // 10 a 100 %
  int autoStopMinutes = 0; // 0 = pas d'arret automatique
  bool keepScreenOn = false;
  bool backgroundServiceActive = false;

  // ---- Etat ----
  MinerStatus status = MinerStatus.stopped;
  String statusMessage = 'A l\'arret';
  double hashrate = 0;
  double bestDifficulty = 0;
  int totalHashes = 0;
  int accepted = 0;
  int rejected = 0;
  double poolDifficulty = 0;
  int jobsReceived = 0;
  DateTime? startedAt;
  JobSnapshot? job;
  final List<double> history = <double>[];
  final List<String> logs = <String>[];
  final List<MiningSession> sessions = <MiningSession>[];
  final List<FoundShare> _pendingShares = <FoundShare>[];
  bool _authorized = false;
  Timer? _autoStopTimer;

  int get pendingShares => _pendingShares.length;

  bool get isBusy => status != MinerStatus.stopped && status != MinerStatus.error;

  /// Nombre de coeurs disponibles sur l'appareil.
  int get availableCores => Platform.numberOfProcessors.clamp(1, 16);

  /// Par defaut on garde de la marge : la moitie des coeurs, 4 au maximum.
  int get recommendedThreads => (availableCores / 2).floor().clamp(1, 4);

  int get effectiveThreads =>
      threads <= 0 ? recommendedThreads : threads.clamp(1, availableCores);
  bool get isActive => _wantsMining;
  Duration get uptime =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  /// Verification de forme uniquement : longueur et prefixe plausibles.
  bool get walletLooksValid {
    final w = wallet.trim();
    if (w.length < 26 || w.length > 62) return false;
    return w.startsWith('bc1') || w.startsWith('1') || w.startsWith('3');
  }

  // ---------------------------------------------------------------------------

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    poolHost = p.getString('poolHost') ?? poolHost;
    poolPort = p.getInt('poolPort') ?? poolPort;
    wallet = p.getString('wallet') ?? '';
    workerName = p.getString('workerName') ?? workerName;
    poolPassword = p.getString('poolPassword') ?? poolPassword;
    threads = p.getInt('threads') ?? 0;
    intensity = p.getInt('intensity') ?? 100;
    autoStopMinutes = p.getInt('autoStopMinutes') ?? 0;
    keepScreenOn = p.getBool('keepScreenOn') ?? false;
    sessions.addAll(MiningSession.decodeList(p.getString('sessions') ?? '[]'));

    _engine.onStats = (hps, total) {
      hashrate = hps;
      totalHashes = total;
      if (status == MinerStatus.waitingJob && hps > 0) {
        status = MinerStatus.mining;
        statusMessage = 'Minage en cours sur $poolHost';
      }
      notifyListeners();
    };
    _engine.onShare = _onShareFound;

    log(wallet.isEmpty
        ? 'Renseigne ton adresse Bitcoin dans Reglages pour commencer.'
        : 'Pret. Appuie sur Lancer le minage.');
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('poolHost', poolHost);
    await p.setInt('poolPort', poolPort);
    await p.setString('wallet', wallet);
    await p.setString('workerName', workerName);
    await p.setString('poolPassword', poolPassword);
    await p.setInt('threads', threads);
    await p.setInt('intensity', intensity);
    await p.setInt('autoStopMinutes', autoStopMinutes);
    await p.setBool('keepScreenOn', keepScreenOn);
    log('Reglages enregistres.');
    notifyListeners();
  }

  void log(String line) {
    final now = DateTime.now();
    final stamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    logs.insert(0, '[$stamp] $line');
    if (logs.length > 200) logs.removeLast();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------

  Future<void> start() async {
    if (_wantsMining) return;
    if (!walletLooksValid) {
      status = MinerStatus.error;
      statusMessage = 'Adresse Bitcoin invalide';
      log('Verifie ton adresse dans Reglages : elle doit commencer par bc1, 1 ou 3.');
      notifyListeners();
      return;
    }

    _wantsMining = true;
    _reconnectAttempts = 0;
    accepted = 0;
    rejected = 0;
    totalHashes = 0;
    bestDifficulty = 0;
    jobsReceived = 0;
    poolDifficulty = 0;
    job = null;
    history.clear();
    startedAt = DateTime.now();

    _pendingShares.clear();
    _authorized = false;
    await _engine.start(effectiveThreads);
    _engine.setIntensity(intensity);
    if (keepScreenOn) _setWakelock(true);

    if (ForegroundService.isSupported) {
      backgroundServiceActive = await ForegroundService.start(
        title: 'BTC Miner Fun',
        text: 'Connexion a $poolHost...',
      );
      log(backgroundServiceActive
          ? 'Service de premier plan actif : le minage continue ecran eteint.'
          : 'Service de premier plan indisponible : le minage s\'arretera '
              'quand l\'ecran s\'eteindra.');
    }
    log('Moteur lance sur $effectiveThreads coeur(s) '
        '(sur $availableCores disponibles).');
    _ticker?.cancel();
    var tick = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      history.add(hashrate);
      if (history.length > 60) history.removeAt(0);
      if (backgroundServiceActive && ++tick % 10 == 0) _updateNotification();
      notifyListeners();
    });

    if (autoStopMinutes > 0) {
      _autoStopTimer?.cancel();
      _autoStopTimer = Timer(Duration(minutes: autoStopMinutes), () {
        log('Arret automatique apres $autoStopMinutes minutes.');
        stop();
      });
      log('Arret automatique programme dans $autoStopMinutes minutes.');
    }

    await _connect();
  }

  Future<void> _connect() async {
    status = MinerStatus.connecting;
    statusMessage = 'Connexion a $poolHost';
    notifyListeners();

    final client = StratumClient();
    _client = client;
    client.onLog = log;
    client.onSubscribed = (e1, size) {
      _extranonce1 = e1;
      _extranonce2Size = size;
      _reconnectAttempts = 0;
    };
    client.onAuthorized = (ok) {
      _authorized = ok;
      if (ok) {
        status = MinerStatus.waitingJob;
        statusMessage = 'En attente d\'un travail du pool';
      } else {
        _wantsMining = false;
        status = MinerStatus.error;
        statusMessage = 'Refuse par le pool';
      }
      notifyListeners();
    };
    client.onDifficulty = (d) {
      poolDifficulty = d;
      _pushWork();
    };
    client.onJob = (j) {
      _job = j;
      jobsReceived++;
      _pushWork();
      _flushPendingShares();
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
      _authorized = false;
      log(msg);
      _scheduleReconnect();
    };

    try {
      await client.connect(
        host: poolHost,
        port: poolPort,
        user: '${wallet.trim()}.${workerName.trim()}',
        password: poolPassword,
      );
    } catch (e) {
      log('Connexion impossible : $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wantsMining) return;
    _engine.pause();
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    if (_reconnectAttempts > 6) {
      _wantsMining = false;
      status = MinerStatus.error;
      statusMessage = 'Pool injoignable';
      log('Abandon apres 6 tentatives. Verifie ta connexion ou le serveur du pool.');
      notifyListeners();
      return;
    }
    final delay = Duration(seconds: 3 * _reconnectAttempts);
    status = MinerStatus.connecting;
    statusMessage = 'Reconnexion dans ${delay.inSeconds} s';
    log('Nouvelle tentative dans ${delay.inSeconds} secondes '
        '($_reconnectAttempts/6).');
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      if (_wantsMining) _connect();
    });
  }

  Future<void> stop() async {
    _recordSession();
    _wantsMining = false;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _ticker?.cancel();
    _ticker = null;
    await _client?.disconnect();
    _client = null;
    await _engine.stop();
    _setWakelock(false);
    if (backgroundServiceActive) {
      await ForegroundService.stop();
      backgroundServiceActive = false;
    }
    status = MinerStatus.stopped;
    statusMessage = 'A l\'arret';
    hashrate = 0;
    startedAt = null;
    job = null;
    log('Minage arrete.');
    notifyListeners();
  }

  Future<void> toggle() => _wantsMining ? stop() : start();

  // ---------------------------------------------------------------------------

  void _pushWork() {
    final j = _job;
    if (j == null || _extranonce1.isEmpty || poolDifficulty <= 0) return;

    _extranonce2Counter = (_extranonce2Counter + 1) & 0x7fffffff;
    final en2 = _extranonce2Counter
        .toRadixString(16)
        .padLeft(_extranonce2Size * 2, '0');
    final root = j.merkleRootFor(_extranonce1, en2);
    final header = j.headerFor(root);
    final target = targetFromDifficulty(poolDifficulty);

    job = JobSnapshot(
      jobId: j.jobId,
      prevHash: j.prevHash,
      merkleRoot: bytesToHex(root),
      version: j.version,
      nBits: j.nBits,
      nTime: j.nTime,
      extranonce1: _extranonce1,
      extranonce2: en2,
      targetHex: bytesToHex(target),
      difficulty: poolDifficulty,
      transactionsCount: j.merkleBranch.length,
      receivedAt: DateTime.now(),
    );

    _engine.setWork(WorkPackage(
      jobId: j.jobId,
      header: header,
      target: target,
      extranonce2: en2,
      nTime: j.nTime,
      startNonce: _random.nextInt(0x7fffffff),
    ));

    if (status == MinerStatus.waitingJob) {
      status = MinerStatus.mining;
      statusMessage = 'Minage en cours sur $poolHost';
    }
    notifyListeners();
  }

  void _onShareFound(FoundShare share) {
    if (share.difficulty > bestDifficulty) {
      bestDifficulty = share.difficulty;
    }
    final client = _client;
    if (client == null || !client.isConnected || !_authorized) {
      _pendingShares.add(share);
      log('Solution trouvee hors connexion : mise de cote '
          '(${_pendingShares.length} en attente).');
      notifyListeners();
      return;
    }
    log('Solution trouvee (difficulte ${share.difficulty.toStringAsFixed(3)}), '
        'envoi au pool.');
    client.submit(
      worker: '${wallet.trim()}.${workerName.trim()}',
      share: share,
    );
  }

  /// Une part ne vaut que pour le travail auquel elle repond : apres une
  /// coupure, celles qui visaient un travail perime sont abandonnees.
  void _flushPendingShares() {
    if (_pendingShares.isEmpty) return;
    final client = _client;
    final currentJobId = _job?.jobId;
    if (client == null || !client.isConnected || currentJobId == null) return;

    var sent = 0, dropped = 0;
    for (final share in List<FoundShare>.from(_pendingShares)) {
      if (share.jobId == currentJobId) {
        client.submit(
          worker: '${wallet.trim()}.${workerName.trim()}',
          share: share,
        );
        sent++;
      } else {
        dropped++;
      }
    }
    _pendingShares.clear();
    if (sent > 0) log('$sent part(s) en attente envoyee(s) au pool.');
    if (dropped > 0) {
      log('$dropped part(s) abandonnee(s) : le travail vise n\'est plus valide.');
    }
    notifyListeners();
  }

  void _recordSession() {
    final started = startedAt;
    if (started == null || totalHashes == 0) return;
    final seconds = DateTime.now().difference(started).inSeconds;
    if (seconds < 10) return;
    sessions.insert(
      0,
      MiningSession(
        startedAt: started,
        seconds: seconds,
        hashes: totalHashes,
        averageHashrate: seconds == 0 ? 0 : totalHashes / seconds,
        bestDifficulty: bestDifficulty,
        accepted: accepted,
        rejected: rejected,
        pool: poolHost,
        threads: effectiveThreads,
      ),
    );
    while (sessions.length > 50) {
      sessions.removeLast();
    }
    SharedPreferences.getInstance().then(
      (p) => p.setString('sessions', MiningSession.encodeList(sessions)),
    );
  }

  void setThreads(int value) {
    threads = value;
    notifyListeners();
  }

  void setIntensity(int value) {
    intensity = value.clamp(10, 100);
    _engine.setIntensity(intensity);
    notifyListeners();
  }

  void setAutoStopMinutes(int value) {
    autoStopMinutes = value;
    notifyListeners();
  }

  void setKeepScreenOn(bool value) {
    keepScreenOn = value;
    if (isActive) _setWakelock(value);
    notifyListeners();
  }

  Future<void> clearSessions() async {
    sessions.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove('sessions');
    log('Historique efface.');
    notifyListeners();
  }

  /// Totaux cumules de toutes les sessions conservees.
  ({int hashes, int seconds, int accepted, double best}) get lifetime {
    var hashes = 0, seconds = 0, accepted = 0;
    var best = 0.0;
    for (final s in sessions) {
      hashes += s.hashes;
      seconds += s.seconds;
      accepted += s.accepted;
      if (s.bestDifficulty > best) best = s.bestDifficulty;
    }
    return (hashes: hashes, seconds: seconds, accepted: accepted, best: best);
  }

  void _updateNotification() {
    final parts = accepted == 0
        ? 'aucune part pour l\'instant'
        : '$accepted part(s) acceptee(s)';
    ForegroundService.update(
      title: '${formatHashrate(hashrate)} - $poolHost',
      text: '$parts - ${formatDuration(uptime)} de minage',
    );
  }

  /// Empeche l'ecran de s'eteindre pendant le minage. Sans effet sur les
  /// plateformes qui ne le supportent pas.
  void _setWakelock(bool enable) {
    try {
      WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Plateforme non supportee : on ignore.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _reconnectTimer?.cancel();
    _autoStopTimer?.cancel();
    _client?.disconnect();
    _engine.stop();
    _setWakelock(false);
    ForegroundService.stop();
    super.dispose();
  }
}
