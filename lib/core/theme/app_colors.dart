import 'package:flutter/material.dart';

/// Raw Harbor palette values. [AppTheme] turns these into a [ColorScheme]
/// and [AppColorsExt] turns them into the app-specific tokens Material's
/// ColorScheme has no slot for (presence, message bubbles).
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.border,
    required this.error,
    required this.onError,
    required this.online,
    required this.warning,
  });

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color border;
  final Color error;
  final Color onError;
  final Color online;
  final Color warning;

  static const light = AppPalette(
    primary: Color(0xFF2F6D4F),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFEFF3F4),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF132025),
    muted: Color(0xFF647B82),
    border: Color(0xFFDCE4E6),
    error: Color(0xFFB3453A),
    onError: Color(0xFFFFFFFF),
    online: Color(0xFF3FA772),
    warning: Color(0xFFB8863A),
  );

  // Neutral near-black, Spotify-style dark surfaces — true grays (no blue
  // tint) at two elevations: #121212 base, #181818 for raised surfaces.
  static const dark = AppPalette(
    primary: Color(0xFF6FBF9A),
    onPrimary: Color(0xFF0B1F17),
    background: Color(0xFF121212),
    surface: Color(0xFF181818),
    ink: Color(0xFFFFFFFF),
    muted: Color(0xFFB3B3B3),
    border: Color(0xFF282828),
    error: Color(0xFFD97468),
    onError: Color(0xFF2B0D09),
    online: Color(0xFF45B57F),
    warning: Color(0xFFD9A44F),
  );
}

/// Presence/message-bubble colors, exposed via [Theme.of(context).extension].
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.online,
    required this.warning,
    required this.bubbleSent,
    required this.onBubbleSent,
    required this.bubbleReceived,
    required this.bubbleReceivedBorder,
    required this.onBubbleReceived,
  });

  final Color online;
  final Color warning;
  final Color bubbleSent;
  final Color onBubbleSent;
  final Color bubbleReceived;
  final Color bubbleReceivedBorder;
  final Color onBubbleReceived;

  static AppColorsExt fromPalette(AppPalette p) => AppColorsExt(
        online: p.online,
        warning: p.warning,
        bubbleSent: p.primary,
        onBubbleSent: p.onPrimary,
        bubbleReceived: p.surface,
        bubbleReceivedBorder: p.border,
        onBubbleReceived: p.ink,
      );

  @override
  AppColorsExt copyWith({
    Color? online,
    Color? warning,
    Color? bubbleSent,
    Color? onBubbleSent,
    Color? bubbleReceived,
    Color? bubbleReceivedBorder,
    Color? onBubbleReceived,
  }) {
    return AppColorsExt(
      online: online ?? this.online,
      warning: warning ?? this.warning,
      bubbleSent: bubbleSent ?? this.bubbleSent,
      onBubbleSent: onBubbleSent ?? this.onBubbleSent,
      bubbleReceived: bubbleReceived ?? this.bubbleReceived,
      bubbleReceivedBorder: bubbleReceivedBorder ?? this.bubbleReceivedBorder,
      onBubbleReceived: onBubbleReceived ?? this.onBubbleReceived,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      online: Color.lerp(online, other.online, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      bubbleSent: Color.lerp(bubbleSent, other.bubbleSent, t)!,
      onBubbleSent: Color.lerp(onBubbleSent, other.onBubbleSent, t)!,
      bubbleReceived: Color.lerp(bubbleReceived, other.bubbleReceived, t)!,
      bubbleReceivedBorder:
          Color.lerp(bubbleReceivedBorder, other.bubbleReceivedBorder, t)!,
      onBubbleReceived: Color.lerp(onBubbleReceived, other.onBubbleReceived, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColorsExt get appColors => Theme.of(this).extension<AppColorsExt>()!;
}
