import 'package:hive/hive.dart';
import 'package:rxdart/rxdart.dart';
import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import 'adapters/talker_data_adapter.dart';

/// A persistent, observable store of [TalkerData] entries backed by a Hive
/// [Box].
///
/// The host application owns the Hive box (it must be opened after
/// `Hive.initFlutter()`); [LogStorage] registers [TalkerDataAdapter]
/// automatically the first time it is constructed.
///
/// ```dart
/// final storage = LogStorage(Hive.box('logs'));
/// await storage.addLog(TalkerLog('Hello'));
/// ```
class LogStorage {
  /// Wraps an already opened Hive [box].
  LogStorage(this._box) {
    _registerAdapter();
  }

  final Box _box;

  static final TalkerDataAdapter _adapter = TalkerDataAdapter();

  static void _registerAdapter() {
    if (Hive.isAdapterRegistered(TalkerDataAdapter.typeIdValue)) return;
    try {
      Hive.registerAdapter(_adapter);
    } on HiveError {
      // Already registered (possibly by another isolate) - safe to ignore.
    }
  }

  /// The underlying Hive box.
  Box get box => _box;

  /// The number of stored entries.
  int get length => _box.length;

  /// Whether there are no stored entries.
  bool get isEmpty => _box.isEmpty;

  /// Whether there is at least one stored entry.
  bool get isNotEmpty => _box.isNotEmpty;

  /// All stored entries in insertion order (oldest first).
  List<TalkerData> get logs => _box.values.cast<TalkerData>().toList();

  /// All stored entries, newest first.
  List<TalkerData> get reversedLogs => logs.reversed.toList();

  /// The [count] most recent entries, newest first.
  List<TalkerData> recentLogs([int count = 10]) {
    final list = reversedLogs;
    return count >= list.length ? list : list.sublist(0, count);
  }

  /// Appends [log] and returns its Hive key.
  Future<int> addLog(TalkerData log) => _box.add(log);

  /// Appends every entry in [logsToAdd].
  Future<void> addLogs(Iterable<TalkerData> logsToAdd) async {
    await _box.addAll(logsToAdd);
  }

  /// Deletes [log] from the store.
  ///
  /// Matching relies on [TalkerData] identity. Hive caches the decoded values,
  /// so entries previously returned from this storage compare by identity.
  Future<void> deleteLog(TalkerData log) async {
    final index = logs.indexOf(log);
    if (index >= 0) await _box.deleteAt(index);
  }

  /// Deletes the entry at the given box [index].
  Future<void> deleteAt(int index) => _box.deleteAt(index);

  /// Deletes every entry whose timestamp is before [threshold].
  ///
  /// Returns the number of entries that were removed, so it can be used to
  /// prune the store on start-up:
  ///
  /// ```dart
  /// await storage.deleteOlderThan(
  ///   DateTime.now().subtract(const Duration(days: 7)),
  /// );
  /// ```
  Future<int> deleteOlderThan(DateTime threshold) async {
    final expired = <dynamic>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is TalkerData && value.time.isBefore(threshold)) {
        expired.add(key);
      }
    }
    if (expired.isEmpty) return 0;
    await _box.deleteAll(expired);
    return expired.length;
  }

  /// Deletes every entry older than [age] relative to `DateTime.now()`.
  ///
  /// ```dart
  /// await storage.deleteOlderThanDuration(const Duration(days: 7));
  /// ```
  Future<int> deleteOlderThanDuration(Duration age) =>
      deleteOlderThan(DateTime.now().subtract(age));

  /// Removes every stored entry.
  Future<void> clearLogs() async {
    await _box.clear();
  }

  /// Entries at least as severe as [minLevel], newest first.
  List<TalkerData> getLogs(LogLevel minLevel) =>
      filter(minLevel: minLevel, newestFirst: true);

  /// Returns entries matching the supplied filters.
  ///
  /// * [minLevel] keeps entries at least as severe as the given level.
  /// * [levels] keeps entries whose level is in the set (empty means "all").
  /// * [query] performs a case-insensitive full-text search.
  /// * [since] / [until] restrict by timestamp.
  List<TalkerData> filter({
    LogLevel? minLevel,
    Set<LogLevel>? levels,
    String? query,
    DateTime? since,
    DateTime? until,
    bool newestFirst = false,
    int? limit,
  }) {
    final source = newestFirst ? reversedLogs : logs;
    final needle = query?.trim().toLowerCase();
    final result = <TalkerData>[];

    for (final log in source) {
      if (levels != null &&
          levels.isNotEmpty &&
          !levels.contains(log.logLevel)) {
        continue;
      }
      if (minLevel != null &&
          !meetsLogLevelThreshold(log.logLevel ?? LogLevel.info, minLevel)) {
        continue;
      }
      if (since != null && log.time.isBefore(since)) continue;
      if (until != null && log.time.isAfter(until)) continue;
      if (needle != null &&
          needle.isNotEmpty &&
          !log.searchableText.contains(needle)) {
        continue;
      }

      result.add(log);
      if (limit != null && result.length >= limit) break;
    }

    return result;
  }

  /// A broadcast stream of raw Hive box change events.
  Stream<BoxEvent> watch() => _box.watch();

  /// Emits every newly added entry (ignoring deletions and updates).
  Stream<TalkerData> get newLogs => _box
      .watch()
      .where((event) => !event.deleted && event.value is TalkerData)
      .map((event) => event.value as TalkerData);

  /// Emits the current entries immediately and again on every change.
  ///
  /// This is the stream used by the live widgets to stay in sync with Hive.
  Stream<List<TalkerData>> watchLogs({bool newestFirst = true, int? limit}) {
    List<TalkerData> snapshot() {
      final list = newestFirst ? reversedLogs : logs;
      if (limit == null || list.length <= limit) return list;
      return list.sublist(0, limit);
    }

    return _box.watch().map((_) => snapshot()).startWith(snapshot());
  }
}
