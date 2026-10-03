import 'dart:async';

import 'package:flutter/material.dart';
import 'package:talker/talker.dart';

import '../extensions/talker_data_extension.dart';
import '../storage/log_storage.dart';
import '../theme/log_level_colors.dart';
import '../utils/log_format.dart';

/// Where [LogToastWrapper] anchors its toasts.
enum LogToastPosition {
  /// Top left corner.
  topLeft,

  /// Top centre.
  topCenter,

  /// Top right corner.
  topRight,

  /// Bottom left corner.
  bottomLeft,

  /// Bottom centre.
  bottomCenter,

  /// Bottom right corner.
  bottomRight,
}

/// Builds the visual surface of a single toast.
///
/// [dismiss] removes the toast immediately; the wrapper still animates it.
typedef LogToastBuilder = Widget Function(
  BuildContext context,
  TalkerData log,
  VoidCallback dismiss,
);

/// Wraps an app (or a subtree) and shows a toast for every log entry at or
/// above [minLevel].
///
/// Provide either a [storage] (the wrapper listens to newly added Hive entries)
/// or a custom [stream] (for example `loggerObserver.logStream`).
///
/// ```dart
/// LogToastWrapper(
///   storage: storage,
///   minLevel: LogLevel.error,
///   child: MaterialApp(...),
/// )
/// ```
class LogToastWrapper extends StatefulWidget {
  /// Creates a log toast wrapper.
  const LogToastWrapper({
    super.key,
    required this.child,
    this.storage,
    this.stream,
    this.minLevel = LogLevel.error,
    this.duration = const Duration(seconds: 5),
    this.maxVisible = 3,
    this.position = LogToastPosition.topCenter,
    this.maxWidth = 420,
    this.enabled = true,
    this.onToastTap,
    this.toastBuilder,
  }) : assert(
         storage != null || stream != null,
         'Provide either a storage or a stream.',
       );

  /// The wrapped subtree.
  final Widget child;

  /// The store to observe for new entries.
  final LogStorage? storage;

  /// Alternatively, an arbitrary stream of log entries.
  final Stream<TalkerData>? stream;

  /// The minimum severity required to show a toast.
  final LogLevel minLevel;

  /// How long each toast stays on screen.
  final Duration duration;

  /// The maximum number of toasts visible at once.
  final int maxVisible;

  /// Where the toasts are anchored.
  final LogToastPosition position;

  /// The maximum width of a single toast.
  final double maxWidth;

  /// When `false`, incoming entries are ignored.
  final bool enabled;

  /// Called when a toast is tapped (before it is dismissed).
  final ValueChanged<TalkerData>? onToastTap;

  /// When provided, replaces the default toast surface entirely. The wrapper
  /// still handles positioning, animation and auto-dismissal.
  final LogToastBuilder? toastBuilder;

  @override
  State<LogToastWrapper> createState() => _LogToastWrapperState();
}

class _LogToastWrapperState extends State<LogToastWrapper> {
  final List<_ActiveToast> _toasts = <_ActiveToast>[];
  StreamSubscription<TalkerData>? _subscription;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _resubscribe();
  }

  @override
  void didUpdateWidget(covariant LogToastWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage ||
        oldWidget.stream != widget.stream) {
      _resubscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _resubscribe() {
    _subscription?.cancel();
    final source = widget.stream ?? widget.storage!.newLogs;
    _subscription = source.listen(_onLog);
  }

  void _onLog(TalkerData log) {
    if (!mounted || !widget.enabled) return;
    if (!meetsLogLevelThreshold(
      log.logLevel ?? LogLevel.info,
      widget.minLevel,
    )) {
      return;
    }

    setState(() {
      _toasts.add(_ActiveToast(_nextId++, log));
      if (_toasts.length > widget.maxVisible) {
        _toasts.removeRange(0, _toasts.length - widget.maxVisible);
      }
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((toast) => toast.id == id));
  }

  Alignment get _alignment {
    switch (widget.position) {
      case LogToastPosition.topLeft:
        return Alignment.topLeft;
      case LogToastPosition.topCenter:
        return Alignment.topCenter;
      case LogToastPosition.topRight:
        return Alignment.topRight;
      case LogToastPosition.bottomLeft:
        return Alignment.bottomLeft;
      case LogToastPosition.bottomCenter:
        return Alignment.bottomCenter;
      case LogToastPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }

  bool get _isTop =>
      widget.position == LogToastPosition.topLeft ||
      widget.position == LogToastPosition.topCenter ||
      widget.position == LogToastPosition.topRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: _isTop ? 0 : null,
          bottom: _isTop ? null : 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Align(
              alignment: _alignment,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final toast in _toasts)
                      _LogToast(
                        key: ValueKey<int>(toast.id),
                        log: toast.log,
                        duration: widget.duration,
                        slideFromY: _isTop ? -0.3 : 0.3,
                        onDismiss: () => _remove(toast.id),
                        onTap: widget.onToastTap,
                        builder: widget.toastBuilder,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveToast {
  _ActiveToast(this.id, this.log);

  final int id;
  final TalkerData log;
}

class _LogToast extends StatefulWidget {
  const _LogToast({
    super.key,
    required this.log,
    required this.duration,
    required this.slideFromY,
    required this.onDismiss,
    this.onTap,
    this.builder,
  });

  final TalkerData log;
  final Duration duration;
  final double slideFromY;
  final VoidCallback onDismiss;
  final ValueChanged<TalkerData>? onTap;
  final LogToastBuilder? builder;

  @override
  State<_LogToast> createState() => _LogToastState();
}

class _LogToastState extends State<_LogToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDismiss();
  }

  void _handleTap() {
    widget.onTap?.call(widget.log);
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.logLevelColors;
    final level = widget.log.logLevel ?? LogLevel.info;
    final color = colors.of(level);
    final title = widget.log.title?.trim();

    return SlideTransition(
      position:
          Tween<Offset>(
            begin: Offset(0, widget.slideFromY),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          ),
      child: FadeTransition(
        opacity: _controller,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child:
              widget.builder?.call(context, widget.log, _dismiss) ??
              Material(
                elevation: 6,
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _handleTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(colors.iconOf(level), color: color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title == null || title.isEmpty
                                          ? widget.log.effectiveKey
                                          : title,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(color: color),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatLogTime(widget.log.time),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.log.summary,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (widget.log.hasStackTrace)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Stack trace available',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Dismiss',
                          visualDensity: VisualDensity.compact,
                          onPressed: _dismiss,
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
