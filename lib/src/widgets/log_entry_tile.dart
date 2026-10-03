import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../theme/log_level_colors.dart';
import '../utils/log_format.dart';

/// Builds the collapsed row of a [LogEntryTile].
///
/// [onToggle] flips the expansion state, which is owned by the parent.
typedef LogCollapsedBuilder = Widget Function(
  BuildContext context,
  TalkerData log,
  VoidCallback onToggle,
);

/// Builds the expanded details panel of a [LogEntryTile].
typedef LogDetailsBuilder = Widget Function(
  BuildContext context,
  TalkerData log,
);

/// Builds a single log row inside a list of entries, as used by
/// `RecentLogsCard` and `LogViewer`.
///
/// [expanded] reflects the current expansion state and [onToggle] flips it.
typedef LogEntryTileBuilder = Widget Function(
  BuildContext context,
  TalkerData log,
  bool expanded,
  VoidCallback onToggle,
);

/// A single, expandable log row.
///
/// Collapsed it shows the entry's timestamp and level; expanding reveals the
/// message, key, error / exception and (optionally) the stack trace. The
/// expansion state is owned by the parent so it survives live list rebuilds.
class LogEntryTile extends StatelessWidget {
  /// Creates a log entry tile.
  const LogEntryTile({
    super.key,
    required this.log,
    required this.expanded,
    required this.onToggle,
    this.compact = false,
    this.showCopyButton = true,
    this.maxStackTraceHeight = 220,
    this.collapsedBuilder,
    this.detailsBuilder,
  });

  /// The entry to display.
  final TalkerData log;

  /// Whether the details panel is visible.
  final bool expanded;

  /// Called when the row (or the expand button) is tapped.
  final VoidCallback onToggle;

  /// When `true`, only the timestamp and level are shown while collapsed.
  final bool compact;

  /// Whether the details panel exposes a "Copy" action.
  final bool showCopyButton;

  /// The maximum height of the scrollable stack trace block.
  final double maxStackTraceHeight;

  /// When provided, replaces the default collapsed row entirely.
  final LogCollapsedBuilder? collapsedBuilder;

  /// When provided, replaces the default expanded details panel.
  final LogDetailsBuilder? detailsBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.logLevelColors;
    final level = log.logLevel ?? LogLevel.info;
    final color = colors.of(level);
    final customRow = collapsedBuilder?.call(context, log, onToggle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child:
              customRow ??
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LevelBadge(color: color, icon: colors.iconOf(level)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                formatLogTime(log.time),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatRelativeTime(log.time),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 2),
                            Text(
                              log.summary,
                              maxLines: expanded ? null : 1,
                              overflow: expanded ? null : TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (log.hasStackTrace)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.layers_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    IconButton(
                      tooltip: expanded ? 'Collapse' : 'Expand',
                      onPressed: onToggle,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
              ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? detailsBuilder?.call(context, log) ??
                      _LogDetails(
                        log: log,
                        color: color,
                        maxStackTraceHeight: maxStackTraceHeight,
                        showCopyButton: showCopyButton,
                      )
                : const SizedBox(width: double.infinity),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _LogDetails extends StatelessWidget {
  const _LogDetails({
    required this.log,
    required this.color,
    required this.maxStackTraceHeight,
    required this.showCopyButton,
  });

  final TalkerData log;
  final Color color;
  final double maxStackTraceHeight;
  final bool showCopyButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.logLevelColors;
    final level = log.logLevel ?? LogLevel.info;
    final stackTrace = log.stackTraceString;
    final message = log.message?.trim();
    final error = log.errorMessage;
    final exception = log.exceptionMessage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.tintOf(level),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MetaChip(label: 'level: ${level.name}', color: color),
                if (log.title != null && log.title!.isNotEmpty)
                  _MetaChip(label: 'title: ${log.title}', color: color),
                _MetaChip(label: 'key: ${log.effectiveKey}', color: color),
                _MetaChip(label: formatLogDateTime(log.time), color: color),
              ],
            ),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(message, style: theme.textTheme.bodyMedium),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _DetailBlock(title: 'Error', body: error, color: color),
            ],
            if (exception != null) ...[
              const SizedBox(height: 10),
              _DetailBlock(title: 'Exception', body: exception, color: color),
            ],
            if (stackTrace != null && stackTrace.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailBlock(
                title: 'Stack trace',
                body: stackTrace,
                color: color,
                monospace: true,
                maxHeight: maxStackTraceHeight,
              ),
            ],
            if (showCopyButton)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  label: const Text('Copy'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: formatLogEntry(log)));
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Log entry copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.body,
    required this.color,
    this.monospace = false,
    this.maxHeight,
  });

  final String title;
  final String body;
  final Color color;
  final bool monospace;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = monospace
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    final content = SelectableText(
      body,
      style: baseStyle?.copyWith(fontFamily: monospace ? 'monospace' : null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        if (maxHeight == null)
          content
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight!),
            child: SingleChildScrollView(child: content),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
