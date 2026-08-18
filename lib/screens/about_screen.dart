import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/app_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BTC Miner Fun',
                  style: mono(size: 24, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Version 0.1.0 - licence MIT',
                  style: mono(size: 12, color: AppColors.muted)),
              const SizedBox(height: 16),
              const Text(
                'Un mineur Bitcoin pedagogique, ecrit en Flutter, qui tourne sur '
                'Android et sur Windows a partir du meme code source.',
                style: TextStyle(height: 1.55, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Sous le capot'),
        const _Fact('Hachage', 'Double SHA-256, dans un isolate separe'),
        const _Fact('Protocole', 'Stratum V1 (subscribe, authorize, notify, submit)'),
        const _Fact('Interface', 'Flutter, Material 3, theme sur mesure'),
        const _Fact('Compilation', 'GitHub Actions : APK Android + .exe Windows'),
        const SizedBox(height: 16),
        AppCard(
          accent: AppColors.coral.withOpacity(0.4),
          child: const Text(
            'Aucune garantie de gain. Le minage sollicite fortement le processeur '
            'et la batterie. Utilise cette application sur ton propre materiel, '
            'et pour apprendre.',
            style: TextStyle(height: 1.55, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.title, this.value);
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: label()),
            const SizedBox(height: 6),
            Text(value, style: mono(size: 13)),
          ],
        ),
      ),
    );
  }
}
