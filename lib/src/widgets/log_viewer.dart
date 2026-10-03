import 'dart:async';

import 'package:flutter/material.dart';
import 'package:talker/talker.dart';

import '../export/log_export.dart';
import '../extensions/talker_data_extension.dart';
import '../storage/log_storage.dart';
import '../theme/log_level_colors.dart';
import 'log_entry_tile.dart';

/// A preset time window used by [LogViewer].
enum LogTimeRange {
  /// No time restriction.
  all('All time'),

  /// The last minute.
  lastMinute('Last minute'),

  /// The last five minutes.
  lastFiveMinutes('Last 5 minutes'),

  /// The last hour.
  lastHour('Last hour'),

  /// The last 24 hours.
  lastDay('Last 24 hours');

  const LogTimeRange(this.label);

  /// A human readable label.
  final String label;

  /// The lower bound for this range, or `null` for [LogTimeRange.all].
  DateTime? since([DateTime? now]) {
    final reference = now ?? DateTime.now();
    switch (this) {
      case LogTimeRange.all:
        return null;
      case LogTimeRange.lastMinute:
        return reference.subtract(const Duration(minutes: 1));
      case LogTimeRange.lastFiveMinutes:
        return reference.subtract(const Duration(minutes: 5));
      case LogTimeRange.lastHour:
        return reference.subtract(const Duration(hours: 1));
      case LogTimeRange.lastDay:
        return reference.subtract(const Duration(days: 1));
    }
  }
}

/// A full-page log viewer intended to be used as the `body` of a page.
///
/// Provides live streaming from Hive, full-text search, level and time
/// filtering, sorting, per-entry expansion and export to a file / browser
/// download.
///
/// ```dart
/// Scaffold(appBar: AppBar(title: const Text('Logs')), body: LogViewer(storage: storage));
/// ```
class LogViewer extends StatefulWidget {
  /// Creates a log viewer.
  const LogViewer({
    super.key,
    required this.storage,
    this.initialQuery = '',
    this.initialLevels = const <LogLevel>{},
    this.initialTimeRange = LogTimeRange.all,
    this.newestFirst = true,
    this.live = true,
    this.showExportButton = true,
    this.showClearButton = true,
    this.showLevelFilters = true,
    this.searchHintText = 'Search logs',
    this.emptyMessage = 'No matching log entries',
    this.padding = const EdgeInsets.all(12),
    this.header,
    this.tileBuilder,
    this.emptyBuilder,
    this.toolbarBuilder,
    this.errorBuilder,
  });

  /// The source store.
  final LogStorage storage;

  /// The initial search query.
  final String initialQuery;

  /// The initially selected levels (empty means "all levels").
  final Set<LogLevel> initialLevels;

  /// The initially selected time range.
  final LogTimeRange initialTimeRange;

  /// Whether entries are shown newest first by default.
  final bool newestFirst;

  /// Whether the viewer subscribes to live Hive updates by default.
  final bool live;

  /// Whether to show the export action.
  final bool showExportButton;

  /// Whether to show the clear action.
  final bool showClearButton;

  /// Whether to show the level filter chips.
  final bool showLevelFilters;

  /// The hint text of the search field.
  final String searchHintText;

  /// Message shown when no entries match the active filters.
  final String emptyMessage;

  /// Padding applied around the toolbar.
  final EdgeInsetsGeometry padding;

  /// An optional widget rendered above the toolbar.
  final Widget? header;

  /// When provided, builds each entry row instead of the default tile.
  final LogEntryTileBuilder? tileBuilder;

  /// When provided, builds the empty state.
  final Widget Function(BuildContext context, String message)? emptyBuilder;

  /// When provided, builds the toolbar. The default toolbar is passed in so it
  /// can be wrapped, extended or replaced entirely.
  final Widget Function(BuildContext context, Widget toolbar, int matchCount)?
  toolbarBuilder;

  /// When provided, builds the error state shown if the Hive stream fails.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.initialQuery,
  );
  late final Set<LogLevel> _selectedLevels = {...widget.initialLevels};
  late LogTimeRange _timeRange = widget.initialTimeRange;
  late bool _newestFirst = widget.newestFirst;
  late bool _live = widget.live;

  final Set<TalkerData> _expanded = <TalkerData>{};
  StreamSubscription<List<TalkerData>>? _subscription;
  List<TalkerData> _logs = const <TalkerData>[];
  Object? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    _logs = _sort(widget.storage.reversedLogs);
    _error = null;
    _subscription = widget.storage
        .watchLogs(newestFirst: true)
        .listen(
          (logs) {
            if (!mounted || !_live) return;
            setState(() {
              _error = null;
              _logs = _sort(logs);
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _error = error);
          },
        );
  }

  List<TalkerData> _sort(List<TalkerData> logs) {
    final sorted = [...logs];
    sorted.sort(
      (a, b) =>
          _newestFirst ? b.time.compareTo(a.time) : a.time.compareTo(b.time),
    );
    return sorted;
  }

  List<TalkerData> _filtered() {
    final needle = _searchController.text.trim().toLowerCase();
    final since = _timeRange.since();

    return _logs.where((log) {
      if (_selectedLevels.isNotEmpty &&
          !_selectedLevels.contains(log.logLevel)) {
        return false;
      }
      if (since != null && log.time.isBefore(since)) return false;
      if (needle.isNotEmpty && !log.searchableText.contains(needle)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _toggleLive() {
    setState(() {
      _live = !_live;
      if (_live) _logs = _sort(widget.storage.reversedLogs);
    });
  }

  Future<void> _export(BuildContext context, LogExportFormat format) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _exporting = true);
    try {
      final result = await LogExporter.save(_filtered(), format: format);
      messenger?.showSnackBar(SnackBar(content: Text(result.description)));
    } catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('This permanently deletes every stored log entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await widget.storage.clearLogs();
      if (!mounted) return;
      setState(() {
        _logs = const <TalkerData>[];
        _expanded.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Padding(
          padding: widget.padding,
          child:
              widget.toolbarBuilder?.call(
                context,
                _buildToolbar(context, filtered.length),
                filtered.length,
              ) ??
              _buildToolbar(context, filtered.length),
        ),
        const Divider(height: 1),
        Expanded(
          child: _error != null
              ? widget.errorBuilder?.call(context, _error!) ??
                    _buildError(context, _error!)
              : filtered.isEmpty
              ? widget.emptyBuilder?.call(context, widget.emptyMessage) ??
                    _buildEmpty(context)
              : ListView.builder(
                  key: const PageStorageKey<String>('log_viewer_list'),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    void onToggle() => setState(() {
                      if (!_expanded.remove(log)) _expanded.add(log);
                    });
                    return widget.tileBuilder?.call(
                          context,
                          log,
                          _expanded.contains(log),
                          onToggle,
                        ) ??
                        LogEntryTile(
                          key: ObjectKey(log),
                          log: log,
                          expanded: _expanded.contains(log),
                          onToggle: onToggle,
                        );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, int matchCount) {
    final theme = Theme.of(context);
    final colors = context.logLevelColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.searchHintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_searchController.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (widget.showLevelFilters) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in LogLevel.values)
                FilterChip(
                  label: Text(level.name),
                  selected: _selectedLevels.contains(level),
                  selectedColor: colors.tintOf(level),
                  checkmarkColor: colors.of(level),
                  avatar: _selectedLevels.contains(level)
                      ? null
                      : Icon(
                          colors.iconOf(level),
                          size: 16,
                          color: colors.of(level),
                        ),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedLevels.add(level);
                    } else {
                      _selectedLevels.remove(level);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                '$matchCount of ${_logs.length} entries',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: _live ? 'Pause live updates' : 'Resume live updates',
              onPressed: _toggleLive,
              icon: Icon(
                _live ? Icons.pause_circle_outline : Icons.play_circle_outline,
              ),
            ),
            IconButton(
              tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
              onPressed: () => setState(() {
                _newestFirst = !_newestFirst;
                _logs = _sort(_logs);
              }),
              icon: Icon(
                _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              ),
            ),
            PopupMenuButton<LogTimeRange>(
              tooltip: 'Time range',
              icon: const Icon(Icons.schedule),
              initialValue: _timeRange,
              onSelected: (range) => setState(() => _timeRange = range),
              itemBuilder: (context) => [
                for (final range in LogTimeRange.values)
                  PopupMenuItem(value: range, child: Text(range.label)),
              ],
            ),
            if (widget.showExportButton)
              PopupMenuButton<LogExportFormat>(
                tooltip: 'Export logs',
                icon: const Icon(Icons.download_outlined),
                enabled: !_exporting && matchCount > 0,
                onSelected: (format) => _export(context, format),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: LogExportFormat.text,
                    child: Text('Export as text'),
                  ),
                  PopupMenuItem(
                    value: LogExportFormat.json,
                    child: Text('Export as JSON'),
                  ),
                  PopupMenuItem(
                    value: LogExportFormat.csv,
                    child: Text('Export as CSV'),
                  ),
                ],
              ),
            if (widget.showClearButton)
              IconButton(
                tooltip: 'Clear logs',
                onPressed: _logs.isEmpty ? null : () => _clear(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Failed to read logs: $error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
