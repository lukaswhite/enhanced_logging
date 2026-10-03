## 0.0.1

* `LogStorage`: Hive-backed, observable store for `TalkerData` with
  `filter()`, `getLogs()`, `watchLogs()` and `newLogs`.
* Added `LogStorage.deleteOlderThan()` and `deleteOlderThanDuration()` to prune
  entries by age; both return the number of entries removed.
* `TalkerDataAdapter` now serialises the full entry – message, title, level,
  key, timestamp, error, exception and stack trace – as JSON.
* The Hive dependency is now `package:hive` rather than `hive_ce`. Because
  `hive` only accepts external type ids in the range `0..223`, the adapter type
  id moved from `999` to `223`.
* `TalkerDataExtension` gained `toJson()`, `stackTraceString`, `summary`,
  `searchableText`, `effectiveKey` and friends; `talkerDataFromJson()` and
  `talkerDataListToJson()` provide standalone codecs.
* Stack traces are serialised/parsed with the `stack_trace` package.
* Added `LogStorageObserver` for persisting talker events into Hive.
* `LoggerObserver` can now also persist: pass `storage:` to the constructor or
  call `registerStorage()` / `unregisterStorage()`. `storageMinLevel` limits
  what is persisted independently of the stream `minLevel`, and persistence
  failures never reach the caller.
* `LoggerObserver` now also forwards errors and exceptions.
* Added the `LogLevelColors` theme extension.
* Added `RecentLogsCard`, `LogEntryTile`, `LogViewer` and `LogToastWrapper`.
* Every widget now accepts optional builders – `cardBuilder`, `headerBuilder`,
  `toolbarBuilder`, `tileBuilder`, `emptyBuilder`, `errorBuilder`,
  `collapsedBuilder`, `detailsBuilder` and `toastBuilder` – so any part can be
  restyled or replaced.
* `LogViewer` now surfaces Hive stream failures through `errorBuilder` instead
  of silently keeping stale data.
* Added `LogExporter` with text, JSON and CSV output, writing to the file system
  or triggering a browser download on Flutter Web.
* Fixed the level filtering in `getLogs`, which previously kept the least severe
  levels instead of the most severe ones.
