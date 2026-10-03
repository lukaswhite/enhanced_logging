import 'package:flutter/material.dart';
import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../storage/log_storage.dart';
import 'log_entry_tile.dart';

/// A compact, live dashboard card showing the most recent log entries.
///
/// Each collapsed row shows **only** the entry's timestamp (plus a level
/// badge). Tap the row or the expand button to reveal the remaining data, such
/// as the message and stack trace.
///
/// The card subscribes to the [LogStorage] Hive change stream, so it updates
/// automatically as new entries are written.
class RecentLogsCard extends StatefulWidget {
  /// Creates a recent logs card.
  const RecentLogsCard({
    super.key,
    required this.storage,
    this.title = 'Recent logs',
    this.maxEntries = 8,
    this.minLevel = LogLevel.verbose,
    this.levels,
    this.emptyMessage = 'No logs yet',
    this.showClearButton = true,
    this.onEntryTap,
    this.margin = const EdgeInsets.all(8),
    this.borderRadius = 12,
    this.cardBuilder,
    this.headerBuilder,
    this.tileBuilder,
    this.emptyBuilder,
    this.errorBuilder,
  });

  /// The source store.
  final LogStorage storage;

  /// The card header title.
  final String title;

  /// The maximum number of entries to display.
  final int maxEntries;

  /// The minimum severity to display.
  final LogLevel minLevel;

  /// When non-empty, only entries whose level is in the set are displayed.
  final Set<LogLevel>? levels;

  /// Message shown when there is nothing to display.
  final String emptyMessage;

  /// Whether to show the "clear" action in the header.
  final bool showClearButton;

  /// Optional callback invoked when an entry row is tapped.
  final ValueChanged<TalkerData>? onEntryTap;

  /// Outer margin of the card.
  final EdgeInsetsGeometry margin;

  /// Corner radius of the card.
  final double borderRadius;

  /// Wraps (or replaces) the default [Card] surface. The default card is
  /// passed in as [child] so it can be decorated or swapped out entirely.
  final Widget Function(
    BuildContext context,
    Widget child,
    List<TalkerData> logs,
  )?
  cardBuilder;

  /// Builds the card header. [onClear] is `null` when there is nothing to
  /// clear.
  final Widget Function(BuildContext context, int count, VoidCallback? onClear)?
  headerBuilder;

  /// When provided, builds each entry row instead of the default tile.
  final LogEntryTileBuilder? tileBuilder;

  /// When provided, builds the empty state.
  final Widget Function(BuildContext context, String message)? emptyBuilder;

  /// When provided, builds the error state.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  @override
  State<RecentLogsCard> createState() => _RecentLogsCardState();
}

class _RecentLogsCardState extends State<RecentLogsCard> {
  final Set<TalkerData> _expanded = <TalkerData>{};
  late Stream<List<TalkerData>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant RecentLogsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage ||
        oldWidget.maxEntries != widget.maxEntries ||
        oldWidget.minLevel != widget.minLevel ||
        oldWidget.levels != widget.levels) {
      _stream = _buildStream();
    }
  }

  Stream<List<TalkerData>> _buildStream() {
    final levels = widget.levels;
    return widget.storage.watchLogs(newestFirst: true).map((logs) {
      return logs
          .where((log) {
            if (levels != null &&
                levels.isNotEmpty &&
                !levels.contains(log.logLevel)) {
              return false;
            }
            return meetsLogLevelThreshold(
              log.logLevel ?? LogLevel.info,
              widget.minLevel,
            );
          })
          .take(widget.maxEntries)
          .toList();
    });
  }

  void _toggle(TalkerData log) {
    setState(() {
      if (!_expanded.remove(log)) _expanded.add(log);
    });
    widget.onEntryTap?.call(log);
  }

  Future<void> _clear() async {
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
      if (mounted) setState(_expanded.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<TalkerData>>(
      stream: _stream,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? const <TalkerData>[];

        final card = Card(
          margin: widget.margin,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.headerBuilder?.call(
                    context,
                    logs.length,
                    logs.isEmpty ? null : _clear,
                  ) ??
                  _buildHeader(context, theme, logs.length),
              const Divider(height: 1),
              if (snapshot.hasError)
                widget.errorBuilder?.call(context, snapshot.error!) ??
                    _buildMessage(
                      theme,
                      'Failed to read logs: ${snapshot.error}',
                    )
              else if (logs.isEmpty)
                widget.emptyBuilder?.call(context, widget.emptyMessage) ??
                    _buildMessage(theme, widget.emptyMessage)
              else
                for (final log in logs)
                  widget.tileBuilder?.call(
                        context,
                        log,
                        _expanded.contains(log),
                        () => _toggle(log),
                      ) ??
                      LogEntryTile(
                        key: ObjectKey(log),
                        log: log,
                        compact: true,
                        expanded: _expanded.contains(log),
                        onToggle: () => _toggle(log),
                      ),
            ],
          ),
        );

        return widget.cardBuilder?.call(context, card, logs) ?? card;
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.showClearButton)
            IconButton(
              tooltip: 'Clear logs',
              onPressed: count == 0 ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(ThemeData theme, String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
