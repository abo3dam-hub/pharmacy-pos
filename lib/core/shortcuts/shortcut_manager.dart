import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'pos_shortcuts.dart';

/// POS keyboard actions (§21).
///
/// Central, rebindable catalog of the workspace shortcuts. Defaults follow the
/// roadmap table exactly; bindings are persisted via `app_settings`
/// (`PosShortcutKind.settingsKey`) and re-resolved on every launch, so the
/// focused-context behavior (`PosShortcutScope`) and the POS page stay in sync.
enum PosShortcutKind {
  search('f1'),
  toggleUnit('f2'),
  holdBill('f5'),
  checkout('f12'),
  alternatives('alt_s');

  const PosShortcutKind(this.defaultToken);

  /// Stable persisted token of the §21 default binding.
  final String defaultToken;

  /// Canonical `app_settings` key holding this action's binding.
  String get settingsKey => 'shortcut.$name';
}

/// Single registry of §21 keyboard shortcuts (centralized in `core/`,
/// configurable through settings, applied app-wide).
abstract final class PosShortcutManager {
  PosShortcutManager._();

  /// The rebindable keys offered in the settings screen. Stored as stable
  /// tokens ("f1", …, "f12", "alt_s") — never key IDs — so values survive
  /// layout/platform differences.
  static const Map<String, ShortcutActivator> assignable = {
    'f1': SingleActivator(LogicalKeyboardKey.f1),
    'f2': SingleActivator(LogicalKeyboardKey.f2),
    'f3': SingleActivator(LogicalKeyboardKey.f3),
    'f4': SingleActivator(LogicalKeyboardKey.f4),
    'f5': SingleActivator(LogicalKeyboardKey.f5),
    'f6': SingleActivator(LogicalKeyboardKey.f6),
    'f7': SingleActivator(LogicalKeyboardKey.f7),
    'f8': SingleActivator(LogicalKeyboardKey.f8),
    'f9': SingleActivator(LogicalKeyboardKey.f9),
    'f10': SingleActivator(LogicalKeyboardKey.f10),
    'f11': SingleActivator(LogicalKeyboardKey.f11),
    'f12': SingleActivator(LogicalKeyboardKey.f12),
    'alt_s': SingleActivator(LogicalKeyboardKey.keyS, alt: true),
  };

  /// Human-readable key captions for the settings dropdown.
  static const Map<String, String> assignableLabels = {
    'f1': 'F1',
    'f2': 'F2',
    'f3': 'F3',
    'f4': 'F4',
    'f5': 'F5',
    'f6': 'F6',
    'f7': 'F7',
    'f8': 'F8',
    'f9': 'F9',
    'f10': 'F10',
    'f11': 'F11',
    'f12': 'F12',
    'alt_s': 'Alt + S',
  };

  /// §21 defaults: F1 search, F2 box/fraction, F5 hold bill, F12 checkout,
  /// Alt+S alternatives.
  static const Map<PosShortcutKind, String> defaultBindings = {
    PosShortcutKind.search: 'f1',
    PosShortcutKind.toggleUnit: 'f2',
    PosShortcutKind.holdBill: 'f5',
    PosShortcutKind.checkout: 'f12',
    PosShortcutKind.alternatives: 'alt_s',
  };

  /// Builds the `Shortcuts` map for a resolved binding map. Unknown tokens
  /// (e.g. a stale setting) are skipped rather than crashing the UI.
  static Map<ShortcutActivator, Intent> buildIntentMap(
      Map<PosShortcutKind, String> bindings) {
    final out = <ShortcutActivator, Intent>{};
    for (final kind in PosShortcutKind.values) {
      final activator = assignable[bindings[kind]];
      if (activator == null) continue;
      out[activator] = _intentFor(kind);
    }
    return Map.unmodifiable(out);
  }

  /// Resolves the persisted `app_settings` map into per-kind tokens, falling
  /// back to §21 defaults for missing / unknown / malformed entries.
  static Map<PosShortcutKind, String> resolveFromSettings(
      Map<String, String> settings) {
    final resolved = <PosShortcutKind, String>{};
    for (final kind in PosShortcutKind.values) {
      final value = settings[kind.settingsKey]?.trim();
      resolved[kind] =
          value != null && assignable.containsKey(value) ? value : kind.defaultToken;
    }
    return Map.unmodifiable(resolved);
  }

  /// The subset of bindings that differ from the §21 defaults (only these are
  /// persisted, so defaults always win on a fresh install).
  static Map<String, String> settingsMap(
      Map<PosShortcutKind, String> bindings) {
    final out = <String, String>{};
    for (final kind in PosShortcutKind.values) {
      final token = bindings[kind] ?? kind.defaultToken;
      if (token != kind.defaultToken) out[kind.settingsKey] = token;
    }
    return out;
  }

  /// The first [PosShortcutKind] whose token is already used by another action,
  /// or `null` when every key is unique.
  static PosShortcutKind? firstConflict(Map<PosShortcutKind, String> bindings) {
    final seen = <String, PosShortcutKind>{};
    for (final kind in PosShortcutKind.values) {
      final token = bindings[kind];
      if (token == null) continue;
      if (seen.containsKey(token)) return kind;
      seen[token] = kind;
    }
    return null;
  }

  static Intent _intentFor(PosShortcutKind kind) => switch (kind) {
        PosShortcutKind.search => const SearchFocusIntent(),
        PosShortcutKind.toggleUnit => const ToggleUnitModeIntent(),
        PosShortcutKind.holdBill => const HoldBillIntent(),
        PosShortcutKind.checkout => const CheckoutIntent(),
        PosShortcutKind.alternatives => const ShowAlternativesIntent(),
      };
}