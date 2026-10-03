import 'dart:io';

import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stack_trace/stack_trace.dart';

void main() {
  late Directory tempDir;
  late Box box;
  late LogStorage storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('enhanced_logging_storage');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    box = await Hive.openBox('logs_test');
    await box.clear();
    storage = LogStorage(box);
  });

  tearDown(() async {
    if (box.isOpen) await box.close();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('adds and reads logs', () async {
    await storage.addLog(TalkerLog('first', logLevel: LogLevel.info));
    await storage.addLog(TalkerLog('second', logLevel: LogLevel.error));

    expect(storage.length, 2);
    expect(storage.logs.map((log) => log.message), ['first', 'second']);
    expect(storage.reversedLogs.map((log) => log.message), ['second', 'first']);
  });

  test('persists entries through the adapter across a reopen', () async {
    final trace = Trace.parse('#0      main (package:app/main.dart:1:1)');
    await storage.addLog(
      TalkerLog('persisted', logLevel: LogLevel.error, stackTrace: trace),
    );
    await box.close();

    box = await Hive.openBox('logs_test');
    storage = LogStorage(box);

    final log = storage.logs.single;
    expect(log.message, 'persisted');
    expect(log.logLevel, LogLevel.error);
    expect(log.hasStackTrace, isTrue);
    expect(log.stackTraceString, contains('package:app/main.dart'));
  });

  test('filters by level, query and time', () async {
    final now = DateTime.now();
    await storage.addLogs([
      TalkerData(
        'alpha',
        logLevel: LogLevel.debug,
        time: now.subtract(const Duration(minutes: 10)),
      ),
      TalkerData('beta', logLevel: LogLevel.error, time: now),
      TalkerData(
        'gamma',
        logLevel: LogLevel.warning,
        time: now,
        key: 'special',
      ),
    ]);

    expect(
      storage.filter(minLevel: LogLevel.warning).map((log) => log.message),
      ['beta', 'gamma'],
    );
    expect(storage.filter(query: 'alpha').map((log) => log.message), ['alpha']);
    expect(storage.filter(query: 'SPECIAL').map((log) => log.message), [
      'gamma',
    ]);
    expect(storage.filter(levels: {LogLevel.debug}).map((log) => log.message), [
      'alpha',
    ]);
    expect(
      storage
          .filter(since: now.subtract(const Duration(minutes: 1)))
          .map((log) => log.message),
      ['beta', 'gamma'],
    );
    expect(storage.filter(newestFirst: true, limit: 1).single.message, 'gamma');
  });

  test('getLogs keeps entries at least as severe as the minimum', () async {
    await storage.addLogs([
      TalkerLog('debug', logLevel: LogLevel.debug),
      TalkerLog('warning', logLevel: LogLevel.warning),
      TalkerLog('error', logLevel: LogLevel.error),
    ]);

    expect(storage.getLogs(LogLevel.warning).map((log) => log.message), [
      'error',
      'warning',
    ]);
  });

  test('newLogs emits added entries', () async {
    final received = <TalkerData>[];
    final subscription = storage.newLogs.listen(received.add);

    await storage.addLog(TalkerLog('streamed'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(received.single.message, 'streamed');
  });

  test('watchLogs emits the current list and updates', () async {
    await storage.addLog(TalkerLog('existing'));

    final emissions = <List<TalkerData>>[];
    final subscription = storage.watchLogs().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await storage.addLog(TalkerLog('fresh'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(emissions.first.map((log) => log.message), ['existing']);
    expect(emissions.last.map((log) => log.message), ['fresh', 'existing']);
  });

  test('clears logs', () async {
    await storage.addLog(TalkerLog('gone'));
    await storage.clearLogs();
    expect(storage.isEmpty, isTrue);
  });

  test('deleteOlderThan removes only entries before the threshold', () async {
    final now = DateTime(2026, 1, 10, 12);
    await storage.addLogs([
      TalkerData('old', time: DateTime(2026, 1, 7, 12)),
      TalkerData('edge', time: DateTime(2026, 1, 9, 12)),
      TalkerData('new', time: now),
    ]);

    expect(await storage.deleteOlderThan(DateTime(2026, 1, 9, 12)), 1);
    expect(storage.logs.map((log) => log.message), ['edge', 'new']);

    expect(await storage.deleteOlderThan(now), 1);
    expect(storage.logs.map((log) => log.message), ['new']);

    expect(await storage.deleteOlderThan(DateTime(2026, 1, 1)), 0);
    expect(storage.length, 1);
  });

  test('deleteOlderThanDuration prunes relative to now', () async {
    await storage.addLogs([
      TalkerData(
        'ancient',
        time: DateTime.now().subtract(const Duration(days: 400)),
      ),
      TalkerData('recent', time: DateTime.now()),
    ]);

    expect(await storage.deleteOlderThanDuration(const Duration(days: 30)), 1);
    expect(storage.logs.single.message, 'recent');
  });
}
