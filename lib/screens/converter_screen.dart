import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../core/bitcoin_utils.dart';
import '../core/price_service.dart';
import '../state/miner_controller.dart';
import '../widgets/app_card.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _btc = TextEditingController();
  final _eur = TextEditingController();
  final _manual = TextEditingController();

  @override
  void dispose() {
    _btc.dispose();
    _eur.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _fromBtc(MinerController m) {
    final rate = m.market?.eurPerBtc ?? 0;
    final value = double.tryParse(_btc.text.replaceAll(',', '.')) ?? 0;
    _eur.text = rate <= 0 ? '' : (value * rate).toStringAsFixed(2);
    setState(() {});
  }

  void _fromEur(MinerController m) {
    final rate = m.market?.eurPerBtc ?? 0;
    final value = double.tryParse(_eur.text.replaceAll(',', '.')) ?? 0;
    _btc.text = rate <= 0 ? '' : formatBtc(value / rate);
    setState(() {});
  }

  void _setBtc(double value, MinerController m) {
    _btc.text = formatBtc(value);
    _fromBtc(m);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MinerController>();
    final market = m.market;
    final rate = market?.eurPerBtc ?? 0;
    final btcValue = double.tryParse(_btc.text.replaceAll(',', '.')) ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _PriceCard(market: market, m: m),
        const SizedBox(height: 20),
        const SectionLabel('Convertir'),
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: _btc,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: mono(size: 20, weight: FontWeight.w700),
                onChanged: (_) => _fromBtc(m),
                decoration: const InputDecoration(
                  labelText: 'Bitcoin',
                  prefixText: '₿  ',
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.swap_vert_rounded, color: AppColors.muted),
              const SizedBox(height: 8),
              TextField(
                controller: _eur,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: mono(size: 20, weight: FontWeight.w700),
                onChanged: (_) => _fromEur(m),
                decoration: const InputDecoration(
                  labelText: 'Euros',
                  prefixText: '€  ',
                ),
              ),
              if (btcValue > 0) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'soit ${formatCount((btcValue * kSatoshisPerBtc).round())} satoshis',
                    style: mono(size: 12, color: AppColors.amber),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quick('1 000 sat', 0.00001, m),
                  _quick('100 000 sat', 0.001, m),
                  _quick('0,01 ₿', 0.01, m),
                  _quick('1 ₿', 1, m),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Ton adresse'),
        _BalanceCard(m: m),
        const SizedBox(height: 20),
        const SectionLabel('Et ta machine, dans tout ca'),
        _EarningsCard(m: m),
        if (rate <= 0 || (market?.manual ?? false)) ...[
          const SizedBox(height: 20),
          const SectionLabel('Cours manuel'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pas de connexion ? Saisis le cours toi-meme : la conversion '
                  'fonctionnera hors ligne.',
                  style: TextStyle(
                      fontSize: 12.5, height: 1.5, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: mono(size: 14),
                        decoration: const InputDecoration(
                          labelText: 'Euros pour 1 bitcoin',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () {
                        final v =
                            double.tryParse(_manual.text.replaceAll(',', '.'));
                        if (v != null && v > 0) {
                          m.setManualPrice(v);
                          _fromBtc(m);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                      child: const Text('Fixer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _quick(String text, double btc, MinerController m) {
    return ActionChip(
      onPressed: () => _setBtc(btc, m),
      backgroundColor: AppColors.panelHigh,
      side: const BorderSide(color: AppColors.line),
      label: Text(text,
          style: mono(size: 12, weight: FontWeight.w700, color: AppColors.muted)),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.market, required this.m});
  final MarketData? market;
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.amber.withOpacity(0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('COURS DU BITCOIN', style: label())),
              IconButton(
                onPressed: m.priceLoading ? null : m.refreshMarket,
                icon: m.priceLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.amber),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: AppColors.amber, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (market == null)
            Text(
              m.priceLoading
                  ? 'Recuperation du cours...'
                  : 'Cours indisponible. Touche la fleche pour reessayer, ou '
                      'saisis-le a la main plus bas.',
              style: mono(size: 12.5, color: AppColors.muted),
            )
          else ...[
            Text(formatEuros(market!.eurPerBtc),
                style: mono(size: 32, weight: FontWeight.w700, spacing: -1)),
            const SizedBox(height: 4),
            Text('pour 1 bitcoin', style: mono(size: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            Text(
              market!.manual
                  ? 'Cours saisi a la main'
                  : 'Mis a jour a ${_hhmm(market!.fetchedAt)} - source CoinGecko',
              style: mono(size: 11, color: AppColors.muted),
            ),
            if (market!.usdPerBtc > 0 && !market!.manual)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${market!.usdPerBtc.toStringAsFixed(0)} dollars',
                    style: mono(size: 11, color: AppColors.muted)),
              ),
          ],
        ],
      ),
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final balance = m.balance;
    final rate = m.market?.eurPerBtc ?? 0;

    if (m.wallet.trim().isEmpty) {
      return AppCard(
        child: Text(
          'Renseigne ton adresse dans Reglages pour suivre son solde ici.',
          style: mono(size: 12, color: AppColors.muted),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('SOLDE DE TON ADRESSE', style: label())),
              IconButton(
                onPressed: m.balanceLoading ? null : m.refreshBalance,
                icon: m.balanceLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.amber),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: AppColors.amber, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (balance == null)
            Text(
              m.balanceError ??
                  'Touche la fleche pour consulter la chaine et voir ce que ton '
                      'adresse a recu.',
              style: mono(size: 12, color: AppColors.muted),
            )
          else ...[
            Text('${formatBtc(balance.totalBtc)} ₿',
                style: mono(size: 26, weight: FontWeight.w700, spacing: -1)),
            const SizedBox(height: 4),
            Text(
              rate > 0
                  ? '${formatEuros(balance.totalBtc * rate)} au cours actuel'
                  : '${formatCount(balance.totalSats)} satoshis',
              style: mono(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            if (balance.pendingSats != 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${formatCount(balance.pendingSats)} satoshis en attente de '
                  'confirmation',
                  style: mono(size: 11.5, color: AppColors.amber),
                ),
              ),
            Text(
              balance.transactionCount == 0
                  ? 'Aucun mouvement sur cette adresse. C\'est normal : trouver '
                      'un bloc est un evenement rarissime.'
                  : '${balance.transactionCount} transaction(s) enregistree(s)',
              style: mono(size: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Text(
              'Consultation seule, via mempool.space. Cette application ne '
              'detient aucune cle et ne peut rien depenser.',
              style: mono(size: 10.5, color: AppColors.dim),
            ),
          ],
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.m});
  final MinerController m;

  @override
  Widget build(BuildContext context) {
    final market = m.market;
    final network = market?.networkHashrate;
    final rate = market?.eurPerBtc ?? 0;

    // La puissance de reference : celle mesuree en ce moment, sinon la
    // meilleure moyenne des sessions passees.
    var hashrate = m.hashrate;
    if (hashrate <= 0) {
      for (final s in m.sessions) {
        if (s.averageHashrate > hashrate) hashrate = s.averageHashrate;
      }
    }

    if (network == null || network <= 0 || rate <= 0) {
      return AppCard(
        child: Text(
          'L\'estimation demande le cours et la puissance du reseau. '
          'Actualise le cours quand tu auras une connexion.',
          style: mono(size: 12, color: AppColors.muted),
        ),
      );
    }

    if (hashrate <= 0) {
      return AppCard(
        child: Text(
          'Lance une session de minage : l\'estimation utilisera ta puissance '
          'reelle plutot qu\'une valeur theorique.',
          style: mono(size: 12, color: AppColors.muted),
        ),
      );
    }

    final btcPerDay = expectedBtcPerDay(hashrate, network);
    final eurPerYear = btcPerDay * 365 * rate;
    final daysPerBlock =
        network / hashrate / kBlocksPerDay; // jours avant un bloc, en moyenne

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ESPERANCE DE GAIN', style: label()),
          const SizedBox(height: 12),
          _Line('Ta puissance', formatHashrate(hashrate)),
          _Line('Le reseau entier', formatHashrate(network)),
          _Line('Ta part du reseau',
              '${(hashrate / network * 100).toStringAsExponential(2)} %'),
          const Divider(height: 26),
          _Line('Par jour', '${formatEuros(eurPerYear / 365)}  '
              '(${formatBtc(btcPerDay)} ₿)'),
          _Line('Par an', formatEuros(eurPerYear)),
          _Line('Un bloc en moyenne tous les', formatLongDuration(daysPerBlock),
              highlight: true),
          const SizedBox(height: 14),
          const Text(
            'Ce sont des esperances mathematiques, pas des previsions. En solo, '
            'le resultat reel est presque toujours zero, et tres rarement un '
            'bloc entier. C\'est exactement le principe d\'une loterie.',
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.title, this.value, {this.highlight = false});
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SizedBox(width: 12),
          Text(value,
              textAlign: TextAlign.right,
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
