/// Describes the outcome of writing a log export.
class LogExportResult {
  /// Creates a log export result.
  const LogExportResult({required this.fileName, this.path, this.bytes});

  /// The name of the exported file.
  final String fileName;

  /// Absolute path of the written file, or `null` when the file was delivered
  /// to the browser as a download (Flutter Web).
  final String? path;

  /// Size of the export in bytes, when known.
  final int? bytes;

  /// Whether the export was delivered as a browser download.
  bool get isDownload => path == null;

  /// A short, human readable description of the result.
  String get description =>
      isDownload ? 'Downloaded $fileName' : 'Saved to $path';

  @override
  String toString() => 'LogExportResult($description)';
}
