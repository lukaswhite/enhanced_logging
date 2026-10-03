/// Platform specific file writer used by the log exporter.
///
/// On the web the export is delivered as a browser download, everywhere else it
/// is written to the local file system.
library;

export 'log_file_saver_io.dart'
    if (dart.library.js_interop) 'log_file_saver_web.dart';
