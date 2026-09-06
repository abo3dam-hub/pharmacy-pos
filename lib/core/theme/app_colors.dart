import 'package:flutter/material.dart';

/// Central color tokens — the single source of truth for the visual identity
/// (Modern Clinical + Professional + Calm + Premium).
///
/// Rules enforced by this palette:
/// - Green (`primarySeed`) is the primary medical identity — calm, never neon.
/// - Muted purple (`accent`) is an accent only, used sparingly.
/// - Red is reserved for errors/danger; amber for warnings; blue for info;
///   green for success. Colors are never used decoratively.
/// - Neutral surfaces are white / warm light gray; text is charcoal.
///
/// The Material 3 `ColorScheme` in `app_theme.dart` is derived from these
/// tokens; screens must never hardcode colors. Status rendering additionally
/// pairs every color with text + icon/badge (§24 — never color alone).
abstract final class AppColors {
  // ── Primary (medical green) ────────────────────────────────────────────
  static const Color primarySeed = Color(0xFF00696D);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Accent (muted purple, used sparingly) ─────────────────────────────
  static const Color accent = Color(0xFF7B6A9E);
  static const Color accentContainer = Color(0xFFE7E1F0);

  // ── Neutrals (warm gray scale) ────────────────────────────────────────
  static const Color canvas = Color(0xFFF7F7F5);
  static const Color surfaceLight = Color(0xFFFCFCFB);
  static const Color surfaceVariant = Color(0xFFF0F0ED);
  static const Color surfaceContainer = Color(0xFFE9E9E5);
  static const Color outline = Color(0xFFC9CCC8);
  static const Color divider = Color(0xFFE1E0DB);

  // ── Text (charcoal / dark gray) ───────────────────────────────────────
  static const Color textPrimary = Color(0xFF24292B);
  static const Color textSecondary = Color(0xFF5A6366);
  static const Color textMuted = Color(0xFF7C858A);
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── Semantic (never decorative) ───────────────────────────────────────
  static const Color success = Color(0xFF2E7D5B);
  static const Color successContainer = Color(0xFFDDEBDD);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningContainer = Color(0xFFF4E8D2);
  static const Color error = Color(0xFFB45550);
  static const Color errorContainer = Color(0xFFF6DEDA);
  static const Color info = Color(0xFF3D6B96);
  static const Color infoContainer = Color(0xFFDCE7F2);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onInfo = Color(0xFFFFFFFF);

  // ── Dark surfaces (optional night/premium variant) ────────────────────
  static const Color darkCanvas = Color(0xFF141716);
  static const Color darkSurface = Color(0xFF1C201F);
  static const Color darkSurfaceVariant = Color(0xFF262B29);
  static const Color darkSurfaceContainer = Color(0xFF2E3432);
  static const Color darkOutline = Color(0xFF49504D);
  static const Color darkDivider = Color(0xFF2E3432);
  static const Color darkTextPrimary = Color(0xFFE8EAE7);
  static const Color darkTextSecondary = Color(0xFF9BA4A0);
  static const Color darkTextMuted = Color(0xFF767F7A);
  static const Color darkAccent = Color(0xFF9E8FD0);
  static const Color darkSuccess = Color(0xFF62B18B);
  static const Color darkWarning = Color(0xFFD29B4A);
  static const Color darkError = Color(0xFFD4796F);
  static const Color darkInfo = Color(0xFF6F9BC7);
}