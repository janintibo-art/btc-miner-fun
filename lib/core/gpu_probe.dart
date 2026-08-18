import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'platform_profile.dart';

/// Un peripherique de calcul vu par OpenCL.
class GpuDevice {
  const GpuDevice({
    required this.name,
    required this.vendor,
    required this.version,
    required this.computeUnits,
    required this.clockMHz,
    required this.memoryMiB,
    required this.kind,
  });

  final String name;
  final String vendor;
  final String version;

  /// Unites de calcul : chacune contient des dizaines a des centaines de
  /// coeurs elementaires. C'est la mesure de parallelisme la plus parlante.
  final int computeUnits;

  final int clockMHz;
  final int memoryMiB;

  /// 2 = processeur, 4 = carte graphique, 8 = accelerateur dedie.
  final int kind;

  bool get isGpu => kind == 4;

  String get kindLabel => switch (kind) {
        2 => 'Processeur',
        4 => 'Carte graphique',
        8 => 'Accelerateur',
        _ => 'Peripherique',
      };

  /// Ordre de grandeur du parallelisme disponible, a titre indicatif.
  int get parallelSlots => computeUnits * 64;
}

/// Le resultat d'une detection, message compris.
class GpuProbeResult {
  const GpuProbeResult({
    required this.devices,
    required this.message,
    required this.available,
  });

  final List<GpuDevice> devices;
  final String message;

  /// Vrai si un peripherique exploitable a ete trouve.
  final bool available;

  static const GpuProbeResult notProbed = GpuProbeResult(
    devices: <GpuDevice>[],
    message: 'Detection non lancee.',
    available: false,
  );
}

typedef _ProbeNative = Int32 Function(Pointer<Uint8>, Int32);
typedef _ProbeDart = int Function(Pointer<Uint8>, int);
typedef _VersionNative = Int32 Function();
typedef _VersionDart = int Function();

/// Interroge le pont natif. Rien de tout cela n'est bloquant : en l'absence de
/// bibliotheque, de pilote ou de materiel compatible, la fonction renvoie
/// simplement une explication.
GpuProbeResult probeGpuDevices() {
  if (!PlatformProfile.isDesktop || !Platform.isWindows) {
    return const GpuProbeResult(
      devices: <GpuDevice>[],
      message: 'La detection materielle n\'existe que sur la version Windows.',
      available: false,
    );
  }

  DynamicLibrary library;
  try {
    library = DynamicLibrary.open('gpu_probe.dll');
  } catch (e) {
    return const GpuProbeResult(
      devices: <GpuDevice>[],
      message: 'Pont natif introuvable : gpu_probe.dll doit se trouver a cote '
          'de l\'executable.',
      available: false,
    );
  }

  const capacity = 8192;
  final buffer = calloc<Uint8>(capacity);
  try {
    final abi = library
        .lookupFunction<_VersionNative, _VersionDart>('gpu_probe_abi_version')();
    final count = library
        .lookupFunction<_ProbeNative, _ProbeDart>('gpu_probe_list')(
      buffer,
      capacity,
    );

    if (count < 0) {
      return GpuProbeResult(
        devices: const <GpuDevice>[],
        message: switch (count) {
          -1 => 'OpenCL n\'est pas installe sur cette machine. Il arrive '
              'normalement avec les pilotes de la carte graphique.',
          -2 => 'OpenCL est present mais ne declare aucune plateforme : les '
              'pilotes de la carte sont probablement a mettre a jour.',
          -3 => 'Reponse trop volumineuse pour le tampon de lecture.',
          _ => 'Detection impossible (code $count).',
        },
        available: false,
      );
    }

    final devices = _parse(buffer, capacity);
    return GpuProbeResult(
      devices: devices,
      message: devices.isEmpty
          ? 'Aucun peripherique de calcul detecte.'
          : '${devices.length} peripherique(s) detecte(s) - pont natif v$abi.',
      available: devices.any((device) => device.isGpu),
    );
  } catch (e) {
    return GpuProbeResult(
      devices: const <GpuDevice>[],
      message: 'Erreur pendant la detection : $e',
      available: false,
    );
  } finally {
    calloc.free(buffer);
  }
}

List<GpuDevice> _parse(Pointer<Uint8> buffer, int capacity) {
  final bytes = <int>[];
  for (var i = 0; i < capacity; i++) {
    final byte = buffer[i];
    if (byte == 0) break;
    bytes.add(byte);
  }
  final text = String.fromCharCodes(bytes);

  final devices = <GpuDevice>[];
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) continue;
    final fields = line.split('|');
    if (fields.length < 7) continue;
    devices.add(GpuDevice(
      name: fields[0],
      vendor: fields[1],
      version: fields[2],
      computeUnits: int.tryParse(fields[3]) ?? 0,
      clockMHz: int.tryParse(fields[4]) ?? 0,
      memoryMiB: int.tryParse(fields[5]) ?? 0,
      kind: int.tryParse(fields[6]) ?? 0,
    ));
  }
  return devices;
}
