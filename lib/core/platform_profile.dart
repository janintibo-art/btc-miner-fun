import 'dart:io';

/// Un ordinateur et un telephone ne meritent pas les memes reglages.
///
/// Le telephone n'a aucun refroidissement actif : au-dela de la moitie des
/// coeurs, il se bride tout seul et vide sa batterie. Un ordinateur de bureau
/// est ventile, branche au secteur, et peut travailler a fond sans dommage.
class PlatformProfile {
  PlatformProfile._();

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static int get availableCores => Platform.numberOfProcessors.clamp(1, 64);

  /// Sur ordinateur, on garde un coeur pour le systeme et l'interface.
  /// Sur telephone, on reste volontairement prudent.
  static int get recommendedThreads {
    if (isDesktop) return (availableCores - 1).clamp(1, 32);
    return (availableCores / 2).floor().clamp(1, 4);
  }

  /// Le curseur d'intensite protege de la chaleur : inutile sur une machine
  /// ventilee.
  static int get defaultIntensity => isDesktop ? 100 : 100;

  /// L'ecran allume n'a de sens que sur un appareil qui s'endort.
  static bool get canKeepScreenOn => isMobile;

  /// Largeur a partir de laquelle une disposition en colonnes devient utile.
  static const double wideBreakpoint = 900;
}
