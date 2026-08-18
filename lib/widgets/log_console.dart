import 'package:flutter/material.dart';

import '../app_theme.dart';

class LogConsole extends StatelessWidget {
  const LogConsole({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.abyss.withOpacity(.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyan.withOpacity(.25)),
        boxShadow: [
          BoxShadow(color: AppColors.cyan.withOpacity(.06), blurRadius: 20),
          const BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.panelLift.withOpacity(.9), AppColors.panel.withOpacity(.65)],
                ),
                border: Border(bottom: BorderSide(color: AppColors.line.withOpacity(.7))),
              ),
              child: Row(
                children: [
                  const _ConsoleDot(AppColors.coral),
                  const SizedBox(width: 5),
                  const _ConsoleDot(AppColors.amber),
                  const SizedBox(width: 5),
                  const _ConsoleDot(AppColors.mint),
                  const Spacer(),
                  Text('STRATUM // DATA FEED', style: mono(size: 8.8, color: AppColors.dim, spacing: .8)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                child: lines.isEmpty
                    ? Center(
                        child: Text(
                          '> aucun evenement_',
                          style: mono(size: 11.5, color: AppColors.dim),
                        ),
                      )
                    : ListView.builder(
                        itemCount: lines.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i == 0 ? '>' : '·',
                                style: mono(
                                  size: 11.2,
                                  color: i == 0 ? AppColors.mint : AppColors.dim,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  lines[i],
                                  style: mono(
                                    size: 11.2,
                                    color: i == 0 ? AppColors.ink : AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleDot extends StatelessWidget {
  const _ConsoleDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
