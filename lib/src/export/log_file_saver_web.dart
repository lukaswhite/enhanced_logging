import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'log_export_result.dart';

/// Triggers a browser download of [contents] using a temporary object URL.
Future<LogExportResult> saveLogFile(
  String fileName,
  String contents, {
  String mimeType = 'text/plain',
  String? directoryPath,
}) async {
  final blob = web.Blob(
    <web.BlobPart>[contents.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;

  anchor.click();
  web.URL.revokeObjectURL(url);

  return LogExportResult(fileName: fileName, bytes: contents.length);
}
