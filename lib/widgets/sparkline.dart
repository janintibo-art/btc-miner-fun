import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Courbe du hashrate des 60 dernieres secondes.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 64,
    this.markers = const <double>[],
  });

  final List<double> values;
  final double height;

  /// Positions relatives (0 a gauche, 1 a droite) des trouvailles recentes.
  /// Elles apparaissent comme des impacts sur la courbe : la chance devient
  /// une donnee visible, sans rien coûter en calcul.
  final List<double> markers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, markers)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.markers);
  final List<double> values;
  final List<double> markers;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.line.withOpacity(.42)
      ..strokeWidth = .7;

    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = AppColors.line.withOpacity(.16)
        ..strokeWidth = .6);
    }

    if (values.length < 2) {
      _paintMarkers(canvas, size);
      return;
    }
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV <= 0 ? 1.0 : maxV * 1.15;
    final dx = size.width / (values.length - 1);

    final path = Path();
    final fill = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - (values[i] / top) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      fill.lineTo(x, y);
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4236D9FF), Color(0x18F7931A), Color(0x0002040A)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan.withOpacity(.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.cyan, AppColors.amberHot],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final lastX = size.width;
    final lastY = size.height - (values.last / top) * size.height;
    canvas.drawCircle(
      Offset(lastX, lastY),
      4.4,
      Paint()..color = AppColors.amberHot,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      9,
      Paint()..color = AppColors.amber.withOpacity(.12),
    );

    _paintMarkers(canvas, size);
  }

  void _paintMarkers(Canvas canvas, Size size) {
    for (final position in markers) {
      final x = size.width * position.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height * .18),
        Paint()
          ..color = AppColors.cyan.withOpacity(.28)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        Offset(x, size.height * .18),
        2.6,
        Paint()..color = AppColors.cyan,
      );
      canvas.drawCircle(
        Offset(x, size.height * .18),
        5.5,
        Paint()..color = AppColors.cyan.withOpacity(.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.markers != markers;
}
