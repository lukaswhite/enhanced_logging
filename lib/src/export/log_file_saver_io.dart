import 'dart:io';

import 'log_export_result.dart';

/// Writes [contents] to a file on the local file system.
///
/// The file is written to [directoryPath] when provided, otherwise to a
/// dedicated folder inside the system temporary directory.
Future<LogExportResult> saveLogFile(
  String fileName,
  String contents, {
  String mimeType = 'text/plain',
  String? directoryPath,
}) async {
  final directory = directoryPath != null
      ? Directory(directoryPath)
      : Directory(
          '${Directory.systemTemp.path}'
          '${Platform.pathSeparator}enhanced_logging_exports',
        );

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents, flush: true);

  return LogExportResult(
    fileName: fileName,
    path: file.path,
    bytes: await file.length(),
  );
}
