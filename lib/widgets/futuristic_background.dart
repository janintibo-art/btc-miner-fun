import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Fond technique volontairement statique : il donne de la profondeur sans
/// voler de CPU au mineur quand le calcul est actif.
class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _ReactorBackdropPainter()),
      ),
    );
  }
}

class _ReactorBackdropPainter extends CustomPainter {
  const _ReactorBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.abyss, AppColors.night, Color(0xFF080D1B)],
          stops: [0, 0.56, 1],
        ).createShader(rect),
    );

    _radial(canvas, size, Offset(size.width * .88, size.height * .10),
        math.max(size.width, size.height) * .45, AppColors.amber, .13);
    _radial(canvas, size, Offset(size.width * .04, size.height * .64),
        math.max(size.width, size.height) * .48, AppColors.cyan, .075);
    _radial(canvas, size, Offset(size.width * .76, size.height * .80),
        math.max(size.width, size.height) * .40, AppColors.violet, .055);

    final gridPaint = Paint()
      ..color = AppColors.line.withOpacity(.16)
      ..strokeWidth = .7;
    const step = 36.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final diagonal = Paint()
      ..color = AppColors.cyan.withOpacity(.045)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 108) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), diagonal);
    }

    final nodePaint = Paint()..color = AppColors.amber.withOpacity(.22);
    final linkPaint = Paint()
      ..color = AppColors.lineBright.withOpacity(.18)
      ..strokeWidth = 1;
    final nodes = <Offset>[
      Offset(size.width * .12, size.height * .16),
      Offset(size.width * .29, size.height * .25),
      Offset(size.width * .71, size.height * .20),
      Offset(size.width * .86, size.height * .42),
      Offset(size.width * .18, size.height * .73),
      Offset(size.width * .58, size.height * .86),
    ];
    for (var i = 0; i < nodes.length - 1; i += 2) {
      canvas.drawLine(nodes[i], nodes[i + 1], linkPaint);
    }
    for (final n in nodes) {
      canvas.drawCircle(n, 2.2, nodePaint);
      canvas.drawCircle(n, 6, Paint()..color = AppColors.amber.withOpacity(.035));
    }
  }

  void _radial(Canvas canvas, Size size, Offset center, double radius, Color color,
      double opacity) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
