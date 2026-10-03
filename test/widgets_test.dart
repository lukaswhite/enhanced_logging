import 'dart:async';
import 'dart:typed_data';

import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:stack_trace/stack_trace.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().withLogLevelColors(),
    home: Scaffold(body: child),
  );
}

void main() {
  late Box box;
  late LogStorage storage;

  setUp(() async {
    // An in-memory box keeps these tests free of real file I/O, which the fake
    // async zone used by `testWidgets` cannot complete.
    box = await Hive.openBox('widgets_test', bytes: Uint8List(0));
    await box.clear();
    storage = LogStorage(box);
  });

  tearDown(() async {
    if (box.isOpen) await box.close();
  });

  testWidgets('RecentLogsCard collapses to the timestamp and expands', (
    tester,
  ) async {
    await storage.addLog(
      TalkerData(
        'a detailed message',
        title: 'boot',
        logLevel: LogLevel.error,
        time: DateTime(2026, 1, 2, 3, 4, 5),
        stackTrace: Trace.parse('#0      main (package:app/main.dart:1:1)'),
      ),
    );

    await tester.pumpWidget(
      _host(SizedBox(height: 400, child: RecentLogsCard(storage: storage))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Recent logs'), findsOneWidget);
    expect(find.text('03:04:05.000'), findsOneWidget);
    // Collapsed rows only show the timestamp.
    expect(find.text('a detailed message'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('a detailed message'), findsOneWidget);
    expect(find.textContaining('package:app/main.dart'), findsOneWidget);
  });

  testWidgets('LogViewer filters entries by search query', (tester) async {
    await storage.addLog(
      TalkerData(
        'connection refused',
        logLevel: LogLevel.error,
        time: DateTime(2026, 1, 2, 3, 4, 5),
      ),
    );
    await storage.addLog(
      TalkerData(
        'started up',
        logLevel: LogLevel.info,
        time: DateTime(2026, 1, 2, 3, 4, 6),
      ),
    );

    await tester.pumpWidget(_host(LogViewer(storage: storage)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('connection refused'), findsOneWidget);
    expect(find.textContaining('started up'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'connection');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('connection refused'), findsOneWidget);
    expect(find.textContaining('started up'), findsNothing);
  });

  testWidgets('LogToastWrapper only shows toasts at or above the threshold', (
    tester,
  ) async {
    final controller = StreamController<TalkerData>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().withLogLevelColors(),
        home: LogToastWrapper(
          stream: controller.stream,
          minLevel: LogLevel.error,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    controller.add(TalkerData('minor issue', logLevel: LogLevel.info));
    controller.add(TalkerData('big problem', logLevel: LogLevel.error));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('big problem'), findsOneWidget);
    expect(find.text('minor issue'), findsNothing);

    // Let the toast auto-dismiss so no timers are left pending.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('RecentLogsCard honours its builder hooks', (tester) async {
    await storage.addLog(
      TalkerData('custom entry', time: DateTime(2026, 1, 2, 3, 4, 5)),
    );

    await tester.pumpWidget(
      _host(
        RecentLogsCard(
          storage: storage,
          cardBuilder: (context, child, logs) =>
              Container(key: const Key('custom-card'), child: child),
          headerBuilder: (context, count, onClear) => Text('header:$count'),
          tileBuilder: (context, log, expanded, onToggle) =>
              Text('tile:${log.message}'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('custom-card')), findsOneWidget);
    expect(find.text('header:1'), findsOneWidget);
    expect(find.text('tile:custom entry'), findsOneWidget);
  });

  testWidgets('LogViewer honours its builder hooks', (tester) async {
    await storage.addLog(
      TalkerData('viewer entry', time: DateTime(2026, 1, 2, 3, 4, 5)),
    );

    await tester.pumpWidget(
      _host(
        LogViewer(
          storage: storage,
          toolbarBuilder: (context, toolbar, count) =>
              Column(children: [Text('matches:$count'), toolbar]),
          tileBuilder: (context, log, expanded, onToggle) =>
              Text('row:${log.message}'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('matches:1'), findsOneWidget);
    expect(find.text('row:viewer entry'), findsOneWidget);
  });

  testWidgets('LogToastWrapper honours toastBuilder', (tester) async {
    final controller = StreamController<TalkerData>.broadcast();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().withLogLevelColors(),
        home: LogToastWrapper(
          stream: controller.stream,
          minLevel: LogLevel.error,
          toastBuilder: (context, log, dismiss) => Text('toast:${log.message}'),
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    controller.add(TalkerData('custom toast', logLevel: LogLevel.error));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('toast:custom toast'), findsOneWidget);

    // Let the toast auto-dismiss so no timers are left pending.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
