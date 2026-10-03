import 'dart:convert';

import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../utils/log_format.dart';
import 'log_export_result.dart';
import 'log_file_saver.dart';

/// The encodings supported when exporting logs.
enum LogExportFormat {
  /// Plain, human readable text.
  text,

  /// Pretty printed JSON, one object per entry.
  json,

  /// Comma separated values, one entry per row.
  csv;

  /// The file extension (without the leading dot) for this format.
  String get extension {
    switch (this) {
      case LogExportFormat.text:
        return 'txt';
      case LogExportFormat.json:
        return 'json';
      case LogExportFormat.csv:
        return 'csv';
    }
  }

  /// The MIME type used when handing the file to the browser.
  String get mimeType {
    switch (this) {
      case LogExportFormat.text:
        return 'text/plain';
      case LogExportFormat.json:
        return 'application/json';
      case LogExportFormat.csv:
        return 'text/csv';
    }
  }
}

/// Builds log exports and persists them to a file or browser download.
///
/// ```dart
/// final result = await LogExporter.save(
///   storage.reversedLogs,
///   format: LogExportFormat.json,
/// );
/// ```
class LogExporter {
  const LogExporter._();

  /// Encodes [logs] using [format].
  static String encode(
    List<TalkerData> logs, {
    LogExportFormat format = LogExportFormat.text,
    bool includeStackTraces = true,
  }) {
    switch (format) {
      case LogExportFormat.text:
        return encodeText(logs, includeStackTraces: includeStackTraces);
      case LogExportFormat.json:
        return encodeJson(logs, includeStackTraces: includeStackTraces);
      case LogExportFormat.csv:
        return encodeCsv(logs, includeStackTraces: includeStackTraces);
    }
  }

  /// Encodes [logs] as a plain text report.
  static String encodeText(
    List<TalkerData> logs, {
    bool includeStackTraces = true,
  }) {
    const divider =
        '--------------------------------------------------'
        '----------';
    final buffer = StringBuffer()
      ..writeln('enhanced_logging export')
      ..writeln('Generated: ${formatLogDateTime(DateTime.now())}')
      ..writeln('Entries: ${logs.length}')
      ..writeln(divider);

    for (final log in logs) {
      buffer
        ..writeln()
        ..writeln(formatLogEntry(log, includeStackTrace: includeStackTraces))
        ..writeln(divider);
    }
    return buffer.toString();
  }

  /// Encodes [logs] as an indented JSON array.
  static String encodeJson(
    List<TalkerData> logs, {
    bool includeStackTraces = true,
  }) {
    final entries = logs.map((log) {
      final json = log.toJson();
      if (!includeStackTraces) json.remove('stackTrace');
      return json;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(entries);
  }

  /// Encodes [logs] as CSV.
  static String encodeCsv(
    List<TalkerData> logs, {
    bool includeStackTraces = true,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        <String>[
          'time',
          'level',
          'key',
          'title',
          'message',
          'error',
          'exception',
          if (includeStackTraces) 'stackTrace',
        ].map(_escapeCsv).join(','),
      );

    for (final log in logs) {
      buffer.writeln(
        <String>[
          formatLogDateTime(log.time),
          log.logLevel?.name ?? '',
          log.effectiveKey,
          log.title ?? '',
          log.message ?? '',
          log.errorMessage ?? '',
          log.exceptionMessage ?? '',
          if (includeStackTraces) log.stackTraceString ?? '',
        ].map(_escapeCsv).join(','),
      );
    }
    return buffer.toString();
  }

  /// Builds a timestamped file name for an export.
  static String suggestedFileName({
    LogExportFormat format = LogExportFormat.text,
    DateTime? now,
    String prefix = 'enhanced_logging',
  }) {
    final stamp = now ?? DateTime.now();
    final timestamp =
        '${stamp.year.toString().padLeft(4, '0')}'
        '${_two(stamp.month)}${_two(stamp.day)}-'
        '${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}';
    return '$prefix-$timestamp.${format.extension}';
  }

  /// Encodes [logs] and writes the result to a file.
  ///
  /// On the web this triggers a browser download; elsewhere the file is written
  /// to [directoryPath] or the system temporary directory.
  static Future<LogExportResult> save(
    List<TalkerData> logs, {
    LogExportFormat format = LogExportFormat.text,
    String? fileName,
    bool includeStackTraces = true,
    String? directoryPath,
  }) {
    final contents = encode(
      logs,
      format: format,
      includeStackTraces: includeStackTraces,
    );
    return saveLogFile(
      fileName ?? suggestedFileName(format: format),
      contents,
      mimeType: format.mimeType,
      directoryPath: directoryPath,
    );
  }

  static String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
