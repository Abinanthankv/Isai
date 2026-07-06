import 'dart:math' as math;
import 'package:flutter/material.dart';

class AudioVisualizerPainter extends CustomPainter {
  final String style;
  final int pointCount;
  final double sensitivity;
  final double amplitude;
  final double animationValue;
  final Color color;
  final double alpha;
  final double barSpacing;
  final double cornerRadius;
  final bool isPlaying;
  final double bpm;
  final List<int>? fftMagnitudes;
  final List<Color>? barColors;
  final double beatIntensity;

  static final Map<int, List<double>> _seedCache = {};

  AudioVisualizerPainter({
    required this.style,
    required this.pointCount,
    required this.sensitivity,
    required this.amplitude,
    required this.animationValue,
    required this.color,
    required this.alpha,
    required this.barSpacing,
    required this.cornerRadius,
    required this.isPlaying,
    required this.bpm,
    this.fftMagnitudes,
    this.barColors,
    this.beatIntensity = 0.0,
  }) {
    if (!_seedCache.containsKey(pointCount)) {
      final rng = math.Random(42);
      _seedCache[pointCount] = List.generate(pointCount, (_) => rng.nextDouble());
    }
  }

  List<double> get _seeds => _seedCache[pointCount]!;
  bool get _hasRealData => fftMagnitudes != null && fftMagnitudes!.isNotEmpty;

  Color _getBarColor(int i) {
    if (barColors != null && i < barColors!.length) {
      return barColors![i].withValues(alpha: alpha);
    }
    if (beatIntensity > 0.01) {
      return Color.lerp(color, Colors.white, beatIntensity * 0.5)!.withValues(alpha: alpha);
    }
    return color.withValues(alpha: alpha);
  }

  double _getHeightForPoint(int i) {
    if (_hasRealData) {
      final fft = fftMagnitudes!;
      final int range = fft.length - 1;
      final int bandStart = 1 + (i * range ~/ pointCount);
      final int bandEnd = 1 + ((i + 1) * range ~/ pointCount);
      int sum = 0;
      int count = 0;
      for (int k = bandStart; k < bandEnd && k < fft.length; k++) {
        sum += fft[k];
        count++;
      }
      double magnitude = count > 0 ? (sum / count) / 255.0 : 0.0;
      final double gainRamp = 1.0 + (i / pointCount) * (i / pointCount) * 6.0;
      return isPlaying ? (magnitude * gainRamp).clamp(0.0, 1.0) : magnitude * 0.05;
    } else {
      final seed = _seeds[i];
      final speedFactor = bpm / 120.0;
      final phase1 = math.sin((animationValue * 2 * math.pi) + (seed * math.pi * 2)) * 0.5 + 0.5;
      final phase2 = math.sin((animationValue * 4 * math.pi) + (i * 0.7)) * 0.3 + 0.5;
      final phase3 = math.cos((animationValue * 3 * math.pi) + (seed * 5.0)) * 0.2 + 0.5;
      final rawHeight = (phase1 * 0.5 + phase2 * 0.3 + phase3 * 0.2) * seed * (0.85 + speedFactor * 0.15);
      return isPlaying ? rawHeight : rawHeight * 0.05;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pointCount <= 0) return;

    switch (style) {
      case 'bar':
        _paintBars(canvas, size);
        break;
      case 'wave':
        _paintWave(canvas, size);
        break;
      case 'line':
        _paintLine(canvas, size);
        break;
      case 'mirrored':
        _paintMirrored(canvas, size);
        break;
      case 'circular':
        _paintCircular(canvas, size);
        break;
      default:
        _paintBars(canvas, size);
    }
  }

  void _paintBars(Canvas canvas, Size size) {
    final totalSpacing = barSpacing * (pointCount - 1);
    final barWidth = (size.width - totalSpacing) / pointCount;
    if (barWidth <= 0) return;

    for (int i = 0; i < pointCount; i++) {
      final heightFactor = _getHeightForPoint(i);
      final barHeight = (heightFactor * sensitivity * amplitude * size.height).clamp(2.0, size.height);
      final x = i * (barWidth + barSpacing);
      final y = size.height - barHeight;
      final paint = Paint()
        ..color = _getBarColor(i)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(cornerRadius.clamp(0, barWidth / 2)),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    final pointSpacing = size.width / (pointCount - 1);
    final path = Path();

    final rawYValues = List.generate(pointCount, (idx) {
      final heightFactor = _getHeightForPoint(idx);
      return size.height - (heightFactor * sensitivity * amplitude * size.height * 0.5 + size.height * 0.2);
    });

    final smoothedY = List<double>.from(rawYValues);
    for (int k = 1; k < pointCount - 1; k++) {
      smoothedY[k] = (rawYValues[k-1] + rawYValues[k] * 2 + rawYValues[k+1]) / 4;
    }

    path.moveTo(0, smoothedY[0]);
    for (int i = 0; i < smoothedY.length - 1; i++) {
      final x1 = i * pointSpacing;
      final x2 = (i + 1) * pointSpacing;
      final y1 = smoothedY[i];
      final y2 = smoothedY[i + 1];
      final cpx1 = x1 + (x2 - x1) / 2.2;
      final cpx2 = x1 + (x2 - x1) / 1.7;
      path.cubicTo(cpx1, y1, cpx2, y2, x2, y2);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
    );
    final gradientPaint = Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, gradientPaint);

    final sPaint = Paint()
      ..color = color.withValues(alpha: (alpha * (1.0 - beatIntensity * 0.3)).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: (alpha * 0.4 + beatIntensity * 0.3).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0 + beatIntensity * 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..isAntiAlias = true;
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, sPaint);
  }

  void _paintLine(Canvas canvas, Size size) {
    final pointSpacing = size.width / (pointCount - 1);
    final path = Path();

    final rawYValues = List.generate(pointCount, (idx) {
      final heightFactor = _getHeightForPoint(idx);
      return size.height - (heightFactor * sensitivity * amplitude * size.height * 0.5 + size.height * 0.1);
    });

    final smoothedY = List<double>.from(rawYValues);
    for (int k = 1; k < pointCount - 1; k++) {
      smoothedY[k] = (rawYValues[k-1] + rawYValues[k] * 2 + rawYValues[k+1]) / 4;
    }

    path.moveTo(0, smoothedY[0]);
    for (int i = 0; i < smoothedY.length - 1; i++) {
      final x1 = i * pointSpacing;
      final x2 = (i + 1) * pointSpacing;
      final y1 = smoothedY[i];
      final y2 = smoothedY[i + 1];
      final cpx1 = x1 + (x2 - x1) / 2.2;
      final cpx2 = x1 + (x2 - x1) / 1.7;
      path.cubicTo(cpx1, y1, cpx2, y2, x2, y2);
    }

    final lPaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 + beatIntensity * 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: (alpha * 0.5 + beatIntensity * 0.3).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 + beatIntensity * 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..isAntiAlias = true;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, lPaint);
  }

  void _paintMirrored(Canvas canvas, Size size) {
    final totalSpacing = barSpacing * (pointCount - 1);
    final barWidth = (size.width - totalSpacing) / pointCount;
    final centerY = size.height * 0.5;

    for (int i = 0; i < pointCount; i++) {
      final heightFactor = _getHeightForPoint(i);
      final halfHeight = (heightFactor * sensitivity * amplitude * size.height * 0.4).clamp(1.0, size.height * 0.5);
      final x = i * (barWidth + barSpacing);
      final paint = Paint()
        ..color = _getBarColor(i)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight * 2),
        Radius.circular(cornerRadius.clamp(0, barWidth / 2)),
      );
      canvas.drawRRect(rect, paint);

      final shinePaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: alpha * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawRect(Rect.fromLTWH(x + 1, centerY - halfHeight + 1, barWidth - 2, 2), shinePaint);
    }
  }

  void _paintCircular(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = math.min(cx, cy) * 0.8;
    final angleStep = (2 * math.pi) / pointCount;

    for (int i = 0; i < pointCount; i++) {
      final heightFactor = _getHeightForPoint(i);
      final barHeight = (heightFactor * sensitivity * amplitude * maxRadius * 0.6).clamp(1.0, maxRadius * 0.8);
      final angle = i * angleStep - math.pi / 2;
      final innerRadius = maxRadius * 0.2;

      final x0 = cx + innerRadius * math.cos(angle);
      final y0 = cy + innerRadius * math.sin(angle);
      final x1 = cx + (innerRadius + barHeight) * math.cos(angle);
      final y1 = cy + (innerRadius + barHeight) * math.sin(angle);

      final paint = Paint()
        ..color = _getBarColor(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = barSpacing > 0 ? (angleStep * maxRadius * 0.8 / pointCount).clamp(2.0, 12.0) : 4.0
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), paint);

      if (beatIntensity > 0.01) {
        final glowPaint = Paint()
          ..color = _getBarColor(i).withValues(alpha: alpha * 0.3 * beatIntensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (paint.strokeWidth + 4) * beatIntensity
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..isAntiAlias = true;
        canvas.drawLine(Offset(x0, y0), Offset(x1, y1), glowPaint);
      }
    }

    if (beatIntensity > 0.01) {
      final ringPaint = Paint()
        ..color = color.withValues(alpha: alpha * beatIntensity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * beatIntensity
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(Offset(cx, cy), maxRadius * 0.2 + beatIntensity * 10, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioVisualizerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.fftMagnitudes != fftMagnitudes ||
        oldDelegate.style != style ||
        oldDelegate.pointCount != pointCount ||
        oldDelegate.sensitivity != sensitivity ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.color != color ||
        oldDelegate.alpha != alpha ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.bpm != bpm ||
        oldDelegate.beatIntensity != beatIntensity ||
        oldDelegate.barColors != barColors;
  }
}
