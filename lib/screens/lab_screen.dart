import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/avalanche.dart';
import '../core/lottery_sim.dart';
import '../core/bitcoin_utils.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';
import '../widgets/hardware_card.dart';

/// L'onglet Labo : tout ce qui se passe reellement, rendu observable.
class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  int _selectedField = -1;
  int _consoleFilter = 0; // 0 tout, 1 recu, 2 envoye
  AvalancheResult? _avalanche;
  bool _avalancheRunning = false;
  LotteryResult? _lottery;
  bool _lotteryRunning = false;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const SectionLabel('Les 80 octets que tu haches'),
        _HeaderDecoder(
          m: m,
          selected: _selectedField,
          onSelect: (i) => setState(() => _selectedField = i == _selectedField ? -1 : i),
        ),
        const SizedBox(height: 20),
        const SectionLabel('La transaction qui te paierait'),
        _CoinbaseCard(m: m),
        const SizedBox(height: 20),
        const SectionLabel('Rendre le hasard visible'),
        _SightingsCard(m: m),
        const SizedBox(height: 20),
        const SectionLabel('Le protocole en direct'),
        _ConsoleCard(
          m: m,
          filter: _consoleFilter,
          onFilter: (f) => setState(() => _consoleFilter = f),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Ce que ta machine sait faire'),
        const HardwareCard(),
        const SizedBox(height: 20),
        const SectionLabel('Dix mille univers paralleles'),
        _LotteryCard(
          m: m,
          result: _lottery,
          running: _lotteryRunning,
          onRun: () async {
            final network = m.market?.networkHashrate;
            var hashrate = m.hashrate;
            if (hashrate <= 0) {
              for (final session in m.sessions) {
                if (session.averageHashrate > hashrate) {
                  hashrate = session.averageHashrate;
                }
              }
            }
            if (network == null || network <= 0 || hashrate <= 0) return;
            setState(() => _lotteryRunning = true);
            try {
              final r = await runLotterySimulation(
                hashrate: hashrate,
                networkHashrate: network,
              );
              if (mounted) setState(() => _lottery = r);
            } finally {
              if (mounted) setState(() => _lotteryRunning = false);
            }
          },
        ),
        const SizedBox(height: 20),
        const SectionLabel('Pourquoi tricher est impossible'),
        _AvalancheCard(
          result: _avalanche,
          running: _avalancheRunning,
          onRun: () async {
            setState(() => _avalancheRunning = true);
            try {
              final result = await runAvalancheTest();
              if (mounted) setState(() => _avalanche = result);
            } finally {
              if (mounted) setState(() => _avalancheRunning = false);
            }
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Decodeur d'en-tete
// ---------------------------------------------------------------------------

class _HeaderField {
  const _HeaderField(this.name, this.start, this.end, this.color, this.explain);
  final String name;
  final int start; // en caracteres hexadecimaux
  final int end;
  final Color color;
  final String explain;
}

const _headerFields = <_HeaderField>[
  _HeaderField('Version', 0, 8, Color(0xFF7DD3FC),
      'Les regles de consensus que ce bloc annonce suivre. Sert aussi a '
      'signaler le soutien a une evolution du protocole.'),
  _HeaderField('Bloc precedent', 8, 72, Color(0xFFA78BFA),
      'Le hash du bloc precedent. C\'est litteralement ce qui fait la chaine : '
      'change un bloc ancien, et tous les suivants deviennent invalides.'),
  _HeaderField('Racine de Merkle', 72, 136, Color(0xFF4ADE9B),
      'Le resume de toutes les transactions du bloc en un seul hash, dont la '
      'coinbase qui te paierait. Modifier une transaction change cette racine.'),
  _HeaderField('Horodatage', 136, 144, Color(0xFFFBBF24),
      'L\'heure declaree du bloc, en secondes depuis 1970. Le reseau tolere un '
      'certain ecart, ce qui donne aux mineurs quelques bits de liberte.'),
  _HeaderField('nBits', 144, 152, Color(0xFFFB923C),
      'La difficulte du reseau, encodee en 4 octets. Elle se reajuste tous les '
      '2016 blocs pour maintenir un bloc toutes les dix minutes.'),
  _HeaderField('Nonce', 152, 160, Color(0xFFF7931A),
      'Les 4 octets libres. C\'est tout ce que tu fais varier : quatre '
      'milliards de possibilites, testees une par une.'),
];

class _HeaderDecoder extends StatelessWidget {
  const _HeaderDecoder({
    required this.m,
    required this.selected,
    required this.onSelect,
  });

  final MinerController m;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final job = m.job;
    if (job == null || job.headerHex.length < 160) {
      return AppCard(
        child: Text(
          'Lance le minage : l\'en-tete du travail en cours s\'affichera ici, '
          'octet par octet.',
          style: mono(size: 12, color: AppColors.muted),
        ),
      );
    }

    // Le nonce affiche est celui reellement teste en ce moment.
    final live = m.isActive
        ? m.currentNonce.toRadixString(16).padLeft(8, '0')
        : job.headerHex.substring(152, 160);
    final hex = job.headerHex.substring(0, 152) + live;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              for (var i = 0; i < _headerFields.length; i++)
                GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 2, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                      color: selected == i
                          ? _headerFields[i].color.withOpacity(0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hex.substring(_headerFields[i].start, _headerFields[i].end),
                      style: mono(
                        size: 12.5,
                        color: _headerFields[i].color,
                        weight: i == 5 ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _headerFields.length; i++)
                GestureDetector(
                  onTap: () => onSelect(i),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _headerFields[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(_headerFields[i].name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected == i ? FontWeight.w700 : FontWeight.w500,
                            color: selected == i ? AppColors.ink : AppColors.muted,
                          )),
                    ],
                  ),
                ),
            ],
          ),
          if (selected >= 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.panelHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _headerFields[selected].color.withOpacity(0.4)),
              ),
              child: Text(
                _headerFields[selected].explain,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: Text('Espace des nonces explore sur ce travail',
                    style: mono(size: 11.5, color: AppColors.muted)),
              ),
              Text('${(m.nonceSpaceCovered * 100).toStringAsFixed(4)} %',
                  style: mono(size: 12.5, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: m.nonceSpaceCovered,
              minHeight: 7,
              backgroundColor: AppColors.panelHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un travail contient 4 294 967 296 nonces. Quand ils sont epuises, '
            'l\'extranonce change et l\'espace repart a zero.',
            style: mono(size: 10.5, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Coinbase
// ---------------------------------------------------------------------------

class _CoinbaseCard extends StatelessWidget {
  const _CoinbaseCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final cb = m.coinbase;
    if (cb == null || cb.totalBytes == 0) {
      return AppCard(
        child: Text(
          'La transaction coinbase apparaitra ici des le premier travail recu.',
          style: mono(size: 12, color: AppColors.muted),
        ),
      );
    }

    final rate = m.market?.eurPerBtc ?? 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${cb.totalBytes} octets fabriques par toi', style: label()),
          const SizedBox(height: 12),
          if (cb.blockHeight != null)
            _Row('Hauteur du bloc', '#${formatCount(cb.blockHeight!)}'),
          _Row('Recompense totale', '${formatBtc(cb.totalBtc)} ₿'),
          if (rate > 0)
            _Row('Soit, au cours actuel', formatEuros(cb.totalBtc * rate),
                highlight: true),
          _Row('Sorties', '${cb.outputs.length}'),
          if (!cb.complete)
            _Row('Decodage', 'partiel${cb.error == null ? '' : ' : ${cb.error}'}'),
          if (cb.messages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('MESSAGE LAISSE DANS LE BLOC', style: label()),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.night,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: SelectableText(
                cb.messages.join('\n'),
                style: mono(size: 12, color: AppColors.mint),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les pools signent leurs blocs ainsi depuis toujours. Le tout '
              'premier bloc de Bitcoin contenait un titre de journal.',
              style: mono(size: 10.5, color: AppColors.dim),
            ),
          ],
          const SizedBox(height: 14),
          ...cb.outputs.take(4).map(
                (output) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(output.kind,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                      Text('${formatBtc(output.btc)} ₿',
                          style: mono(size: 12, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.title, this.value, {this.highlight = false});
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          Text(value,
              style: mono(
                size: 12.5,
                weight: FontWeight.w700,
                color: highlight ? AppColors.amber : AppColors.ink,
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Trouvailles et histogramme
// ---------------------------------------------------------------------------

class _SightingsCard extends StatelessWidget {
  const _SightingsCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final buckets = m.sightingHistogram.keys.toList()..sort();
    final maxCount = m.sightingHistogram.values.fold(0, (a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEUIL D\'OBSERVATION', style: label()),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${m.observeBits}',
                  style: mono(size: 26, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('bits a zero',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Slider(
            value: m.observeBits.toDouble(),
            min: 8,
            max: 40,
            divisions: 32,
            activeColor: AppColors.amber,
            label: '${m.observeBits}',
            onChanged: (v) => m.setObserveBits(v.round()),
          ),
          const Text(
            'Ce seuil n\'a aucun effet sur le minage : il decide seulement a '
            'partir de quand une tentative merite d\'etre affichee. Baisse-le '
            'et le hasard devient visible ; monte-le et les trouvailles '
            'redeviennent rares. C\'est exactement le mecanisme d\'une '
            'difficulte, en miniature.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
          ),
          if (buckets.isNotEmpty) ...[
            const Divider(height: 26),
            Text('REPARTITION DES TROUVAILLES', style: label()),
            const SizedBox(height: 10),
            ...buckets.reversed.take(10).map((bucket) {
              final count = m.sightingHistogram[bucket] ?? 0;
              final fraction = maxCount == 0 ? 0.0 : count / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text('2^$bucket',
                          style: mono(size: 11, color: AppColors.muted)),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Stack(
                          children: [
                            Container(height: 12, color: AppColors.panelHigh),
                            Container(
                              height: 12,
                              width: c.maxWidth * fraction,
                              color: AppColors.amber.withOpacity(0.75),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 34,
                      child: Text('$count',
                          textAlign: TextAlign.right,
                          style: mono(size: 11, weight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              'Chaque palier est deux fois plus dur que le precedent, et '
              'devrait donc apparaitre deux fois moins souvent. La loi de '
              'probabilite se dessine sous tes yeux.',
              style: mono(size: 10.5, color: AppColors.dim),
            ),
          ],
          if (m.sightings.isNotEmpty) ...[
            const Divider(height: 26),
            Text('DERNIERES TROUVAILLES', style: label()),
            const SizedBox(height: 10),
            ...m.sightings.take(6).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('nonce ${s.nonce.toRadixString(16).padLeft(8, '0')}',
                              style: mono(size: 11.5, color: AppColors.muted)),
                        ),
                        Text('difficulte ${s.difficulty.toStringAsFixed(1)}',
                            style: mono(size: 11.5, color: AppColors.mint)),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Console Stratum
// ---------------------------------------------------------------------------

class _ConsoleCard extends StatelessWidget {
  const _ConsoleCard({
    required this.m,
    required this.filter,
    required this.onFilter,
  });

  final MinerController m;
  final int filter;
  final ValueChanged<int> onFilter;

  @override
  Widget build(BuildContext context) {
    final messages = m.rawMessages.where((msg) {
      if (filter == 1) return !msg.outgoing;
      if (filter == 2) return msg.outgoing;
      return true;
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        selected: filter == i,
                        onSelected: (_) => onFilter(i),
                        backgroundColor: AppColors.panelHigh,
                        selectedColor: AppColors.amber,
                        side: const BorderSide(color: AppColors.line),
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: filter == i ? Colors.black : AppColors.muted,
                        ),
                        label: Text(['Tout', 'Recu', 'Envoye'][i]),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: messages.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(
                            text: messages.map((e) => e.line).join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Echanges copies')),
                        );
                      },
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: AppColors.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 240,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.night,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: messages.isEmpty
                ? Center(
                    child: Text('Aucun echange. Lance le minage.',
                        style: mono(size: 11.5, color: AppColors.muted)),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${msg.outgoing ? '>>' : '<<'} '
                              '${msg.at.hour.toString().padLeft(2, '0')}:'
                              '${msg.at.minute.toString().padLeft(2, '0')}:'
                              '${msg.at.second.toString().padLeft(2, '0')}',
                              style: mono(
                                size: 9.5,
                                color: msg.outgoing
                                    ? AppColors.amber
                                    : AppColors.mint,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              msg.line,
                              style: mono(size: 10.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Voici le protocole Stratum sans intermediaire : les lignes JSON '
            'echangees avec le pool, dans l\'ordre. mining.notify apporte un '
            'travail, mining.submit envoie une part.',
            style: mono(size: 10.5, color: AppColors.dim),
          ),
        ],
      ),
    );
  }
}

class _LotteryCard extends StatelessWidget {
  const _LotteryCard({
    required this.m,
    required this.result,
    required this.running,
    required this.onRun,
  });

  final MinerController m;
  final LotteryResult? result;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final network = m.market?.networkHashrate;
    final pret = network != null && network > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'On fait vivre dix mille univers paralleles avec ta puissance de '
            'calcul, pendant cinquante ans chacun, et on compte ceux ou tu as '
            'trouve un bloc. La formule exacte est affichee a cote : quand la '
            'chance est minuscule, la simulation donne zero et seule la formule '
            'reste parlante.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (!pret)
            Text(
              'Actualise le cours dans l\'onglet Euros : la puissance du reseau '
              'est necessaire pour simuler.',
              style: mono(size: 11.5, color: AppColors.dim),
            ),
          if (result != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${result!.winners}',
                    style: mono(size: 34, weight: FontWeight.w700, spacing: -1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('univers gagnants sur ${result!.universes}',
                      style: mono(size: 12.5, color: AppColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Row('Duree simulee', '${result!.years} ans par univers'),
            _Row('Blocs attendus par univers',
                result!.expectedBlocks.toStringAsExponential(2)),
            _Row('Probabilite exacte',
                result!.exactProbability.toStringAsExponential(2)),
            _Row(
              'Soit une chance sur',
              result!.oneInHowMany.isInfinite
                  ? 'jamais'
                  : formatCount(result!.oneInHowMany.round()),
              highlight: true,
            ),
            const SizedBox(height: 12),
            Text(
              result!.winners == 0
                  ? 'Aucun univers gagnant. Ce n\'est pas un defaut de la '
                      'simulation : il faudrait en faire tourner bien davantage '
                      'pour en voir un seul.'
                  : 'Un univers a trouve jusqu\'a ${result!.bestUniverseBlocks} '
                      'bloc(s).',
              style: mono(size: 11, color: AppColors.dim),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: running || !pret ? null : onRun,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.violet,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.violet),
                    )
                  : const Icon(Icons.casino_rounded, size: 18),
              label: Text(running
                  ? 'Simulation en cours...'
                  : (result == null
                      ? 'Simuler cinquante ans'
                      : 'Relancer la simulation')),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Avalanche
// ---------------------------------------------------------------------------

class _AvalancheCard extends StatelessWidget {
  const _AvalancheCard({
    required this.result,
    required this.running,
    required this.onRun,
  });

  final AvalancheResult? result;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'On change un seul bit de l\'en-tete, puis on compte combien de '
            'bits changent dans le hash. Si un calcul approche etait possible, '
            'ce nombre serait petit.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(result!.averageBitsChanged.toStringAsFixed(1),
                    style: mono(size: 34, weight: FontWeight.w700, spacing: -1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('bits sur 256',
                      style: mono(size: 13, color: AppColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'soit ${result!.percentChanged.toStringAsFixed(1)} % de la sortie, '
              'pour un seul bit d\'entree',
              style: mono(size: 11.5, color: AppColors.amber),
            ),
            const SizedBox(height: 14),
            _Row('Essais', '${result!.trials}'),
            _Row('Minimum observe', '${result!.minBitsChanged} bits'),
            _Row('Maximum observe', '${result!.maxBitsChanged} bits'),
            const SizedBox(height: 10),
            Text('EXEMPLE : BIT NUMERO ${result!.exampleBitFlipped} INVERSE',
                style: label()),
            const SizedBox(height: 8),
            SelectableText(result!.exampleBefore,
                style: mono(size: 10, color: AppColors.muted)),
            const SizedBox(height: 4),
            SelectableText(result!.exampleAfter,
                style: mono(size: 10, color: AppColors.mint)),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: running ? null : onRun,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.amber),
                    )
                  : const Icon(Icons.science_rounded, size: 18),
              label: Text(running
                  ? 'Mesure en cours...'
                  : (result == null ? 'Lancer le test' : 'Refaire le test')),
            ),
          ),
        ],
      ),
    );
  }
}
