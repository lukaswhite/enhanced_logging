import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';

/// Formats [time] as `HH:mm:ss.SSS`.
String formatLogTime(DateTime time) {
  return '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}'
      '.${time.millisecond.toString().padLeft(3, '0')}';
}

/// Formats [time] as `yyyy-MM-dd HH:mm:ss.SSS`.
String formatLogDateTime(DateTime time) {
  return '${time.year.toString().padLeft(4, '0')}-${_two(time.month)}-'
      '${_two(time.day)} ${formatLogTime(time)}';
}

/// A coarse, human friendly description of [time] relative to [now]
/// (defaults to [DateTime.now]).
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative) return 'in ${_humanise(-diff)}';
  if (diff.inSeconds < 5) return 'just now';
  return '${_humanise(diff)} ago';
}

/// Builds a human readable, multi-line text block for a single [log].
///
/// Used when copying an entry to the clipboard and by the text exporter.
String formatLogEntry(TalkerData log, {bool includeStackTrace = true}) {
  final buffer = StringBuffer()
    ..writeln('[${formatLogDateTime(log.time)}] [${log.effectiveKey}]');

  if (log.title != null && log.title!.isNotEmpty) {
    buffer.writeln('Title: ${log.title}');
  }
  if (log.logLevel != null) {
    buffer.writeln('Level: ${log.logLevel!.name}');
  }
  if (log.message != null && log.message!.isNotEmpty) {
    buffer.writeln('Message: ${log.message}');
  }
  final error = log.errorMessage;
  if (error != null) buffer.writeln('Error: $error');
  final exception = log.exceptionMessage;
  if (exception != null) buffer.writeln('Exception: $exception');
  if (includeStackTrace && log.hasStackTrace) {
    buffer
      ..writeln('StackTrace:')
      ..writeln(log.stackTraceString);
  }
  return buffer.toString().trimRight();
}

String _humanise(Duration duration) {
  if (duration.inDays >= 365) return '${duration.inDays ~/ 365}y';
  if (duration.inDays >= 1) return '${duration.inDays}d';
  if (duration.inHours >= 1) return '${duration.inHours}h';
  if (duration.inMinutes >= 1) return '${duration.inMinutes}m';
  if (duration.inSeconds >= 1) return '${duration.inSeconds}s';
  return '${duration.inMilliseconds}ms';
}

String _two(int value) => value.toString().padLeft(2, '0');
