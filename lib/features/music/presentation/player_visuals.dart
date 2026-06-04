import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/apple_music_theme.dart';

class RainbowSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2.0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeGradient = LinearGradient(
      colors: [
        AppleMusicTheme.primaryPink,
        AppleMusicTheme.primaryPurple,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.orange,
        Colors.red,
      ],
    );

    final activePaint = Paint()
      ..shader = activeGradient.createShader(trackRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight! + additionalActiveTrackHeight
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight!
      ..strokeCap = StrokeCap.round;

    final Offset startPoint = Offset(trackRect.left, trackRect.center.dy);
    final Offset endPoint = Offset(trackRect.right, trackRect.center.dy);
    final Offset thumbPoint = Offset(thumbCenter.dx, trackRect.center.dy);

    // Paint inactive track
    context.canvas.drawLine(thumbPoint, endPoint, inactivePaint);
    
    // Paint active rainbow track
    context.canvas.drawLine(startPoint, thumbPoint, activePaint);
  }
}

class WavySliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double width = trackRect.width;
    final double centerY = trackRect.center.dy;
    final double thumbX = thumbCenter.dx;
    
    // Parameters for the wave
    const double wavelength = 20.0;
    const double amplitude = 4.0;
    
    // Draw Inactive Track (Flat)
    context.canvas.drawLine(
      Offset(thumbX, centerY),
      Offset(trackRect.right, centerY),
      inactivePaint,
    );

    // Draw Active Track (Wavy)
    final Path wavyPath = Path();
    wavyPath.moveTo(trackRect.left, centerY);
    
    for (double x = trackRect.left; x <= thumbX; x += 1.0) {
      final relativeX = x - trackRect.left;
      final y = centerY + math.sin(relativeX * 2 * math.pi / wavelength) * amplitude;
      wavyPath.lineTo(x, y);
    }
    
    context.canvas.drawPath(wavyPath, activePaint);
  }
}

class GradientSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2.0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final activeGradient = LinearGradient(
      colors: [
        AppleMusicTheme.primaryPink,
        AppleMusicTheme.primaryPurple,
      ],
    );
    final activePaint = Paint()
      ..shader = activeGradient.createShader(trackRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight! + additionalActiveTrackHeight
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight!
      ..strokeCap = StrokeCap.round;
    context.canvas.drawLine(Offset(thumbCenter.dx, trackRect.center.dy), Offset(trackRect.right, trackRect.center.dy), inactivePaint);
    context.canvas.drawLine(Offset(trackRect.left, trackRect.center.dy), Offset(thumbCenter.dx, trackRect.center.dy), activePaint);
  }
}

class CapsuleSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double capsuleHeight = 12.0;
    final double centerY = trackRect.center.dy;
    final RRect inactiveRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(trackRect.left, centerY - capsuleHeight / 2, trackRect.right, centerY + capsuleHeight / 2),
      const Radius.circular(6.0),
    );
    final RRect activeRRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(trackRect.left, centerY - capsuleHeight / 2, thumbCenter.dx, centerY + capsuleHeight / 2),
      const Radius.circular(6.0),
    );
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor ?? Colors.white12;
    final activePaint = Paint()..color = sliderTheme.activeTrackColor ?? Colors.white;
    context.canvas.drawRRect(inactiveRRect, inactivePaint);
    context.canvas.drawRRect(activeRRect, activePaint);
  }
}

class NeonSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2.0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double activeHeight = sliderTheme.trackHeight! + additionalActiveTrackHeight;
    final Color activeColor = sliderTheme.activeTrackColor ?? Colors.white;
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeHeight + 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeHeight
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = sliderTheme.trackHeight!
      ..strokeCap = StrokeCap.round;
    final Offset startPoint = Offset(trackRect.left, trackRect.center.dy);
    final Offset endPoint = Offset(trackRect.right, trackRect.center.dy);
    final Offset thumbPoint = Offset(thumbCenter.dx, trackRect.center.dy);
    context.canvas.drawLine(thumbPoint, endPoint, inactivePaint);
    context.canvas.drawLine(startPoint, thumbPoint, glowPaint);
    context.canvas.drawLine(startPoint, thumbPoint, activePaint);
  }
}

class DashedSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double centerY = trackRect.center.dy;
    final double dashWidth = 4.0;
    final double dashSpace = 4.0;
    final double step = dashWidth + dashSpace;
    final double trackHeight = 6.0;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.square;
    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.square;
    for (double x = trackRect.left; x < thumbCenter.dx; x += step) {
      final double endX = math.min(x + dashWidth, thumbCenter.dx);
      context.canvas.drawLine(Offset(x, centerY), Offset(endX, centerY), activePaint);
    }
    for (double x = thumbCenter.dx; x < trackRect.right; x += step) {
      final double endX = math.min(x + dashWidth, trackRect.right);
      context.canvas.drawLine(Offset(x, centerY), Offset(endX, centerY), inactivePaint);
    }
  }
}

class DottedSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double centerY = trackRect.center.dy;
    final double dotRadius = 2.0;
    final double dotSpace = 6.0;
    final double step = dotRadius * 2 + dotSpace;
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white12
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.white
      ..style = PaintingStyle.fill;
    for (double x = trackRect.left + dotRadius; x < thumbCenter.dx; x += step) {
      context.canvas.drawCircle(Offset(x, centerY), dotRadius, activePaint);
    }
    for (double x = thumbCenter.dx + dotRadius; x < trackRect.right; x += step) {
      context.canvas.drawCircle(Offset(x, centerY), dotRadius, inactivePaint);
    }
  }
}
