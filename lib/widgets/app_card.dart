import 'package:flutter/material.dart';

import '../app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final glow = accent ?? AppColors.cyan;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          if (accent != null)
            BoxShadow(
              color: glow.withOpacity(.10),
              blurRadius: 24,
              spreadRadius: -7,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xF21A2336), Color(0xF20B101C)],
                  ),
                  border: Border.all(
                    color: accent?.withOpacity(.58) ?? AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
            Positioned(
              top: -54,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glow.withOpacity(.12), glow.withOpacity(0)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      glow.withOpacity(.58),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 11, top: 7),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [AppColors.amber, AppColors.cyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.amber.withOpacity(.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(text.toUpperCase(), style: label()),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.line.withOpacity(.6), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
