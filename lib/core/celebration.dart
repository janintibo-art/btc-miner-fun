import 'dart:async';

import 'package:flutter/services.dart';

/// Les petites recompenses sonores et tactiles.
///
/// Aucune bibliotheque audio n'est utilisee : uniquement les sons systeme et
/// le vibreur, disponibles partout et sans dependance. C'est discret, et ca
/// suffit largement quand l'appareil tourne sur un coin de bureau.
class Celebration {
  static bool enabled = true;

  /// Un bloc trouve : un clic sec et une pichenette.
  static Future<void> block() async {
    if (!enabled) return;
    unawaited(HapticFeedback.lightImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
  }

  /// Un bloc accepte par le serveur : deux clics rapproches.
  static Future<void> accepted() async {
    if (!enabled) return;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));
    await Future<void>.delayed(const Duration(milliseconds: 110));
    unawaited(SystemSound.play(SystemSoundType.click));
  }

  /// Un record : une petite fanfare de trois notes, en rythme.
  ///
  /// Les sons systeme n'ont pas de hauteur, mais le rythme suffit a se faire
  /// comprendre - et un rythme reconnaissable vaut mieux qu'un long message.
  static Future<void> record() async {
    if (!enabled) return;
    for (final pause in <int>[0, 90, 90, 200]) {
      await Future<void>.delayed(Duration(milliseconds: pause));
      unawaited(SystemSound.play(SystemSoundType.click));
      unawaited(HapticFeedback.mediumImpact());
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    unawaited(HapticFeedback.heavyImpact());
  }

  /// Un refus : une vibration seule, sans son. Une mauvaise nouvelle n'a pas
  /// besoin d'etre bruyante.
  static Future<void> rejected() async {
    if (!enabled) return;
    unawaited(HapticFeedback.selectionClick());
  }
}
