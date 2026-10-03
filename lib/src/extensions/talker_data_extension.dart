import 'dart:convert';

import 'package:stack_trace/stack_trace.dart';
import 'package:talker/talker.dart';

/// Placeholder [Error] used to rehydrate an error that was flattened to text
/// when it was serialised by [TalkerDataExtension.toJson].
///
/// The original [Error] instance cannot be reconstructed from JSON, so the
/// human readable [message] (the result of `error.toString()`) is preserved
/// instead.
class SerializedError extends Error {
  /// Creates a serialised error placeholder.
  SerializedError(this.message, {this.type});

  /// The `toString()` representation of the original error.
  final String message;

  /// The runtime type of the original error, when available.
  final String? type;

  @override
  String toString() => message;
}

/// Placeholder [Exception] used to rehydrate an exception that was flattened
/// to text when it was serialised by [TalkerDataExtension.toJson].
///
/// The original [Exception] instance cannot be reconstructed from JSON, so the
/// human readable [message] (the result of `exception.toString()`) is preserved
/// instead.
class SerializedException implements Exception {
  /// Creates a serialised exception placeholder.
  SerializedException(this.message, {this.type});

  /// The `toString()` representation of the original exception.
  final String message;

  /// The runtime type of the original exception, when available.
  final String? type;

  @override
  String toString() => message;
}

/// Convenience accessors and JSON (de)serialisation for [TalkerData].
extension TalkerDataExtension on TalkerData {
  /// The [stackTrace] parsed into a [Trace] from the `stack_trace` package.
  ///
  /// Returns `null` when no stack trace is attached. If a [Trace] is already
  /// attached it is returned as-is.
  Trace? get trace {
    final raw = stackTrace;
    if (raw == null) return null;
    if (raw is Trace) return raw;
    return Trace.from(raw);
  }

  /// The [stackTrace] rendered as a string using the `stack_trace` package.
  ///
  /// This is the representation stored on disk so it can be parsed again with
  /// [Trace.parse].
  String? get stackTraceString {
    final raw = stackTrace;
    if (raw == null) return null;
    if (raw is Trace) return raw.toString();
    return Trace.from(raw).toString();
  }

  /// Whether this entry carries a stack trace.
  bool get hasStackTrace =>
      stackTrace != null && stackTrace != StackTrace.empty;

  /// `true` when this entry represents an [Error].
  bool get isError => error != null;

  /// `true` when this entry represents an [Exception].
  bool get isException => exception != null;

  /// `toString()` of the attached [error], if any.
  String? get errorMessage => error?.toString();

  /// `toString()` of the attached [exception], if any.
  String? get exceptionMessage => exception?.toString();

  /// A stable, human readable key for this entry.
  ///
  /// Falls back to [TalkerKey.fromLogLevel] when no explicit key was provided.
  String get effectiveKey =>
      key ??
      (logLevel != null ? TalkerKey.fromLogLevel(logLevel!) : TalkerKey.debug);

  /// A short single-line summary suitable for dense list rows.
  String get summary {
    final text = message?.trim();
    if (text == null || text.isEmpty) {
      return title?.trim().isNotEmpty == true ? title!.trim() : effectiveKey;
    }
    return text.split('\n').first;
  }

  /// Lower-cased haystack used for case-insensitive full-text search.
  String get searchableText => <String>[
    title ?? '',
    message ?? '',
    key ?? '',
    logLevel?.name ?? '',
    errorMessage ?? '',
    exceptionMessage ?? '',
    stackTraceString ?? '',
  ].join('\n').toLowerCase();

  /// Serialises this entry to a JSON-compatible map.
  ///
  /// Stack traces are stored as a `stack_trace` `Trace` string so they can be
  /// parsed back losslessly. Errors and exceptions are stored as their textual
  /// representation together with their runtime type.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'time': time.toIso8601String()};

    if (title != null) json['title'] = title;
    if (message != null) json['message'] = message;
    if (logLevel != null) json['level'] = logLevel!.name;
    if (key != null) json['key'] = key;

    final traceString = stackTraceString;
    if (traceString != null) json['stackTrace'] = traceString;

    final error = this.error;
    if (error != null) {
      json['error'] = error.toString();
      json['errorType'] = error.runtimeType.toString();
    }

    final exception = this.exception;
    if (exception != null) {
      json['exception'] = exception.toString();
      json['exceptionType'] = exception.runtimeType.toString();
    }

    return json;
  }
}

/// Rebuilds a [TalkerData] entry from the map produced by
/// [TalkerDataExtension.toJson].
///
/// Stack traces are parsed back into a `stack_trace` [Trace] (which implements
/// [StackTrace]) and errors / exceptions are rehydrated as [SerializedError]
/// and [SerializedException] placeholders.
TalkerData talkerDataFromJson(Map<String, dynamic> json) {
  final time = json['time'] as String?;

  return TalkerData(
    json['message'] as String?,
    title: json['title'] as String?,
    logLevel: _logLevelFromName(json['level'] as String?),
    time: time == null ? null : DateTime.tryParse(time),
    key: json['key'] as String?,
    stackTrace: _parseStackTrace(json['stackTrace'] as String?),
    exception: _exceptionFromJson(json),
    error: _errorFromJson(json),
  );
}

/// Encodes a list of entries as a JSON array.
String talkerDataListToJson(Iterable<TalkerData> logs, {bool pretty = true}) {
  final encoded = logs.map((log) => log.toJson()).toList();
  return pretty
      ? const JsonEncoder.withIndent('  ').convert(encoded)
      : jsonEncode(encoded);
}

/// Decodes a JSON array produced by [talkerDataListToJson].
List<TalkerData> talkerDataListFromJson(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw const FormatException('Expected a JSON array of log entries');
  }
  return decoded
      .whereType<Map>()
      .map((entry) => talkerDataFromJson(entry.cast<String, dynamic>()))
      .toList();
}

/// Returns `true` when [level] is at least as severe as [threshold].
///
/// Uses [logLevelPriorityList] (most severe first), so an `error` meets an
/// `error` or `debug` threshold, while `verbose` only meets `verbose`.
bool meetsLogLevelThreshold(LogLevel? level, LogLevel threshold) {
  if (level == null) return false;
  final levelIndex = logLevelPriorityList.indexOf(level);
  final thresholdIndex = logLevelPriorityList.indexOf(threshold);
  if (levelIndex < 0 || thresholdIndex < 0) return false;
  return levelIndex <= thresholdIndex;
}

LogLevel? _logLevelFromName(String? name) {
  if (name == null) return null;
  for (final level in LogLevel.values) {
    if (level.name == name) return level;
  }
  return null;
}

StackTrace? _parseStackTrace(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return Trace.parse(raw);
  } catch (_) {
    return StackTrace.fromString(raw);
  }
}

SerializedException? _exceptionFromJson(Map<String, dynamic> json) {
  final message = json['exception'] as String?;
  if (message == null) return null;
  return SerializedException(message, type: json['exceptionType'] as String?);
}

SerializedError? _errorFromJson(Map<String, dynamic> json) {
  final message = json['error'] as String?;
  if (message == null) return null;
  return SerializedError(message, type: json['errorType'] as String?);
}
