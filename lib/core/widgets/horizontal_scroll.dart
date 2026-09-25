import 'package:flutter/material.dart';

/// Horizontal scroll container with a *working*, always-visible scrollbar.
///
/// Why this exists: a bare `Scrollbar` without an explicit controller
/// attaches to the primary scroll controller, which is never connected to a
/// horizontal view — so no thumb appears. On desktop (mouse) that leaves
/// horizontal scrolling impossible: there is no touch-drag and the wheel
/// scrolls vertically. This widget wires one explicit [ScrollController] to
/// both the scroll view and its scrollbar, keeps the thumb visible, and
/// filters notifications by axis so nested scrollbars never fight.
class HorizontalScroll extends StatefulWidget {
  const HorizontalScroll({super.key, required this.child, this.controller});

  final Widget child;

  /// Optional external controller (useful in tests). When omitted, the
  /// widget owns and disposes its own controller.
  final ScrollController? controller;

  @override
  State<HorizontalScroll> createState() => _HorizontalScrollState();
}

class _HorizontalScrollState extends State<HorizontalScroll> {
  ScrollController? _owned;

  ScrollController get _effective =>
      widget.controller ?? (_owned ??= ScrollController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effective;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
