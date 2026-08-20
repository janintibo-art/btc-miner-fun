import 'dart:io';

import 'package:flutter/services.dart';

/// Pont vers le service de premier plan Android.
///
/// Sans lui, Android suspend l'application quelques minutes apres l'extinction
/// de l'ecran et le minage s'arrete. Le service maintient le processus vivant
/// et affiche une notification permanente : l'utilisateur sait toujours que
/// son appareil calcule.
///
/// Sur Windows, il n'y a rien a faire : les methodes ne font rien.
class ForegroundService {
  static const MethodChannel _channel = MethodChannel('btc_miner_fun/service');

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> start({
    required String title,
    required String text,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('start', {
            'title': title,
            'text': text,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> update({
    required String title,
    required String text,
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('update', {
        'title': title,
        'text': text,
      });
    } catch (_) {
      // Le service n'est pas actif : sans consequence.
    }
  }

  /// Temperature de la batterie, en degres, ou null si indisponible.
  ///
  /// C'est le seul capteur thermique lisible sans permission particuliere.
  /// Il ne mesure pas le processeur, mais il en suit fidelement
  /// l'echauffement : sur un telephone, les deux sont a quelques centimetres.
  static Future<double?> batteryTemperature() async {
    if (!isSupported) return null;
    try {
      final value = await _channel.invokeMethod<double>('temperature');
      if (value == null || value < 0) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  /// Vrai si l'utilisateur a touche "Arreter" dans la notification. Le
  /// drapeau est remis a zero par la lecture.
  static Future<bool> consumeStopRequest() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('consume_stop_request') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {
      // Deja arrete.
    }
  }
}
