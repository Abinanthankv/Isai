import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A high-performance CustomPainter that renders audio visualizer graphics
/// in multiple styles: Wave, Bar, and Line.
///
/// When [fftMagnitudes] is provided (from the native Android Visualizer),
/// it uses **real audio frequency data** to drive the visualization — the bars
/// and waves react to the actual song tempo, bass drops, and energy.
///
/// When [fftMagnitudes] is null (e.g. on non-Android platforms), it falls back
/// to a procedural animation driven by [animationValue].
class AudioVisualizerPainter extends CustomPainter {
  final String style; // 'wave', 'bar', 'line'
  final int pointCount;
  final double sensitivity;
  final double amplitude;
  final double animationValue; // 0.0 → 1.0 repeating (fallback only)
  final Color color;
  final double alpha;
  final double barSpacing;
  final double cornerRadius;
  final bool isPlaying;
  final double bpm;
  
  /// Real FFT magnitude data from the native Visualizer (0–255 per bin).
  /// When non-null, this drives the visualization instead of procedural math.
  final List<int>? fftMagnitudes;

  // Cached seeds for procedural fallback
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
  }) {
    if (!_seedCache.containsKey(pointCount)) {
      final rng = math.Random(42);
      _seedCache[pointCount] = List.generate(pointCount, (_) => rng.nextDouble());
    }
  }

  List<double> get _seeds => _seedCache[pointCount]!;

  /// Whether we have real audio data to work with.
  bool get _hasRealData => fftMagnitudes != null && fftMagnitudes!.isNotEmpty;

  /// Get the normalized height (0.0–1.0) for the i-th point.
  /// Uses real FFT data when available, procedural fallback otherwise.
  double _getHeightForPoint(int i) {
    if (_hasRealData) {
      final fft = fftMagnitudes!;
      
      // LOGARITHMIC MAPPING
      final double fraction = i / pointCount;
      // High-Pass Filter: Skip early bins that contain sub-sonic noise
      final int startBin = 12; 
      final int endBin = fft.length - 2;
      final int binRange = endBin - startBin;
      
      // Adjusted curve: 1.2 is a "sweet spot" that keeps bass on the left 
      // but lets vocals and melodies take up most of the middle/right.
      final double logIndex = (math.pow(fraction, 1.2) * binRange + startBin).toDouble();
      final int index = logIndex.floor().clamp(startBin, endBin);
      
      // VERTICAL SMOOTHING
      int sum = 0;
      int count = 0;
      for (int k = index - 1; k <= index + 1; k++) {
        if (k >= 0 && k < fft.length) {
          sum += fft[k];
          count++;
        }
      }
      double magnitude = (sum / count) / 255.0;
      
      // HIGH-FREQUENCY COMPENSATION (Treble Boost)
      // We scale the boost logarithmically so the far right (treble) 
      // is roughly 2.5x more sensitive than the bass.
      final double boost = 1.0 + (math.sqrt(fraction) * 1.5); 
      magnitude *= boost;
      
      return isPlaying ? magnitude.clamp(0.0, 1.3) : magnitude * 0.05;
    } else {
      // Procedural fallback reacting to BPM
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

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    switch (style) {
      case 'bar':
        _paintBars(canvas, size, paint);
        break;
      case 'wave':
        _paintWave(canvas, size, paint, strokePaint);
        break;
      case 'line':
        _paintLine(canvas, size, strokePaint);
        break;
      case 'mirrored':
        _paintMirrored(canvas, size, paint);
        break;
      default:
        _paintBars(canvas, size, paint);
    }
  }

  /// Renders vertical bars driven by real audio or procedural fallback.
  void _paintBars(Canvas canvas, Size size, Paint paint) {
    final totalSpacing = barSpacing * (pointCount - 1);
    final barWidth = (size.width - totalSpacing) / pointCount;
    if (barWidth <= 0) return;

    for (int i = 0; i < pointCount; i++) {
      final heightFactor = _getHeightForPoint(i);
      final barHeight = (heightFactor * sensitivity * amplitude * size.height).clamp(2.0, size.height);

      final x = i * (barWidth + barSpacing);
      final y = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(cornerRadius.clamp(0, barWidth / 2)),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  /// Renders a single high-fidelity smooth wave form.
  void _paintWave(Canvas canvas, Size size, Paint fillPaint, Paint strokePaint) {
    final pointSpacing = size.width / (pointCount - 1);
    final path = Path();
    
    final rawYValues = List.generate(pointCount, (idx) {
      final heightFactor = _getHeightForPoint(idx);
      return size.height - (heightFactor * sensitivity * amplitude * size.height * 0.5 + size.height * 0.2);
    });

    // Horizontal smoothing
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
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..isAntiAlias = true;
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, sPaint);
  }

  /// Renders a single clean frequency line.
  void _paintLine(Canvas canvas, Size size, Paint paint) {
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
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0)
      ..isAntiAlias = true;
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, lPaint);
  }

  /// NEW: Renders mirrored symmetric bars from the center.
  void _paintMirrored(Canvas canvas, Size size, Paint paint) {
    final totalSpacing = barSpacing * (pointCount - 1);
    final barWidth = (size.width - totalSpacing) / pointCount;
    final centerY = size.height * 0.5;

    for (int i = 0; i < pointCount; i++) {
      final heightFactor = _getHeightForPoint(i);
      final halfHeight = (heightFactor * sensitivity * amplitude * size.height * 0.4).clamp(1.0, size.height * 0.5);

      final x = i * (barWidth + barSpacing);
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, centerY - halfHeight, barWidth, halfHeight * 2),
        Radius.circular(cornerRadius.clamp(0, barWidth / 2)),
      );
      
      canvas.drawRRect(rect, paint);
      
      // Add a subtle glow/shine to mirrored bars
      final shinePaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: alpha * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawRect(Rect.fromLTWH(x + 1, centerY - halfHeight + 1, barWidth - 2, 2), shinePaint);
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
        oldDelegate.bpm != bpm;
  }
}
