import 'package:flutter/material.dart';
import 'package:talker/talker.dart';

/// A [ThemeExtension] describing the colour used for each [LogLevel].
///
/// Register it on a [ThemeData] with
/// [LogLevelColorsThemeExtension.withLogLevelColors] or by adding it to
/// `ThemeData.extensions`. When it is not registered the log widgets fall back
/// to [LogLevelColors.light] / [LogLevelColors.dark] based on the current
/// [Brightness].
@immutable
class LogLevelColors extends ThemeExtension<LogLevelColors> {
  /// Creates a set of log level colours.
  const LogLevelColors({
    required this.critical,
    required this.error,
    required this.warning,
    required this.info,
    required this.debug,
    required this.verbose,
    this.tintOpacity = 0.14,
  });

  /// Colour used for [LogLevel.critical].
  final Color critical;

  /// Colour used for [LogLevel.error].
  final Color error;

  /// Colour used for [LogLevel.warning].
  final Color warning;

  /// Colour used for [LogLevel.info].
  final Color info;

  /// Colour used for [LogLevel.debug].
  final Color debug;

  /// Colour used for [LogLevel.verbose].
  final Color verbose;

  /// Opacity applied to a level colour when painting container backgrounds.
  final double tintOpacity;

  /// The colour associated with [level].
  Color of(LogLevel level) {
    switch (level) {
      case LogLevel.critical:
        return critical;
      case LogLevel.error:
        return error;
      case LogLevel.warning:
        return warning;
      case LogLevel.info:
        return info;
      case LogLevel.debug:
        return debug;
      case LogLevel.verbose:
        return verbose;
    }
  }

  /// The colour associated with [log]'s level (defaults to [LogLevel.info]).
  Color ofEntry(TalkerData log) => of(log.logLevel ?? LogLevel.info);

  /// A translucent version of [of] suitable for chip / container backgrounds.
  Color tintOf(LogLevel level) => of(level).withValues(alpha: tintOpacity);

  /// An icon that represents [level].
  IconData iconOf(LogLevel level) {
    switch (level) {
      case LogLevel.critical:
        return Icons.dangerous_outlined;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.warning:
        return Icons.warning_amber_outlined;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.debug:
        return Icons.bug_report_outlined;
      case LogLevel.verbose:
        return Icons.notes_outlined;
    }
  }

  /// Default colours tuned for a light [ThemeData].
  static const LogLevelColors light = LogLevelColors(
    critical: Color(0xFF7B1FA2),
    error: Color(0xFFD32F2F),
    warning: Color(0xFFEF6C00),
    info: Color(0xFF1976D2),
    debug: Color(0xFF388E3C),
    verbose: Color(0xFF616161),
  );

  /// Default colours tuned for a dark [ThemeData].
  static const LogLevelColors dark = LogLevelColors(
    critical: Color(0xFFCE93D8),
    error: Color(0xFFEF9A9A),
    warning: Color(0xFFFFCC80),
    info: Color(0xFF90CAF9),
    debug: Color(0xFFA5D6A7),
    verbose: Color(0xFFBDBDBD),
  );

  @override
  LogLevelColors copyWith({
    Color? critical,
    Color? error,
    Color? warning,
    Color? info,
    Color? debug,
    Color? verbose,
    double? tintOpacity,
  }) {
    return LogLevelColors(
      critical: critical ?? this.critical,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      debug: debug ?? this.debug,
      verbose: verbose ?? this.verbose,
      tintOpacity: tintOpacity ?? this.tintOpacity,
    );
  }

  @override
  LogLevelColors lerp(ThemeExtension<LogLevelColors>? other, double t) {
    if (other is! LogLevelColors) return this;
    return LogLevelColors(
      critical: Color.lerp(critical, other.critical, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      debug: Color.lerp(debug, other.debug, t)!,
      verbose: Color.lerp(verbose, other.verbose, t)!,
      tintOpacity: tintOpacity + (other.tintOpacity - tintOpacity) * t,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogLevelColors &&
        other.critical == critical &&
        other.error == error &&
        other.warning == warning &&
        other.info == info &&
        other.debug == debug &&
        other.verbose == verbose &&
        other.tintOpacity == tintOpacity;
  }

  @override
  int get hashCode =>
      Object.hash(critical, error, warning, info, debug, verbose, tintOpacity);
}

/// Theme helpers for [LogLevelColors].
extension LogLevelColorsThemeExtension on ThemeData {
  /// The registered [LogLevelColors] or a brightness-aware default.
  LogLevelColors get logLevelColors =>
      extension<LogLevelColors>() ??
      (brightness == Brightness.dark
          ? LogLevelColors.dark
          : LogLevelColors.light);

  /// Returns a copy of this theme with [colors] registered as an extension.
  ThemeData withLogLevelColors([LogLevelColors? colors]) {
    final resolved =
        colors ??
        (brightness == Brightness.dark
            ? LogLevelColors.dark
            : LogLevelColors.light);
    final updated = extensions.values.toList()
      ..removeWhere((extension) => extension is LogLevelColors)
      ..add(resolved);
    return copyWith(extensions: updated);
  }
}

/// Convenience access to [LogLevelColorsThemeExtension.logLevelColors].
extension LogLevelColorsContextExtension on BuildContext {
  /// The [LogLevelColors] from the nearest [ThemeData].
  LogLevelColors get logLevelColors => Theme.of(this).logLevelColors;
}
