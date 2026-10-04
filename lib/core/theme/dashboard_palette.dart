import 'package:flutter/material.dart';

/// Curated pastel tints for the dashboard's colorful cards and hero
/// carousel — "alive but calm", per Ali's visual-refresh request
/// (2026-10-04): comfortable, consistent, never gaudy.
///
/// Design rules:
/// - Backgrounds are soft, low-saturation washes; text always stays on the
///   theme's `onSurface` for readability — the color carries identity, not
///   information.
/// - Accents are the app's existing semantic tokens (medical teal, warning
///   amber, error rose, info indigo, brand violet, success green), so the
///   palette stays consistent with the rest of the product instead of
///   introducing new hues.
/// - Dark mode lifts the accent over the dark surface instead of using a
///   pastel wash, keeping contrast comfortable at night.
///
/// Widgets must consume these tints — no `Color` literals in widgets.
class DashboardTint {
  const DashboardTint._({
    required this.lightBackground,
    required this.lightAccent,
    required this.darkAccent,
  });

  /// Soft pastel wash (light mode).
  final Color lightBackground;

  /// Icon/number accent (light mode) — a semantic token.
  final Color lightAccent;

  /// Icon/number accent (dark mode) — the matching dark semantic token.
  final Color darkAccent;

  /// Card/slide background for the current brightness.
  Color background(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return lightBackground;
    }
    final surface = Theme.of(context).colorScheme.surface;
    return Color.lerp(surface, darkAccent, 0.18)!;
  }

  /// Icon/number accent for the current brightness.
  Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? lightAccent
          : darkAccent;

  /// Soft diagonal gradient for carousel slides.
  LinearGradient gradient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = background(context);
    final deep = Theme.of(context).brightness == Brightness.light
        ? Color.lerp(bg, lightAccent, 0.10)!
        : Color.lerp(scheme.surface, darkAccent, 0.30)!;
    return LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [bg, deep],
    );
  }

  /// Thin outline that ties the card to its accent without shouting.
  Color outline(BuildContext context) =>
      accent(context).withValues(alpha: 0.28);

  // ── The six tints ──────────────────────────────────────────────────────
  // Accents mirror AppColors' semantic tokens (WCAG-checked); dark accents
  // mirror the dark* variants from the same file.

  /// مبيعات اليوم — medical teal (primary identity).
  static const DashboardTint teal = DashboardTint._(
    lightBackground: Color(0xFFDFF0ED),
    lightAccent: Color(0xFF00696D),
    darkAccent: Color(0xFF5EC4B6),
  );

  /// تنبيهات المخزون — warm amber.
  static const DashboardTint amber = DashboardTint._(
    lightBackground: Color(0xFFF7ECD4),
    lightAccent: Color(0xFF7F5714),
    darkAccent: Color(0xFFD29B4A),
  );

  /// قرب انتهاء الصلاحية — soft rose.
  static const DashboardTint rose = DashboardTint._(
    lightBackground: Color(0xFFF6DEDA),
    lightAccent: Color(0xFFA9323A),
    darkAccent: Color(0xFFD4796F),
  );

  /// بيع جديد / معلومات — calm indigo.
  static const DashboardTint indigo = DashboardTint._(
    lightBackground: Color(0xFFDCE7F2),
    lightAccent: Color(0xFF3D6B96),
    darkAccent: Color(0xFF6F9BC7),
  );

  /// المنتجات النشطة — muted brand violet.
  static const DashboardTint violet = DashboardTint._(
    lightBackground: Color(0xFFE7E1F0),
    lightAccent: Color(0xFF7B6A9E),
    darkAccent: Color(0xFF9E8FD0),
  );

  /// الربح / النجاح — calm green.
  static const DashboardTint green = DashboardTint._(
    lightBackground: Color(0xFFDDEBDD),
    lightAccent: Color(0xFF2E7D5B),
    darkAccent: Color(0xFF62B18B),
  );
}
