import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTitleBar extends StatelessWidget {
  final Widget? title;
  final Color? backgroundColor;
  final double height;

  const DesktopTitleBar({
    super.key,
    this.title,
    this.backgroundColor,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      color: backgroundColor ?? Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                height: height,
                color: Colors.transparent,
                padding: const EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: title ?? const SizedBox.shrink(),
              ),
            ),
          ),
          DesktopWindowControls(height: height),
        ],
      ),
    );
  }
}

class DesktopWindowControls extends StatefulWidget {
  final Color? iconColor;
  final double height;

  const DesktopWindowControls({
    super.key,
    this.iconColor,
    this.height = 32,
  });

  @override
  State<DesktopWindowControls> createState() => _DesktopWindowControlsState();
}

class _DesktopWindowControlsState extends State<DesktopWindowControls>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  Future<void> _checkMaximized() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = max);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const SizedBox.shrink();
    }

    final color = widget.iconColor ?? Colors.white.withValues(alpha: 0.8);

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimize
          _WindowButton(
            icon: Icons.horizontal_rule_rounded,
            iconSize: 14,
            color: color,
            onPressed: () => windowManager.minimize(),
            tooltip: 'Minimize',
          ),
          // Maximize / Restore
          _WindowButton(
            icon: _isMaximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            iconSize: _isMaximized ? 12 : 14,
            color: color,
            onPressed: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
              _checkMaximized();
            },
            tooltip: _isMaximized ? 'Restore' : 'Maximize',
          ),
          // Close
          _WindowButton(
            icon: Icons.close_rounded,
            iconSize: 15,
            color: color,
            isClose: true,
            onPressed: () => windowManager.close(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final bool isClose;
  final VoidCallback onPressed;
  final String tooltip;

  const _WindowButton({
    required this.icon,
    this.iconSize = 14,
    required this.color,
    this.isClose = false,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color iconColor = widget.color;

    if (_isHovered) {
      if (widget.isClose) {
        bg = const Color(0xFFE81123);
        iconColor = Colors.white;
      } else {
        bg = Colors.white.withValues(alpha: 0.12);
        iconColor = Colors.white;
      }
    }

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 44,
            height: double.infinity,
            color: bg,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
