import 'package:flutter/services.dart';

/// Active FLAG_SECURE sur Android pendant l'affichage de la phrase de
/// recuperation. Les plateformes sans pont natif ignorent silencieusement la
/// demande : le portefeuille reste utilisable sur Windows.
class SecretScreenGuard {
  SecretScreenGuard._();

  static const _channel = MethodChannel('btc_miner_fun/security');

  static Future<void> setProtected(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setProtected', <String, bool>{
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Plateforme non patchee (ex. Windows).
    } on PlatformException {
      // La protection d'ecran est une defense supplementaire, pas une raison
      // de rendre inaccessible la sauvegarde du portefeuille.
    }
  }
}
