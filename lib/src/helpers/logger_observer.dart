import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../storage/log_storage.dart';

/// Talker only allows a single observer to be attached to a `Talker` instance.
///
/// This observer fans every event out through broadcast streams so that any
/// number of widgets, storage writers or analytics hooks can listen to the
/// same [Talker]. Attach it with `Talker(observer: LoggerObserver())`.
///
/// Because `Talker` supports a single observer, the same instance can also
/// persist everything it sees into a [LogStorage]:
///
/// ```dart
/// final observer = LoggerObserver()..registerStorage(storage);
/// final talker = Talker(observer: observer);
/// ```
class LoggerObserver extends TalkerObserver {
  /// Creates an observer.
  ///
  /// When [minLevel] is provided, entries less severe than [minLevel] are
  /// dropped before they reach the [logs] stream.
  ///
  /// When [storage] is provided every entry is also mirrored into Hive;
  /// [storageMinLevel] optionally limits what is persisted, independently of
  /// [minLevel].
  LoggerObserver({
    LogLevel? logLevel,
    LogLevel? minLevel,
    this.storage,
    this.storageMinLevel,
  }) : minLevel = minLevel ?? logLevel;

  /// The minimum severity forwarded to [logs]. `null` forwards everything.
  final LogLevel? minLevel;

  /// The minimum severity persisted to [storage]. `null` persists everything.
  final LogLevel? storageMinLevel;

  /// The storage every entry is mirrored into, or `null` when nothing is
  /// persisted. Set it directly or via [registerStorage].
  LogStorage? storage;

  /// Registers [storage] so every following entry is also persisted into Hive.
  ///
  /// Returns this instance so it can be chained:
  /// `LoggerObserver()..registerStorage(storage)`.
  LoggerObserver registerStorage(LogStorage storage) {
    this.storage = storage;
    return this;
  }

  /// Stops persisting entries.
  void unregisterStorage() => storage = null;

  /// Every forwarded log entry.
  final BehaviorSubject<TalkerData> logs = BehaviorSubject<TalkerData>();

  /// Every forwarded [TalkerError].
  final BehaviorSubject<TalkerError> errors = BehaviorSubject<TalkerError>();

  /// Every forwarded [TalkerException].
  final BehaviorSubject<TalkerException> exceptions =
      BehaviorSubject<TalkerException>();

  /// A broadcast view of every forwarded log entry.
  Stream<TalkerData> get logStream => logs.stream;

  /// Called when [Talker] handles an [TalkerError].
  @override
  void onError(TalkerError err) {
    errors.add(err);
    _persist(err);
    if (_passes(err)) logs.add(err);
  }

  /// Called when [Talker] handles an [TalkerException].
  @override
  void onException(TalkerException err) {
    exceptions.add(err);
    _persist(err);
    if (_passes(err)) logs.add(err);
  }

  /// Called when [Talker] handles a [TalkerData] log.
  @override
  void onLog(TalkerData log) {
    _persist(log);
    if (!_passes(log)) return;
    logs.add(log);
  }

  bool _passes(TalkerData log) {
    final threshold = minLevel;
    if (threshold == null) return true;
    return meetsLogLevelThreshold(log.logLevel ?? LogLevel.info, threshold);
  }

  void _persist(TalkerData log) {
    final target = storage;
    if (target == null) return;

    final threshold = storageMinLevel;
    if (threshold != null &&
        !meetsLogLevelThreshold(log.logLevel ?? LogLevel.info, threshold)) {
      return;
    }

    unawaited(_addQuietly(target, log));
  }

  /// Persisting must never break the caller's logging call, for example when
  /// the box has already been closed.
  Future<void> _addQuietly(LogStorage target, TalkerData log) async {
    try {
      await target.addLog(log);
    } catch (_) {
      // Ignored on purpose - see above.
    }
  }

  /// Closes the underlying streams.
  Future<void> dispose() async {
    await logs.close();
    await errors.close();
    await exceptions.close();
  }
}
