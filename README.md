<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

Opinionated, batteries-included logging for Flutter, built on top of
[`talker`](https://pub.dev/packages/talker) and
[`hive`](https://pub.dev/packages/hive).

Log entries are persisted in Hive, streamed live into the widget tree, exported
to a file (or a browser download on the web) and surfaced through ready-made
dashboard and page widgets.

## Features

* **Persistent storage** – `LogStorage` wraps a Hive box and (de)serialises
  `TalkerData` – message, title, level, key, timestamp, error, exception **and
  stack trace** (via the `stack_trace` package).
* **Live streams** – `watchLogs()` and `newLogs` emit straight from Hive, so
  widgets update themselves.
* **Theme extension** – `LogLevelColors` gives every `LogLevel` a colour and an
  icon, and takes part in theme lerping.
* **Dashboard card** – `RecentLogsCard` shows the latest entries collapsed to
  just their timestamp, with a button to expand the full detail (stack traces
  included).
* **Full page viewer** – `LogViewer` adds search, level and time filters,
  sorting, a live/pause toggle and export.
* **Export** – `LogExporter` encodes text, JSON or CSV and writes a file. On
  Flutter Web the file is handed to the browser as a download.
* **Toast wrapper** – `LogToastWrapper` shows toasts for entries at or above a
  severity threshold.

## Getting started

Add the dependency, initialise Hive, then wrap an opened box in `LogStorage`.

```yaml
dependencies:
  enhanced_logging: ^0.0.1
```

## Usage

### Storage

```dart
import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // or Hive.init(path) on platforms that need it

  final storage = LogStorage(await Hive.openBox('logs'));
  runApp(MyApp(storage: storage));
}
```

`LogStorage` registers `TalkerDataAdapter` (type id `223`) for you.

`package:hive` only accepts external type ids in the range `0..223`, which is
why the adapter uses `223` rather than the larger id `hive_ce` allowed.

Old entries can be pruned in one call:

```dart
// Everything strictly before the given instant:
await storage.deleteOlderThan(DateTime.now().subtract(const Duration(days: 7)));

// Same thing, expressed as an age. Both return the number of entries removed.
final removed = await storage.deleteOlderThanDuration(const Duration(days: 7));
```

### Wiring up Talker

`Talker` only supports a single observer, so `LoggerObserver` can both fan
events out to streams **and** persist them. Register a storage and use the one
observer for everything:

```dart
final observer = LoggerObserver()..registerStorage(storage);
final talker = Talker(observer: observer);

// Or pass it up front:
final observer = LoggerObserver(storage: storage);

// Stop persisting later, while keeping the streams alive:
observer.unregisterStorage();
```

The two severity thresholds are independent:

```dart
LoggerObserver(
  minLevel: LogLevel.verbose,   // what reaches the streams
  storage: storage,
  storageMinLevel: LogLevel.error, // what reaches Hive
);
```

If you only need persistence, `LogStorageObserver` does just that:

```dart
Talker(observer: LogStorageObserver(storage, minLevel: LogLevel.warning));
```

### Colours from the theme

Register `LogLevelColors` on your `ThemeData`; the widgets fall back to
brightness-aware defaults if you don't.

```dart
MaterialApp(
  theme: ThemeData.light().withLogLevelColors(),
  darkTheme: ThemeData.dark().withLogLevelColors(LogLevelColors.dark),
);
```

Read it anywhere with `context.logLevelColors`:

```dart
final colors = context.logLevelColors;
final color = colors.of(LogLevel.error);
final icon = colors.iconOf(LogLevel.error);
```

### Dashboard card

```dart
RecentLogsCard(
  storage: storage,
  maxEntries: 5,
  minLevel: LogLevel.warning,
)
```

Collapsed rows show **only** the timestamp; tap a row (or its chevron) to expand
the message, metadata, error/exception and stack trace.

### Full page viewer

```dart
Scaffold(
  appBar: AppBar(title: const Text('Logs')),
  body: LogViewer(storage: storage),
)
```

The viewer streams live from Hive and provides:

* case-insensitive full-text search (message, title, key, level, error,
  exception and stack trace),
* level filter chips (multi-select),
* a time-range presets menu,
* newest/oldest sort toggle and a live pause button,
* export to text/JSON/CSV,
* clear all.

### Exporting a file

```dart
// Encode without touching the file system:
final csv = LogExporter.encode(storage.reversedLogs, format: LogExportFormat.csv);

// Or write it out. On web this triggers a browser download.
final result = await LogExporter.save(
  storage.reversedLogs,
  format: LogExportFormat.json,
  // directoryPath: '/tmp/exports', // optional on io platforms
);
debugPrint(result.description);
```

### Toast notifications

```dart
LogToastWrapper(
  storage: storage,
  minLevel: LogLevel.error,
  position: LogToastPosition.bottomRight,
  child: MaterialApp(home: HomePage()),
)
```

You can also supply any `Stream<TalkerData>` instead of a storage, for example
`loggerObserver.logStream`.

### Customising the widgets

Every widget takes optional builders so you can restyle or replace any part of
it. Omit a builder to keep the default.

```dart
RecentLogsCard(
  storage: storage,
  // Wrap (or replace) the default Card.
  cardBuilder: (context, card, logs) =>
      Padding(padding: const EdgeInsets.all(8), child: card),
  // Replace the header, including the clear action.
  headerBuilder: (context, count, onClear) => Row(
    children: [
      Text('$count issues'),
      IconButton(onPressed: onClear, icon: const Icon(Icons.delete_sweep)),
    ],
  ),
  // Replace each row. Same signature as LogViewer.tileBuilder.
  tileBuilder: (context, log, expanded, onToggle) => ListTile(
    title: Text(log.summary),
    subtitle: Text(log.time.toIso8601String()),
    onTap: onToggle,
  ),
);
```

| Widget | Builders |
| --- | --- |
| `RecentLogsCard` | `cardBuilder`, `headerBuilder`, `tileBuilder`, `emptyBuilder`, `errorBuilder` |
| `LogViewer` | `toolbarBuilder`, `tileBuilder`, `emptyBuilder`, `errorBuilder` |
| `LogToastWrapper` | `toastBuilder` |
| `LogEntryTile` | `collapsedBuilder`, `detailsBuilder` |

The tile builders share the `LogEntryTileBuilder` signature
`(context, log, expanded, onToggle)`, so one builder can serve both the card and
the viewer. `toolbarBuilder` receives the default toolbar, which you can keep,
wrap or discard.

### Serialising entries yourself

Entries are serialised with `TalkerDataExtension.toJson()` and restored with
`talkerDataFromJson()`. Stack traces are written using `stack_trace` so they can
be parsed back into a `Trace`.

```dart
final map = log.toJson();
final restored = talkerDataFromJson(map);
assert(restored.stackTraceString == log.stackTraceString);
```

## API overview

| Type | Purpose |
| --- | --- |
| `LogStorage` | Hive-backed store: read, filter, stream, prune, clear. |
| `TalkerDataAdapter` | Hive `TypeAdapter` persisting `TalkerData` as JSON. |
| `TalkerDataExtension` | `toJson`, `trace`, `stackTraceString`, `summary`, `searchableText`, … |
| `talkerDataFromJson` / `talkerDataListToJson` | Standalone codecs. |
| `LogStorageObserver` | Persists talker events into a `LogStorage`. |
| `LoggerObserver` | Fans talker events out to streams and optionally into a `LogStorage`. |
| `LogLevelColors` | Theme extension with per-level colours and icons. |
| `RecentLogsCard` | Live dashboard card of recent entries. |
| `LogViewer` | Full page viewer with search and filters. |
| `LogExporter` | Text/JSON/CSV encoding and file/browser export. |
| `LogToastWrapper` | Toast notifications above a severity threshold. |
| `LogEntryTile` | The individual expandable row used by the widgets. |
| `LogEntryTileBuilder` / `LogCollapsedBuilder` / `LogDetailsBuilder` / `LogToastBuilder` | Builder signatures for customising the widgets. |

## Additional information

* Contributions and issues are welcome.
* Successfully tested with `TalkerData`, `TalkerLog`, `TalkerError` and
  `TalkerException` (subclasses are persisted through the same adapter).
* On Flutter Web, `LogExporter.save` uses an object URL and an anchor element to
  trigger a download; no extra setup is required.
