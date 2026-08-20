/// Limiteur thermique.
///
/// Un telephone n'a aucun refroidissement actif : passe un certain seuil, il
/// se bride lui-meme, et la puissance de calcul chute tout en continuant a
/// vider la batterie. Autant reduire la cadence avant d'y arriver.
///
/// Le limiteur ne remplace pas le reglage d'intensite : il en abaisse
/// temporairement le plafond, et le rend des que l'appareil a refroidi.
class ThermalGuard {
  ThermalGuard({
    this.warmThreshold = 39,
    this.hotThreshold = 43,
    this.minimumIntensity = 25,
  });

  /// Temperature a partir de laquelle on commence a ralentir.
  final double warmThreshold;

  /// Temperature au-dela de laquelle on descend au minimum.
  final double hotThreshold;

  /// Intensite plancher : en dessous, autant arreter de miner.
  final int minimumIntensity;

  double? lastTemperature;
  int? appliedIntensity;

  /// Calcule l'intensite a appliquer pour une temperature donnee.
  ///
  /// En dessous du seuil tiede, l'intensite choisie par l'utilisateur est
  /// rendue telle quelle. Entre les deux seuils, elle decroit
  /// progressivement : pas de palier brutal qui ferait osciller la machine.
  int intensityFor(double temperature, int userIntensity) {
    if (temperature < warmThreshold) return userIntensity;
    if (temperature >= hotThreshold) return minimumIntensity;

    final ratio =
        (temperature - warmThreshold) / (hotThreshold - warmThreshold);
    final reduced = userIntensity - (userIntensity - minimumIntensity) * ratio;
    return reduced.round().clamp(minimumIntensity, userIntensity);
  }

  /// Description lisible de l'etat thermique.
  String describe(double? temperature) {
    if (temperature == null) return 'Temperature indisponible';
    if (temperature < warmThreshold) {
      return '${temperature.toStringAsFixed(1)} °C - normal';
    }
    if (temperature < hotThreshold) {
      return '${temperature.toStringAsFixed(1)} °C - ralentissement en cours';
    }
    return '${temperature.toStringAsFixed(1)} °C - cadence minimale';
  }

  bool isThrottling(double? temperature) =>
      temperature != null && temperature >= warmThreshold;
}
