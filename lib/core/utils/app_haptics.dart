import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/music/presentation/music_providers.dart';

enum HapticFeedbackType {
  selection,
  light,
  medium,
  heavy,
}

class AppHaptics {
  /// Primary trigger accepting [WidgetRef] or [BuildContext]
  static void trigger(dynamic contextOrRef, {HapticFeedbackType type = HapticFeedbackType.light}) {
    bool enabled = true;
    String intensity = 'medium';

    try {
      if (contextOrRef is WidgetRef) {
        final settings = contextOrRef.read(settingsProvider);
        enabled = settings.hapticsEnabled;
        intensity = settings.hapticIntensity.toLowerCase();
      } else if (contextOrRef is BuildContext) {
        final container = ProviderScope.containerOf(contextOrRef, listen: false);
        final settings = container.read(settingsProvider);
        enabled = settings.hapticsEnabled;
        intensity = settings.hapticIntensity.toLowerCase();
      }
    } catch (_) {
      // Fallback if scope context is unmounted
    }

    if (!enabled || intensity == 'off') return;

    switch (intensity) {
      case 'light':
        HapticFeedback.selectionClick();
        break;
      case 'heavy':
        if (type == HapticFeedbackType.selection) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
        break;
      case 'medium':
      default:
        switch (type) {
          case HapticFeedbackType.selection:
            HapticFeedback.selectionClick();
            break;
          case HapticFeedbackType.light:
            HapticFeedback.lightImpact();
            break;
          case HapticFeedbackType.medium:
            HapticFeedback.mediumImpact();
            break;
          case HapticFeedbackType.heavy:
            HapticFeedback.heavyImpact();
            break;
        }
        break;
    }
  }

  static void light([dynamic contextOrRef]) => trigger(contextOrRef, type: HapticFeedbackType.light);
  static void medium([dynamic contextOrRef]) => trigger(contextOrRef, type: HapticFeedbackType.medium);
  static void heavy([dynamic contextOrRef]) => trigger(contextOrRef, type: HapticFeedbackType.heavy);
  static void selection([dynamic contextOrRef]) => trigger(contextOrRef, type: HapticFeedbackType.selection);
}
