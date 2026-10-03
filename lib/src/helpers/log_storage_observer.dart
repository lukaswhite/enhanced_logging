import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../storage/log_storage.dart';

/// A [TalkerObserver] that persists every handled event into a [LogStorage].
///
/// Attach it to a `Talker` to mirror logs, errors and exceptions into Hive:
///
/// ```dart
/// final talker = Talker(observer: LogStorageObserver(storage));
/// ```
class LogStorageObserver extends TalkerObserver {
  /// Creates an observer writing into [storage].
  ///
  /// When [minLevel] is provided, entries less severe than [minLevel] are not
  /// persisted.
  LogStorageObserver(this.storage, {this.minLevel});

  /// The destination store.
  final LogStorage storage;

  /// The minimum severity to persist. `null` persists everything.
  final LogLevel? minLevel;

  @override
  void onError(TalkerError err) => _persist(err);

  @override
  void onException(TalkerException err) => _persist(err);

  @override
  void onLog(TalkerData log) => _persist(log);

  Future<void> _persist(TalkerData log) async {
    final threshold = minLevel;
    if (threshold != null &&
        !meetsLogLevelThreshold(log.logLevel ?? LogLevel.info, threshold)) {
      return;
    }
    await storage.addLog(log);
  }
}
