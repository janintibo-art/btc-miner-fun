import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/my_chain.dart';
import '../core/my_chain_miner.dart';

/// Pilote la chaine personnelle : creation, minage, verification.
///
/// Volontairement separe du controleur de minage principal : les deux ne
/// partagent rien, et une chaine locale ne doit surtout pas se melanger a de
/// vraies parts envoyees a un pool.
class ChainController extends ChangeNotifier {
  MyChain? chain;
  bool mining = false;
  bool _stopRequested = false;

  /// Progression du bloc en cours.
  int currentNonce = 0;
  int hashesOnCurrentBlock = 0;
  double hashrate = 0;
  ChainVerdict? lastVerdict;
  final List<String> log = <String>[];

  static const int _batch = 120000;

  bool get exists => chain != null && chain!.blocks.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    chain = MyChain.tryDecode(prefs.getString('myChain'));
    notifyListeners();
  }

  Future<void> _save() async {
    final current = chain;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('myChain', current.encode());
  }

  void _note(String line) {
    log.insert(0, line);
    if (log.length > 40) log.removeLast();
  }

  /// Cree la chaine et son bloc de genese.
  Future<void> create(ChainRules rules) async {
    final fresh = MyChain(rules: rules);
    fresh.blocks.add(fresh.createGenesis(DateTime.now()));
    chain = fresh;
    _note('Bloc de genese cree : « ${rules.genesisMessage} »');
    await _save();
    notifyListeners();
  }

  Future<void> destroy() async {
    chain = null;
    lastVerdict = null;
    log.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('myChain');
    notifyListeners();
  }

  /// Mine les blocs les uns apres les autres jusqu'a l'arret demande.
  Future<void> mine(String message) async {
    final current = chain;
    if (current == null || mining) return;

    mining = true;
    _stopRequested = false;
    notifyListeners();

    while (!_stopRequested) {
      final candidate = current.prepareNext(DateTime.now(), message);
      final header = candidate.header();
      var nonce = 0;
      var hashes = 0;
      final start = DateTime.now();
      hashesOnCurrentBlock = 0;

      var found = false;
      while (!_stopRequested && !found) {
        final result = await mineChainBatch(
          header: header,
          bits: candidate.bits,
          startNonce: nonce,
          count: _batch,
        );
        hashes += result.hashes;
        nonce = result.nonce;
        hashesOnCurrentBlock = hashes;
        currentNonce = nonce;

        final elapsed = DateTime.now().difference(start).inMilliseconds;
        hashrate = elapsed <= 0 ? 0 : hashes * 1000 / elapsed;
        notifyListeners();

        if (result.found) {
          found = true;
          final mined = MyBlock(
            height: candidate.height,
            version: candidate.version,
            previousHash: candidate.previousHash,
            merkleRoot: candidate.merkleRoot,
            time: candidate.time,
            bits: candidate.bits,
            nonce: result.nonce,
            message: candidate.message,
            reward: candidate.reward,
            hashesTried: hashes,
          );
          current.blocks.add(mined);
          _note('Bloc ${mined.height} trouve en ${_formatCount(hashes)} '
              'tentatives : ${mined.hash.substring(0, 16)}...');
          await _save();
          notifyListeners();
        }

        // Le nonce ne fait que 32 bits : au bout du compte, on change
        // l'horodatage du bloc pour repartir sur un espace neuf.
        if (!found && nonce == 0) break;
      }
    }

    mining = false;
    hashrate = 0;
    notifyListeners();
  }

  void stop() {
    _stopRequested = true;
  }

  /// Verifie la chaine entiere, bloc par bloc.
  void verify() {
    final current = chain;
    if (current == null) return;
    final verdict = current.verify();
    lastVerdict = verdict;
    _note(verdict.valid
        ? 'Chaine verifiee : ${verdict.checked} blocs conformes.'
        : 'Chaine invalide : ${verdict.problem}');
    notifyListeners();
  }

  static String _formatCount(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
