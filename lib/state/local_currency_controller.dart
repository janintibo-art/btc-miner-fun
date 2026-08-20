import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/local_currency.dart';

/// Pilote le registre de monnaie locale.
///
/// Tenu a part du minage et de la chaine personnelle : ces trois choses ne
/// partagent rien, et c'est exactement le propos de cet ecran.
class LocalCurrencyController extends ChangeNotifier {
  LocalLedger? ledger;
  String lastMessage = '';

  bool get exists => ledger != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ledger = LocalLedger.tryDecode(prefs.getString('localLedger'));
    notifyListeners();
  }

  Future<void> _save() async {
    final registre = ledger;
    if (registre == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localLedger', registre.encode());
  }

  Future<void> createDemonstration() async {
    ledger = LocalLedger.demonstration();
    lastMessage = 'Registre de demonstration cree.';
    await _save();
    notifyListeners();
  }

  Future<void> destroy() async {
    ledger = null;
    lastMessage = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('localLedger');
    notifyListeners();
  }

  Future<void> _appliquer(String Function(LocalLedger) action) async {
    final registre = ledger;
    if (registre == null) return;
    lastMessage = action(registre);
    await _save();
    notifyListeners();
  }

  Future<void> transfer(String from, String to, double amount, String label) =>
      _appliquer((r) => r.transfer(from, to, amount, label));

  Future<void> issue(String to, double amount, String label) =>
      _appliquer((r) => r.issue(to, amount, label));

  Future<void> cancel(String id) => _appliquer((r) => r.cancel(id));

  Future<void> addAccount(String name, AccountKind kind) =>
      _appliquer((r) => r.addAccount(name, kind));
}
