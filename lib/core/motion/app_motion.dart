import 'package:flutter/material.dart';

/// Lightweight motion language for the app.
///
/// Principles (Ali: life and motion, never heavy, never gaudy):
/// - Everything is built on [TweenAnimationBuilder]: no controllers to
///   dispose, no tickers to manage, cheap on low-end desktops.
/// - Entrances are fade + short slide only; nothing bounces or rotates.
/// - Durations stay short (150–350ms) so the UI never feels sluggish.
/// - All motion resolves to its final state, so widget tests using
///   `pumpAndSettle()` keep passing unchanged.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  /// Delay between siblings in a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 60);

  static const Curve entranceCurve = Curves.easeOutCubic;
  static const Curve pressCurve = Curves.easeOut;
}

/// Fades + slides a child into place after [delay].
///
/// Used for staggered list/card entrances (dashboard KPIs, report rows…).
/// Resolves exactly to the child — safe under `pumpAndSettle()`.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.medium,
    this.slideOffset = const Offset(0, 12),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: delay + duration,
      builder: (context, t, child) {
        // Hold at 0 during the delay window, then ease out.
        final total = (delay + duration).inMicroseconds;
        final d = delay.inMicroseconds;
        final linear = total <= d ? 0.0 : ((t * total - d) / (total - d));
        final eased = AppMotion.entranceCurve.transform(linear.clamp(0.0, 1.0));
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: slideOffset * (1 - eased),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Convenience: applies [Entrance] to each child with an incremental delay.
class Stagger extends StatelessWidget {
  const Stagger({
    super.key,
    required this.children,
    this.baseDelay = Duration.zero,
    this.step = AppMotion.stagger,
    this.duration = AppMotion.medium,
  });

  final List<Widget> children;
  final Duration baseDelay;
  final Duration step;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          Entrance(
            delay: baseDelay + step * i,
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

/// Counts a number up from zero to [target], formatting each frame.
///
/// Used for dashboard KPI values — the numbers "come alive" on load instead
/// of popping in. Ends exactly on [format(target)].
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.target,
    required this.format,
    this.duration = AppMotion.slow,
    this.style,
    this.textDirection,
  });

  final double target;
  final String Function(double value) format;
  final Duration duration;
  final TextStyle? style;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: duration,
      curve: AppMotion.entranceCurve,
      builder: (context, value, _) =>
          Text(format(value), style: style, textDirection: textDirection),
    );
  }
}

/// Subtle press-down scale for tappable surfaces (buttons, cards, chips).
///
/// Wraps any child; on press it scales to 0.97 and springs back on release.
/// Purely visual — hit-testing and semantics are untouched.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      // Don't steal gestures: the child keeps its own handlers.
      behavior: HitTestBehavior.translucent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: _pressed ? widget.scale : 1),
        duration: AppMotion.fast,
        curve: AppMotion.pressCurve,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: widget.child,
      ),
    );
  }
}
