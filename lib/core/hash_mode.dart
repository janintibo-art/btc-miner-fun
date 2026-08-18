/// Les trois moteurs de hachage disponibles. Ils donnent tous exactement le
/// meme resultat : seule la vitesse change. C'est ce qui permet de les
/// comparer honnetement dans le banc d'essai.
enum HashMode {
  /// Paquet `crypto`, double SHA-256 complet a chaque tentative.
  compatible,

  /// SHA-256 maison, tampons reutilises, mais l'en-tete entier est rehache.
  maison,

  /// SHA-256 maison avec midstate et rejet precoce. Le mode par defaut.
  midstate,
}

extension HashModeInfo on HashMode {
  String get label => switch (this) {
        HashMode.compatible => 'Compatibilite',
        HashMode.maison => 'Maison',
        HashMode.midstate => 'Midstate',
      };

  String get description => switch (this) {
        HashMode.compatible =>
          'Le paquet crypto standard. Une allocation memoire a chaque '
              'tentative, l\'en-tete entier rehache. C\'est la reference.',
        HashMode.maison =>
          'SHA-256 ecrit a la main, tampons reutilises. Meme travail que la '
              'reference, mais sans gaspillage memoire.',
        HashMode.midstate =>
          'Le premier des deux blocs de l\'en-tete ne contient pas le nonce : '
              'il est calcule une fois par travail. S\'y ajoute un rejet '
              'precoce des que les premiers octets condamnent la tentative.',
      };

  static HashMode fromName(String? name) {
    return HashMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => HashMode.midstate,
    );
  }
}
