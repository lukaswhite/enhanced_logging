import 'dart:io';

import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Polls [condition] so the tests never depend on a fixed delay.
Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the storage to catch up');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory tempDir;
  late Box box;
  late LogStorage storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'enhanced_logging_observer',
    );
    Hive.init(tempDir.path);
  });

  setUp(() async {
    box = await Hive.openBox('observer_test');
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

  test(
    'registerStorage mirrors logs, errors and exceptions into Hive',
    () async {
      final observer = LoggerObserver()..registerStorage(storage);

      expect(observer.storage, same(storage));

      observer.onLog(TalkerLog('hello', logLevel: LogLevel.info));
      observer.onError(TalkerError(StateError('boom'), message: 'boom'));
      observer.onException(
        TalkerException(FormatException('nope'), message: 'nope'),
      );

      await _waitFor(() => storage.length == 3);
      expect(storage.logs.map((log) => log.message), ['hello', 'boom', 'nope']);
    },
  );

  test('accepts a storage through the constructor', () async {
    final observer = LoggerObserver(storage: storage);

    observer.onLog(TalkerLog('from constructor'));
    await _waitFor(() => storage.length == 1);

    expect(storage.logs.single.message, 'from constructor');
  });

  test('unregisterStorage stops persisting', () async {
    final observer = LoggerObserver(storage: storage);

    observer.onLog(TalkerLog('kept'));
    await _waitFor(() => storage.length == 1);

    observer.unregisterStorage();
    expect(observer.storage, isNull);

    observer.onLog(TalkerLog('dropped'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(storage.logs.map((log) => log.message), ['kept']);
  });

  test('storageMinLevel only limits what is persisted', () async {
    final observer = LoggerObserver(
      storage: storage,
      storageMinLevel: LogLevel.error,
    );

    observer.onLog(TalkerLog('debug', logLevel: LogLevel.debug));
    observer.onLog(TalkerLog('error', logLevel: LogLevel.error));

    await _waitFor(() => storage.length == 1);
    expect(storage.logs.single.message, 'error');
    // The stream is unaffected by storageMinLevel.
    expect(observer.logs.value.message, 'error');
  });

  test('minLevel only limits the stream', () async {
    final observer = LoggerObserver(minLevel: LogLevel.error, storage: storage);

    observer.onLog(TalkerLog('quiet', logLevel: LogLevel.debug));
    await _waitFor(() => storage.length == 1);

    expect(storage.logs.single.message, 'quiet');
    expect(observer.logs.hasValue, isFalse);
  });

  test('a failing write never reaches the caller', () async {
    final observer = LoggerObserver(storage: storage);
    await box.close();

    // Must not throw even though the box is gone.
    observer.onLog(TalkerLog('after close'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(observer.storage, isNotNull);
  });
}
