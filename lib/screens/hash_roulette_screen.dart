import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/celebration.dart';
import '../core/sha256_fast.dart';

/// La roulette des hachages.
///
/// Chaque hachage est un tirage. Une machine a sous ne fait rien d'autre, a
/// ceci pres que ses rouleaux s'arretent au bout de trois symboles. Ici, il
/// en faudrait dix-neuf alignes pour trouver un bloc Bitcoin.
class HashRouletteScreen extends StatefulWidget {
  const HashRouletteScreen({super.key});

  @override
  State<HashRouletteScreen> createState() => _HashRouletteScreenState();
}

class _HashRouletteScreenState extends State<HashRouletteScreen> {
  final Sha256Fast _hasher = Sha256Fast();
  final Uint8List _header = Uint8List(80);
  final Random _random = Random();
  final List<({String hash, int zeros})> _historique = [];

  Timer? _boucle;
  String _courant = '0' * 64;
  int _zerosCourants = 0;
  int _record = 0;
  int _tirages = 0;
  bool _tourne = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 80; i++) {
      _header[i] = _random.nextInt(256);
    }
    _hasher.prepare(_header);
  }

  @override
  void dispose() {
    _boucle?.cancel();
    super.dispose();
  }

  /// Compte les zeros hexadecimaux de tete : c'est ce que l'oeil repere, et
  /// c'est exactement ce que mesure la difficulte.
  int _compterZeros(String hash) {
    var zeros = 0;
    while (zeros < hash.length && hash[zeros] == '0') {
      zeros++;
    }
    return zeros;
  }

  void _basculer() {
    if (_tourne) {
      _boucle?.cancel();
      setState(() => _tourne = false);
      return;
    }

    setState(() => _tourne = true);
    // Vingt tirages par seconde : assez rapide pour donner le vertige, assez
    // lent pour que l'oeil suive.
    _boucle = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Chaque tirage teste plusieurs nonces et ne montre que le meilleur :
      // sinon, on n'afficherait presque jamais le moindre zero.
      var meilleurHash = '';
      var meilleurZeros = -1;
      for (var i = 0; i < 400; i++) {
        _hasher.hashNonce(_random.nextInt(0xFFFFFFFF));
        final hash = bytesToHex(reverseBytes(_hasher.digest()));
        final zeros = _compterZeros(hash);
        if (zeros > meilleurZeros) {
          meilleurZeros = zeros;
          meilleurHash = hash;
        }
      }
      _tirages += 400;

      setState(() {
        _courant = meilleurHash;
        _zerosCourants = meilleurZeros;
        _historique.insert(0, (hash: meilleurHash, zeros: meilleurZeros));
        if (_historique.length > 8) _historique.removeLast();
        if (meilleurZeros > _record) {
          _record = meilleurZeros;
          Celebration.record();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      appBar: AppBar(
        backgroundColor: AppColors.abyss,
        elevation: 0,
        title: const Text('Roulette des hachages',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chaque hachage est un tirage. Les zeros de tete s\'allument : '
                'plus il y en a, plus le tirage etait improbable.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              _Rouleau(hash: _courant, zeros: _zerosCourants, grand: true),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Compteur('Record', '$_record zeros'),
                  _Compteur('Tirages', formatCount(_tirages)),
                  _Compteur('Un bloc BTC', '19 zeros'),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: _historique.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Opacity(
                      opacity: 1 - (i / 12).clamp(0.0, 0.75),
                      child: _Rouleau(
                        hash: _historique[i].hash,
                        zeros: _historique[i].zeros,
                        grand: false,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _basculer,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _tourne ? AppColors.panelHigh : AppColors.amber,
                    foregroundColor: _tourne ? AppColors.ink : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: Icon(_tourne
                      ? Icons.stop_rounded
                      : Icons.casino_rounded),
                  label: Text(_tourne ? 'Arreter' : 'Faire tourner',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Une machine a sous arrete ses rouleaux au bout de trois '
                'symboles. Il en faudrait dix-neuf alignes pour un bloc '
                'Bitcoin.',
                style: mono(size: 10, color: AppColors.dim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rouleau extends StatelessWidget {
  const _Rouleau({required this.hash, required this.zeros, required this.grand});

  final String hash;
  final int zeros;
  final bool grand;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (zeros) {
      0 => AppColors.dim,
      1 => AppColors.muted,
      2 => AppColors.cyan,
      3 => AppColors.mint,
      _ => AppColors.amberHot,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: 12, vertical: grand ? 16 : 9),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(grand ? 16 : 10),
        border: Border.all(
          color: zeros >= 3 ? couleur.withOpacity(.6) : AppColors.line,
        ),
        boxShadow: zeros >= 4
            ? [BoxShadow(color: couleur.withOpacity(.25), blurRadius: 18)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: hash.substring(0, zeros),
                  style: mono(
                    size: grand ? 15 : 11,
                    weight: FontWeight.w800,
                    color: couleur,
                  ),
                ),
                TextSpan(
                  text: hash.substring(zeros, grand ? 40 : 32),
                  style: mono(
                    size: grand ? 15 : 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (grand) ...[
            const SizedBox(height: 10),
            Text('$zeros zero(s) de tete',
                style: mono(size: 12, color: couleur)),
          ],
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur(this.titre, this.valeur);
  final String titre;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre.toUpperCase(), style: label()),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, style: mono(size: 15, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
