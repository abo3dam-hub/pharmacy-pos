import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/dashboard_palette.dart';

/// One hero slide: an icon, a headline value, a label, a hint pill and the
/// route the slide navigates to when tapped.
@immutable
class DashboardSlide {
  const DashboardSlide({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.tint,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final DashboardTint tint;
  final String route;
}

/// Auto-playing hero carousel ("السلايدر") for the dashboard.
///
/// - Fixed height, so the dashboard's no-scroll contract holds.
/// - Advances every [autoPlayInterval] with a smooth page animation; the
///   timer is cancelled on dispose and user drags simply move the page
///   (the periodic timer then continues from the new page).
/// - Every slide is tappable and navigates to its related page.
/// - Dots indicator mirrors the current page.
///
/// [autoPlay] defaults to true; widget tests pass false so
/// `pumpAndSettle()` keeps working (a periodic timer would never settle).
class DashboardCarousel extends StatefulWidget {
  const DashboardCarousel({
    super.key,
    required this.slides,
    this.autoPlay = true,
    this.height = 148,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  final List<DashboardSlide> slides;
  final bool autoPlay;
  final double height;
  final Duration autoPlayInterval;

  @override
  State<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends State<DashboardCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.autoPlay && widget.slides.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) => _advance());
    }
  }

  void _advance() {
    if (!mounted || !_controller.hasClients || widget.slides.length < 2) {
      return;
    }
    final next = (_page + 1) % widget.slides.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.slides.length,
            itemBuilder: (context, i) =>
                _SlideCard(slide: widget.slides[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        _Dots(count: widget.slides.length, current: _page),
      ],
    );
  }
}

/// A single tappable slide with a soft tinted gradient.
class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide});

  final DashboardSlide slide;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final tint = slide.tint;
    final accent = tint.accent(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(slide.route),
          child: Ink(
            decoration: BoxDecoration(
              gradient: tint.gradient(context),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: tint.outline(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.72),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(slide.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.label,
                          style: typography.bodySecondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          slide.value,
                          style: typography.pageTitle.copyWith(fontSize: 26),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      slide.hint,
                      style: typography.labelSmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dots indicator — the active dot stretches into a pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == current
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
