import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps levels to colours', () {
    expect(LogLevelColors.light.of(LogLevel.error), LogLevelColors.light.error);
    expect(
      LogLevelColors.light.ofEntry(
        TalkerData('x', logLevel: LogLevel.critical),
      ),
      LogLevelColors.light.critical,
    );
    expect(
      LogLevelColors.light.ofEntry(TalkerData('x')),
      LogLevelColors.light.info,
    );
  });

  test('lerp interpolates between two colour sets', () {
    final mid = LogLevelColors.light.lerp(LogLevelColors.dark, 0.5);

    expect(
      mid.error,
      Color.lerp(LogLevelColors.light.error, LogLevelColors.dark.error, 0.5),
    );
  });

  test('withLogLevelColors registers the extension', () {
    final theme = ThemeData.light().withLogLevelColors(LogLevelColors.dark);

    expect(theme.extension<LogLevelColors>(), LogLevelColors.dark);
    expect(theme.logLevelColors, LogLevelColors.dark);
  });

  test('falls back to a brightness-aware default', () {
    expect(ThemeData.light().logLevelColors, LogLevelColors.light);
    expect(ThemeData.dark().logLevelColors, LogLevelColors.dark);
  });
}
