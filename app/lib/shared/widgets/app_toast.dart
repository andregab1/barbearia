import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppToastType { success, warning, error, info }

class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    AppToastType type = AppToastType.success,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastEntry(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastEntry extends StatefulWidget {
  final String message;
  final AppToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastEntry({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (widget.type) {
      AppToastType.success => (AppTheme.corSucesso, Icons.check_circle_outline),
      AppToastType.warning => (Colors.orange, Icons.warning_amber_rounded),
      AppToastType.error => (AppTheme.corErro, Icons.error_outline_rounded),
      AppToastType.info => (Colors.blueGrey, Icons.info_outline_rounded),
    };
    final width = MediaQuery.sizeOf(context).width;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 18,
      right: width < 520 ? 12 : 22,
      left: width < 520 ? 12 : null,
      child: SafeArea(
        child: SlideTransition(
          position: Tween(begin: const Offset(.2, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
          child: FadeTransition(
            opacity: _controller,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width < 520 ? null : 360,
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElev,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: .55)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black45,
                        blurRadius: 24,
                        offset: Offset(0, 10))
                  ],
                ),
                child: Row(children: [
                  Icon(icon, color: color, size: 21),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(widget.message,
                          style: TextStyle(
                              color: AppTheme.corTexto,
                              fontSize: 13,
                              height: 1.35))),
                  IconButton(
                    tooltip: 'Fechar aviso',
                    onPressed: _dismiss,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppTheme.corTextoSecundario,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
