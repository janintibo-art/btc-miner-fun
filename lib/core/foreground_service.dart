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

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {
      // Deja arrete.
    }
  }
}
