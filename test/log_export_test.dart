import 'dart:convert';
import 'dart:io';

import 'package:enhanced_logging/enhanced_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_trace/stack_trace.dart';

void main() {
  final logs = <TalkerData>[
    TalkerData(
      'hello, world',
      title: 'greeting',
      logLevel: LogLevel.info,
      time: DateTime.utc(2026, 1, 1, 12, 0, 0),
    ),
    TalkerError(
      StateError('kaboom'),
      message: 'failed',
      stackTrace: Trace.parse('#0      main (package:app/main.dart:1:1)'),
    ),
  ];

  test('encodes a plain text report', () {
    final text = LogExporter.encode(logs);

    expect(text, contains('enhanced_logging export'));
    expect(text, contains('Entries: 2'));
    expect(text, contains('hello, world'));
    expect(text, contains('StackTrace:'));
    expect(text, contains('package:app/main.dart'));
  });

  test('encodes JSON', () {
    final encoded = LogExporter.encode(logs, format: LogExportFormat.json);
    final decoded = jsonDecode(encoded) as List<dynamic>;

    expect(decoded, hasLength(2));
    expect((decoded.first as Map)['message'], 'hello, world');
    expect((decoded.last as Map)['error'], contains('kaboom'));
  });

  test('can omit stack traces', () {
    final encoded = LogExporter.encode(
      logs,
      format: LogExportFormat.json,
      includeStackTraces: false,
    );
    expect(encoded, isNot(contains('stackTrace')));
  });

  test('encodes CSV with escaping', () {
    final csv = LogExporter.encode(logs, format: LogExportFormat.csv);
    final header = csv.trim().split('\n').first;

    expect(header, startsWith('time,level,key,title,message,error,exception'));
    expect(csv, contains('"hello, world"'));
  });

  test('builds a timestamped file name', () {
    final name = LogExporter.suggestedFileName(
      format: LogExportFormat.csv,
      now: DateTime(2026, 1, 2, 3, 4, 5),
    );
    expect(name, 'enhanced_logging-20260102-030405.csv');
  });

  test('save writes a file on the VM', () async {
    final directory = await Directory.systemTemp.createTemp('log_export_test');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final result = await LogExporter.save(
      logs,
      directoryPath: directory.path,
      fileName: 'out.json',
      format: LogExportFormat.json,
    );

    expect(result.path, isNotNull);
    final file = File(result.path!);
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('hello, world'));
  });
}
