import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bitcoin_utils.dart';

/// Resultat de l'auto-test du moteur GPU.
///
/// Le principe est simple et non negociable : tant que la carte n'a pas
/// reproduit exactement les hachages du processeur, aucun de ses resultats
/// n'est utilise, et rien n'est envoye a un pool.
class GpuSelfTest {
  const GpuSelfTest({
    required this.passed,
    required this.trials,
    required this.message,
    this.mismatchHeader,
    this.cpuHash,
    this.gpuHash,
    this.hashrate,
  });

  final bool passed;
  final int trials;
  final String message;

  /// En-tete fautif, conserve pour pouvoir rejouer le cas.
  final String? mismatchHeader;
  final String? cpuHash;
  final String? gpuHash;

  /// Debit mesure pendant le test de recherche, en hachages par seconde.
  final double? hashrate;

  static const GpuSelfTest notRun = GpuSelfTest(
    passed: false,
    trials: 0,
    message: 'Auto-test non lance.',
  );
}

typedef _InitNative = Int32 Function(Int32, Pointer<Uint8>, Int32);
typedef _InitDart = int Function(int, Pointer<Uint8>, int);
typedef _HashNative = Int32 Function(Pointer<Uint8>, Uint32, Pointer<Uint8>);
typedef _HashDart = int Function(Pointer<Uint8>, int, Pointer<Uint8>);
typedef _SearchNative = Int32 Function(
    Pointer<Uint8>, Uint32, Uint32, Uint32, Pointer<Uint32>, Int32);
typedef _SearchDart = int Function(
    Pointer<Uint8>, int, int, int, Pointer<Uint32>, int);
typedef _ShutdownNative = Void Function();
typedef _ShutdownDart = void Function();

/// Pont vers le moteur de hachage OpenCL.
class GpuMiner {
  GpuMiner._(this._library);

  final DynamicLibrary _library;
  bool _ready = false;

  bool get isReady => _ready;

  static GpuMiner? _instance;

  /// Charge la bibliotheque native. Renvoie null si elle est absente, ce qui
  /// est le cas normal partout sauf sur la version Windows.
  static GpuMiner? open() {
    if (!Platform.isWindows) return null;
    if (_instance != null) return _instance;
    try {
      _instance = GpuMiner._(DynamicLibrary.open('gpu_probe.dll'));
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// Prepare le peripherique : contexte, file, compilation du noyau. Le
  /// message renvoye contient le journal du compilateur en cas d'echec, seule
  /// information exploitable pour corriger a distance.
  ({bool ok, String message}) initialise({int deviceIndex = 0}) {
    final error = calloc<Uint8>(8192);
    try {
      final code = _library.lookupFunction<_InitNative, _InitDart>(
          'gpu_miner_init')(deviceIndex, error, 8192);
      final message = _readString(error, 8192);
      _ready = code == 0;
      return (ok: _ready, message: message.isEmpty ? 'Code $code.' : message);
    } catch (e) {
      return (ok: false, message: 'Appel natif impossible : $e');
    } finally {
      calloc.free(error);
    }
  }

  /// Hash complet d'un nonce : la fonction de verification.
  Uint8List? hashOne(Uint8List header80, int nonce) {
    if (!_ready) return null;
    final headerPointer = calloc<Uint8>(80);
    final outPointer = calloc<Uint8>(32);
    try {
      for (var i = 0; i < 80; i++) {
        headerPointer[i] = header80[i];
      }
      final code = _library.lookupFunction<_HashNative, _HashDart>(
          'gpu_miner_hash')(headerPointer, nonce, outPointer);
      if (code != 0) return null;
      final result = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        result[i] = outPointer[i];
      }
      return result;
    } catch (_) {
      return null;
    } finally {
      calloc.free(headerPointer);
      calloc.free(outPointer);
    }
  }

  /// Balaye [count] nonces et renvoie les candidats sous le seuil.
  List<int> search({
    required Uint8List header80,
    required int baseNonce,
    required int count,
    required int targetHead,
    int maxResults = 64,
  }) {
    if (!_ready) return const <int>[];
    final headerPointer = calloc<Uint8>(80);
    final outPointer = calloc<Uint32>(maxResults);
    try {
      for (var i = 0; i < 80; i++) {
        headerPointer[i] = header80[i];
      }
      final found = _library.lookupFunction<_SearchNative, _SearchDart>(
          'gpu_miner_search')(
        headerPointer,
        baseNonce,
        count,
        targetHead,
        outPointer,
        maxResults,
      );
      if (found <= 0) return const <int>[];
      return [for (var i = 0; i < found; i++) outPointer[i]];
    } catch (_) {
      return const <int>[];
    } finally {
      calloc.free(headerPointer);
      calloc.free(outPointer);
    }
  }

  void shutdown() {
    try {
      _library.lookupFunction<_ShutdownNative, _ShutdownDart>(
          'gpu_miner_shutdown')();
    } catch (_) {
      // Rien a faire : la bibliotheque n'etait pas chargee.
    }
    _ready = false;
  }

  static String _readString(Pointer<Uint8> pointer, int capacity) {
    final bytes = <int>[];
    for (var i = 0; i < capacity; i++) {
      final byte = pointer[i];
      if (byte == 0) break;
      bytes.add(byte);
    }
    return String.fromCharCodes(bytes);
  }
}

/// En-tete authentique du bloc 125552, avec son nonce : le premier cas que la
/// carte doit reproduire.
const String kReferenceHeader =
    '0100000081cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000'
    'e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122b'
    'c7f5d74df2b9441a42a14695';
const int kReferenceNonce = 0x9546a142;
const String kReferenceHash =
    '00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d';

/// Verifie la carte contre le processeur, puis mesure son debit.
///
/// L'ordre compte : on ne mesure la vitesse qu'apres avoir etabli la justesse.
GpuSelfTest runGpuSelfTest({int randomTrials = 64}) {
  final miner = GpuMiner.open();
  if (miner == null) {
    return const GpuSelfTest(
      passed: false,
      trials: 0,
      message: 'Moteur GPU disponible uniquement sur la version Windows.',
    );
  }

  final init = miner.initialise();
  if (!init.ok) {
    return GpuSelfTest(passed: false, trials: 0, message: init.message);
  }

  // 1. Le bloc reel 125552.
  final reference = hexToBytes(kReferenceHeader);
  final referenceGpu = miner.hashOne(reference, kReferenceNonce);
  if (referenceGpu == null) {
    return const GpuSelfTest(
      passed: false,
      trials: 0,
      message: 'La carte n\'a pas repondu au premier hachage.',
    );
  }
  if (bytesToHex(reverseBytes(referenceGpu)) != kReferenceHash) {
    return GpuSelfTest(
      passed: false,
      trials: 1,
      message: 'La carte ne reproduit pas le bloc 125552. Moteur GPU desactive.',
      mismatchHeader: kReferenceHeader,
      cpuHash: kReferenceHash,
      gpuHash: bytesToHex(reverseBytes(referenceGpu)),
    );
  }

  // 2. Des en-tetes aleatoires, compares au moteur du processeur.
  final random = Random(125552);
  for (var trial = 0; trial < randomTrials; trial++) {
    final header = Uint8List(80);
    for (var i = 0; i < 80; i++) {
      header[i] = random.nextInt(256);
    }
    final nonce = random.nextInt(0xFFFFFFFF);
    header[76] = nonce & 0xff;
    header[77] = (nonce >> 8) & 0xff;
    header[78] = (nonce >> 16) & 0xff;
    header[79] = (nonce >> 24) & 0xff;

    final gpu = miner.hashOne(header, nonce);
    final cpu = sha256d(header);
    if (gpu == null || bytesToHex(gpu) != bytesToHex(cpu)) {
      return GpuSelfTest(
        passed: false,
        trials: trial + 1,
        message: 'Divergence au ${trial + 1}e essai. Moteur GPU desactive.',
        mismatchHeader: bytesToHex(header),
        cpuHash: bytesToHex(cpu),
        gpuHash: gpu == null ? 'aucune reponse' : bytesToHex(gpu),
      );
    }
  }

  // 3. Mesure du debit sur une vraie recherche.
  final header = hexToBytes(kReferenceHeader);
  const batch = 1 << 20; // un million de nonces
  final start = DateTime.now();
  miner.search(
    header80: header,
    baseNonce: 0,
    count: batch,
    targetHead: 0, // seuil impossible : on mesure, on ne cherche rien
  );
  final elapsed = DateTime.now().difference(start).inMicroseconds;
  final hashrate = elapsed <= 0 ? 0.0 : batch * 1000000 / elapsed;

  return GpuSelfTest(
    passed: true,
    trials: randomTrials + 1,
    message: 'Carte conforme sur ${randomTrials + 1} hachages, bloc 125552 '
        'compris.',
    hashrate: hashrate,
  );
}
