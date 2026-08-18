import 'package:flutter/material.dart';

import '../app_theme.dart';

class LogConsole extends StatelessWidget {
  const LogConsole({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF090C14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: lines.isEmpty
          ? Center(child: Text('Aucun evenement', style: mono(color: AppColors.muted)))
          : ListView.builder(
              reverse: false,
              itemCount: lines.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  lines[i],
                  style: mono(
                    size: 11.5,
                    color: i == 0 ? AppColors.mint : AppColors.muted,
                  ),
                ),
              ),
            ),
    );
  }
}
