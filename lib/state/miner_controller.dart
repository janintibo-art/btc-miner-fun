import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/address_validator.dart';
import '../core/bitcoin_utils.dart';
import '../core/benchmark.dart';
import '../core/foreground_service.dart';
import '../core/hash_mode.dart';
import '../core/nonce_walker.dart';
import '../core/price_service.dart';
import '../core/wallet_watch.dart';
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
      'Solo sans commission, pense pour les tres petits mineurs. '
      'Difficulte minimale tres basse : le meilleur choix ici.'),
  PoolPreset('CKPool solo', 'solo.ckpool.org', 3333,
      'Solo historique, 2 % de commission. Difficulte plus elevee, '
      'donc des parts beaucoup plus rares.'),
  PoolPreset('CKPool partage', 'stratum.ckpool.org', 3333,
      'Pool partage : les gains sont proportionnels au travail fourni. '
      'Un telephone n\'atteindra jamais le seuil de paiement, mais les '
      'parts acceptees y sont plus frequentes.'),
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
  String? _pendingExtranonce1;
  int? _pendingExtranonce2Size;
  double _activeJobDifficulty = 0;
  bool _wantsMining = false;
  bool _shuttingDown = false;
  int _reconnectAttempts = 0;
  DateTime _lastStatsUiNotify = DateTime.fromMillisecondsSinceEpoch(0);

  int _lifetimeHashes = 0;
  int _lifetimeSeconds = 0;
  int _lifetimeAccepted = 0;
  double _lifetimeBest = 0;

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
  HashMode hashMode = HashMode.midstate;
  NonceStrategy nonceStrategy = NonceStrategy.signature;
  String signaturePhrase = '';
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
  MarketData? market;
  bool priceLoading = false;
  WalletBalance? balance;
  bool balanceLoading = false;
  String? balanceError;
  bool benchmarkRunning = false;
  BenchmarkResult? benchmark;

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

  /// Verification complete : le code de controle de l'adresse est recalcule.
  AddressCheck get walletCheck => checkBitcoinAddress(wallet);

  bool get walletLooksValid => walletCheck.valid;

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
    hashMode = HashModeInfo.fromName(p.getString('hashMode'));
    nonceStrategy = NonceStrategyInfo.fromName(p.getString('nonceStrategy'));
    signaturePhrase = p.getString('signaturePhrase') ?? '';
    market = MarketData.tryDecode(p.getString('market'));
    final cached = WalletBalance.tryDecode(p.getString('balance'));
    if (cached != null && cached.address == wallet.trim()) balance = cached;
    sessions.addAll(MiningSession.decodeList(p.getString('sessions') ?? '[]'));

    if (p.containsKey('lifetimeHashes')) {
      _lifetimeHashes = p.getInt('lifetimeHashes') ?? 0;
      _lifetimeSeconds = p.getInt('lifetimeSeconds') ?? 0;
      _lifetimeAccepted = p.getInt('lifetimeAccepted') ?? 0;
      _lifetimeBest = p.getDouble('lifetimeBest') ?? 0;
    } else {
      // Migration v11 : initialiser les nouveaux compteurs avec les sessions
      // encore presentes sur l'appareil.
      for (final session in sessions) {
        _lifetimeHashes += session.hashes;
        _lifetimeSeconds += session.seconds;
        _lifetimeAccepted += session.accepted;
        if (session.bestDifficulty > _lifetimeBest) {
          _lifetimeBest = session.bestDifficulty;
        }
      }
      await _persistLifetime();
    }

    _engine.onStats = (hps, total) {
      hashrate = hps;
      totalHashes = total;
      if (status == MinerStatus.waitingJob && hps > 0) {
        status = MinerStatus.mining;
        statusMessage = 'Minage en cours sur $poolHost';
      }
      // Plusieurs isolates publient souvent presque au meme instant. On garde
      // toutes les mesures mais on limite les reconstructions de l'interface.
      final now = DateTime.now();
      if (now.difference(_lastStatsUiNotify) >=
          const Duration(milliseconds: 250)) {
        _lastStatsUiNotify = now;
        notifyListeners();
      }
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
    await p.setString('hashMode', hashMode.name);
    await p.setString('nonceStrategy', nonceStrategy.name);
    await p.setString('signaturePhrase', signaturePhrase);
    if (balance != null && balance!.address != wallet.trim()) {
      balance = null;
      balanceError = null;
      await p.remove('balance');
    }
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
      log('Adresse refusee : ${walletCheck.message}');
      log('Ouvre l\'assistant portefeuille dans Reglages pour la verifier.');
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
    _activeJobDifficulty = 0;
    _pendingExtranonce1 = null;
    _pendingExtranonce2Size = null;
    _extranonce1 = '';
    job = null;
    _job = null;
    history.clear();
    startedAt = DateTime.now();

    _pendingShares.clear();
    _authorized = false;
    _engine.configureWalk(nonceStrategy, signature);
    try {
      await _engine.start(effectiveThreads, mode: hashMode);
    } catch (e) {
      await _failMining(
        'Moteur indisponible',
        'Impossible de demarrer les isolates de minage : $e',
      );
      return;
    }
    if (nonceStrategy == NonceStrategy.signature) {
      log('Marche signature ${signature.fingerprint} : '
          'permutation complete des 4 294 967 296 nonces.');
    }
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
    if (!_wantsMining) return;

    // Une reconnexion repart avec un etat Stratum propre. La difficulte et
    // l'extranonce appartiennent a la connexion courante et ne doivent pas etre
    // reutilises aveuglement apres une coupure.
    final previous = _client;
    _client = null;
    if (previous != null) {
      await previous.disconnect();
    }
    if (!_wantsMining) return;

    _authorized = false;
    _job = null;
    job = null;
    poolDifficulty = 0;
    _activeJobDifficulty = 0;
    _extranonce1 = '';
    _pendingExtranonce1 = null;
    _pendingExtranonce2Size = null;

    status = MinerStatus.connecting;
    statusMessage = 'Connexion a $poolHost';
    notifyListeners();

    final client = StratumClient();
    _client = client;
    bool isCurrent() => identical(_client, client);

    client.onLog = (line) {
      if (isCurrent()) log(line);
    };
    client.onSubscribed = (e1, size) {
      if (!isCurrent()) return;
      _extranonce1 = e1;
      _extranonce2Size = size;
      _extranonce2Counter = 0;
    };
    client.onExtranonce = (e1, size) {
      if (!isCurrent()) return;
      // Stratum V1 : ces valeurs prennent effet au prochain mining.notify.
      _pendingExtranonce1 = e1;
      _pendingExtranonce2Size = size;
    };
    client.onAuthorized = (ok) {
      if (!isCurrent()) return;
      _authorized = ok;
      if (ok) {
        status = MinerStatus.waitingJob;
        statusMessage = "En attente d'un travail du pool";
        notifyListeners();
      } else {
        unawaited(_failMining(
          'Refuse par le pool',
          'Le pool a refuse le worker. Le moteur et le service Android ont ete arretes.',
        ));
      }
    };
    client.onDifficulty = (d) {
      if (!isCurrent()) return;
      // Une difficulte annoncee en cours de route ne s'applique qu'au prochain
      // job : changer la cible d'un travail deja lance invaliderait les parts
      // en vol. Exception : si aucun travail n'a encore demarre, il ne faut pas
      // attendre le job suivant, qui peut mettre une minute a arriver.
      poolDifficulty = d;
      if (_activeJobDifficulty <= 0 && _job != null && d > 0) {
        _activeJobDifficulty = d;
        log('Difficulte recue apres le premier job : demarrage immediat.');
        _pushWork();
        _flushPendingShares();
      }
      notifyListeners();
    };
    client.onJob = (j) {
      if (!isCurrent()) return;

      if (_pendingExtranonce1 != null && _pendingExtranonce2Size != null) {
        _extranonce1 = _pendingExtranonce1!;
        _extranonce2Size = _pendingExtranonce2Size!;
        _extranonce2Counter = 0;
        _pendingExtranonce1 = null;
        _pendingExtranonce2Size = null;
        log('Nouvel extranonce applique au job ${j.jobId}.');
      }

      _job = j;
      jobsReceived++;
      _reconnectAttempts = 0;
      if (poolDifficulty <= 0) {
        status = MinerStatus.waitingJob;
        statusMessage = 'Job recu, attente de la difficulte du pool';
        log("Job ${j.jobId} conserve en attente d'une difficulte valide.");
        notifyListeners();
        return;
      }

      _activeJobDifficulty = poolDifficulty;
      _pushWork();
      _flushPendingShares();
    };
    client.onSubmitResult = (ok, reason) {
      if (!isCurrent()) return;
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
      if (!isCurrent()) return;
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
      if (!isCurrent() || !_wantsMining) return;
      log('Connexion impossible : $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_wantsMining || _shuttingDown) return;
    _engine.pause();
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    if (_reconnectAttempts > 6) {
      unawaited(_failMining(
        'Pool injoignable',
        'Abandon apres 6 reconnexions. Verifie ta connexion ou le serveur du pool.',
      ));
      return;
    }
    final delay = Duration(seconds: 3 * _reconnectAttempts);
    status = MinerStatus.connecting;
    statusMessage = 'Reconnexion dans ${delay.inSeconds} s';
    log('Nouvelle tentative dans ${delay.inSeconds} secondes '
        '($_reconnectAttempts/6).');
    notifyListeners();
    _reconnectTimer = Timer(delay, () {
      if (_wantsMining) unawaited(_connect());
    });
  }

  Future<void> _cleanupRuntime({bool recordSession = true}) async {
    // Couper d'abord la production de nouveau travail : la persistance de
    // l'historique ne doit jamais retarder l'arret du calcul ou du reseau.
    _wantsMining = false;
    _engine.pause();
    if (recordSession) {
      try {
        await _recordSession();
      } catch (e) {
        log("Historique non enregistre pendant l'arret : $e");
      }
    }
    _authorized = false;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _ticker?.cancel();
    _ticker = null;

    final client = _client;
    _client = null;
    await client?.disconnect();
    await _engine.stop();
    _setWakelock(false);
    if (backgroundServiceActive) {
      await ForegroundService.stop();
      backgroundServiceActive = false;
    }

    _pendingShares.clear();
    _job = null;
    job = null;
    hashrate = 0;
    _activeJobDifficulty = 0;
    _pendingExtranonce1 = null;
    _pendingExtranonce2Size = null;
    startedAt = null;
  }

  Future<void> _failMining(String message, String detail) async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    try {
      await _cleanupRuntime();
      status = MinerStatus.error;
      statusMessage = message;
      log(detail);
      notifyListeners();
    } finally {
      _shuttingDown = false;
    }
  }

  Future<void> stop() async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    try {
      await _cleanupRuntime();
      status = MinerStatus.stopped;
      statusMessage = "A l'arret";
      log('Minage arrete.');
      notifyListeners();
    } finally {
      _shuttingDown = false;
    }
  }

  Future<void> toggle() => _wantsMining ? stop() : start();

  // ---------------------------------------------------------------------------

  void _pushWork() {
    final j = _job;
    if (j == null || _extranonce1.isEmpty || _activeJobDifficulty <= 0) return;

    // L'extranonce2 doit avoir exactement la taille annoncee par le pool.
    // Pour les petites tailles (< 4 octets), boucler avant de depasser la largeur.
    final en2Bits = _extranonce2Size * 8;
    final en2Mask = en2Bits > 0 && en2Bits < 31
        ? (1 << en2Bits) - 1
        : 0x7fffffff;
    _extranonce2Counter = (_extranonce2Counter + 1) & en2Mask;
    final en2 = _extranonce2Counter
        .toRadixString(16)
        .padLeft(_extranonce2Size * 2, '0');
    final root = j.merkleRootFor(_extranonce1, en2);
    final header = j.headerFor(root);
    final target = targetFromDifficulty(_activeJobDifficulty);

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
      difficulty: _activeJobDifficulty,
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

  Future<void> _recordSession() async {
    final started = startedAt;
    if (started == null || totalHashes == 0) return;
    final seconds = max(1, DateTime.now().difference(started).inSeconds);

    // Les totaux "Depuis le debut" sont conserves independamment des 50
    // sessions affichees. Ils ne disparaissent donc plus quand la liste tourne.
    _lifetimeHashes += totalHashes;
    _lifetimeSeconds += seconds;
    _lifetimeAccepted += accepted;
    if (bestDifficulty > _lifetimeBest) _lifetimeBest = bestDifficulty;
    await _persistLifetime();

    if (seconds < 10) return;
    sessions.insert(
      0,
      MiningSession(
        startedAt: started,
        seconds: seconds,
        hashes: totalHashes,
        averageHashrate: totalHashes / seconds,
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
    final p = await SharedPreferences.getInstance();
    await p.setString('sessions', MiningSession.encodeList(sessions));
  }

  Future<void> _persistLifetime() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('lifetimeHashes', _lifetimeHashes);
    await p.setInt('lifetimeSeconds', _lifetimeSeconds);
    await p.setInt('lifetimeAccepted', _lifetimeAccepted);
    await p.setDouble('lifetimeBest', _lifetimeBest);
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

  /// La phrase reellement utilisee : celle saisie, ou a defaut une phrase
  /// derivee de l'adresse et du nom du worker.
  String get effectiveSignaturePhrase => signaturePhrase.trim().isEmpty
      ? defaultSignaturePhrase(wallet.trim(), workerName.trim())
      : signaturePhrase.trim();

  NonceSignature get signature =>
      NonceSignature.fromPhrase(effectiveSignaturePhrase);

  void setNonceStrategy(NonceStrategy value) {
    nonceStrategy = value;
    notifyListeners();
  }

  void setSignaturePhrase(String value) {
    signaturePhrase = value;
    notifyListeners();
  }

  /// Recupere le cours et l'etat du reseau. Le dernier resultat connu est
  /// conserve : hors connexion, la conversion continue de fonctionner.
  Future<void> refreshMarket() async {
    if (priceLoading) return;
    priceLoading = true;
    notifyListeners();
    try {
      final data = await PriceService.fetch();
      market = data;
      final p = await SharedPreferences.getInstance();
      await p.setString('market', data.encode());
      log('Cours mis a jour : ${formatEuros(data.eurPerBtc)} pour 1 bitcoin.');
    } catch (e) {
      log('Cours indisponible : verifie ta connexion.');
    }
    priceLoading = false;
    notifyListeners();
  }

  /// Consulte le solde de l'adresse configuree. Lecture seule : aucune cle
  /// n'existe dans cette application, aucune depense n'est possible.
  Future<void> refreshBalance([String? rawAddress]) async {
    final address = (rawAddress ?? wallet).trim();
    final check = checkBitcoinAddress(address);
    if (address.isEmpty || !check.valid) {
      balanceError = address.isEmpty
          ? "Configure d'abord une adresse valide."
          : check.message;
      notifyListeners();
      return;
    }
    if (balanceLoading) return;
    balanceLoading = true;
    balanceError = null;
    notifyListeners();
    try {
      final result = await WalletWatch.fetch(address);
      balance = result;
      final p = await SharedPreferences.getInstance();
      await p.setString('balance', result.encode());
      log(result.isEmpty
          ? "Adresse consultee : aucun mouvement pour l'instant."
          : 'Solde : ${formatBtc(result.totalBtc)} bitcoin.');
    } catch (e) {
      balanceError = 'Consultation impossible : verifie ta connexion.';
      log('Solde indisponible : $e');
    }
    balanceLoading = false;
    notifyListeners();
  }

  /// Cours saisi a la main, pour rester utilisable hors ligne.
  Future<void> setManualPrice(double eurPerBtc) async {
    final data = MarketData(
      eurPerBtc: eurPerBtc,
      usdPerBtc: 0,
      fetchedAt: DateTime.now(),
      networkHashrate: market?.networkHashrate,
      difficulty: market?.difficulty,
      manual: true,
    );
    market = data;
    final p = await SharedPreferences.getInstance();
    await p.setString('market', data.encode());
    log('Cours fixe manuellement a ${formatEuros(eurPerBtc)}.');
    notifyListeners();
  }

  void setHashMode(HashMode value) {
    hashMode = value;
    notifyListeners();
  }

  /// Mesure les trois moteurs sur un seul coeur, avec le meme en-tete.
  Future<void> runBenchmark() async {
    if (benchmarkRunning) return;
    benchmarkRunning = true;
    notifyListeners();
    try {
      benchmark = await runBenchmarkOnDevice();
      final r = benchmark!;
      log('Banc d\'essai : '
          '${formatHashrate(r.rates[HashMode.compatible] ?? 0)} en '
          'compatibilite, '
          '${formatHashrate(r.rates[HashMode.midstate] ?? 0)} en midstate '
          '(x${r.gainOver(HashMode.compatible, HashMode.midstate).toStringAsFixed(1)}).');
      if (!r.identical) {
        log('Attention : les moteurs ne donnent pas le meme hash. '
            'Reste en mode compatibilite.');
      }
    } catch (e) {
      log('Banc d\'essai impossible : $e');
    }
    benchmarkRunning = false;
    notifyListeners();
  }

  void setKeepScreenOn(bool value) {
    keepScreenOn = value;
    if (isActive) _setWakelock(value);
    notifyListeners();
  }

  Future<void> clearSessions() async {
    sessions.clear();
    _lifetimeHashes = 0;
    _lifetimeSeconds = 0;
    _lifetimeAccepted = 0;
    _lifetimeBest = 0;
    final p = await SharedPreferences.getInstance();
    await p.remove('sessions');
    await p.remove('lifetimeHashes');
    await p.remove('lifetimeSeconds');
    await p.remove('lifetimeAccepted');
    await p.remove('lifetimeBest');
    log('Historique et totaux cumules effaces.');
    notifyListeners();
  }

  /// Totaux persistants, independants de la limite de 50 sessions affichees.
  ({int hashes, int seconds, int accepted, double best}) get lifetime => (
        hashes: _lifetimeHashes,
        seconds: _lifetimeSeconds,
        accepted: _lifetimeAccepted,
        best: _lifetimeBest,
      );

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
