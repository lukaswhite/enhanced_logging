import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_trace/stack_trace.dart';

void main() {
  group('TalkerData serialisation', () {
    test('round trips basic fields', () {
      final log = TalkerData(
        'hello world',
        title: 'my-title',
        logLevel: LogLevel.warning,
        time: DateTime.utc(2026, 1, 2, 3, 4, 5, 678),
        key: 'my-key',
      );

      final json = log.toJson();
      expect(json['message'], 'hello world');
      expect(json['title'], 'my-title');
      expect(json['level'], 'warning');
      expect(json['key'], 'my-key');
      expect(json['time'], '2026-01-02T03:04:05.678Z');

      final restored = talkerDataFromJson(json);
      expect(restored.message, 'hello world');
      expect(restored.title, 'my-title');
      expect(restored.logLevel, LogLevel.warning);
      expect(restored.key, 'my-key');
      expect(restored.time, DateTime.utc(2026, 1, 2, 3, 4, 5, 678));
    });

    test('serialises and parses stack traces with stack_trace', () {
      final trace = Trace.parse(
        '#0      Foo.bar (package:app/foo.dart:10:5)\n'
        '#1      main (package:app/main.dart:3:1)',
      );
      final log = TalkerData(
        'boom',
        logLevel: LogLevel.error,
        stackTrace: trace,
      );

      final json = log.toJson();
      expect(json['stackTrace'], contains('package:app/foo.dart'));

      final restored = talkerDataFromJson(json);
      expect(restored.hasStackTrace, isTrue);
      expect(restored.stackTraceString, contains('package:app/foo.dart'));
      expect(restored.trace, isA<Trace>());
      expect(restored.trace!.frames.first.member, 'Foo.bar');
    });

    test('preserves errors and exceptions as placeholder objects', () {
      final error = TalkerData(
        'failed',
        error: StateError('bad state'),
        logLevel: LogLevel.error,
        key: 'error',
      );
      final restoredError = talkerDataFromJson(error.toJson());
      expect(restoredError.isError, isTrue);
      expect(restoredError.errorMessage, contains('bad state'));
      expect(restoredError.error, isA<SerializedError>());

      final exception = TalkerException(
        FormatException('nope'),
        message: 'failed',
      );
      final restoredException = talkerDataFromJson(exception.toJson());
      expect(restoredException.isException, isTrue);
      expect(restoredException.exceptionMessage, contains('nope'));
      expect(restoredException.exception, isA<SerializedException>());
    });

    test('parses a list of entries', () {
      final logs = [
        TalkerLog('one'),
        TalkerLog('two', logLevel: LogLevel.debug),
      ];
      final encoded = talkerDataListToJson(logs);
      final decoded = talkerDataListFromJson(encoded);

      expect(decoded.map((log) => log.message), ['one', 'two']);
      expect(decoded[1].logLevel, LogLevel.debug);
    });

    test('exposes a searchable haystack', () {
      final log = TalkerData(
        'Something Happened',
        key: 'custom-key',
        logLevel: LogLevel.info,
      );
      expect(log.searchableText, contains('something happened'));
      expect(log.searchableText, contains('custom-key'));
    });
  });

  group('meetsLogLevelThreshold', () {
    test('keeps entries at least as severe as the threshold', () {
      expect(
        meetsLogLevelThreshold(LogLevel.critical, LogLevel.warning),
        isTrue,
      );
      expect(
        meetsLogLevelThreshold(LogLevel.warning, LogLevel.warning),
        isTrue,
      );
      expect(meetsLogLevelThreshold(LogLevel.info, LogLevel.warning), isFalse);
      expect(meetsLogLevelThreshold(LogLevel.verbose, LogLevel.error), isFalse);
      expect(meetsLogLevelThreshold(null, LogLevel.error), isFalse);
    });
  });
}
