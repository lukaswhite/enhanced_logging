/// Persistent, live, UI-ready logging for Flutter, built on top of
/// [`talker`](https://pub.dev/packages/talker) and
/// [`hive`](https://pub.dev/packages/hive).
library;

export 'package:talker/talker.dart'
    show
        LogLevel,
        Talker,
        TalkerData,
        TalkerError,
        TalkerException,
        TalkerKey,
        TalkerLog,
        TalkerObserver,
        logLevelPriorityList;

export 'src/export/log_export.dart';
export 'src/export/log_export_result.dart';
export 'src/extensions/talker_data_extension.dart';
export 'src/helpers/log_storage_observer.dart';
export 'src/helpers/logger_observer.dart';
export 'src/storage/adapters/talker_data_adapter.dart';
export 'src/storage/log_storage.dart';
export 'src/theme/log_level_colors.dart';
export 'src/utils/log_format.dart';
export 'src/widgets/log_entry_tile.dart';
export 'src/widgets/log_toast_wrapper.dart';
export 'src/widgets/log_viewer.dart';
export 'src/widgets/recent_logs_card.dart';
