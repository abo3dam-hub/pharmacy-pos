import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/database/settings_dao.dart';
import 'shortcut_manager.dart';

/// Loads and persists the rebindable POS shortcut bindings (§21) into
/// `app_settings`. Starts from the §21 defaults and applies stored overrides
/// once per session ([ensureLoaded]).
class ShortcutBindingsController
    extends StateNotifier<Map<PosShortcutKind, String>> {
  ShortcutBindingsController(this._dao)
      : super(PosShortcutManager.defaultBindings);

  final SettingsDao _dao;
  bool _loaded = false;

  /// Applies persisted bindings once. Idempotent, safe to call on each build.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    state = PosShortcutManager.resolveFromSettings(await _dao.getAll());
  }

  /// Reassigns [kind] to [token]. Returns `false` when the token is unknown
  /// or already used by another action; otherwise persists and returns `true`.
  Future<bool> rebind(PosShortcutKind kind, String? token) async {
    if (token == null || !PosShortcutManager.assignable.containsKey(token)) {
      return false;
    }
    final next = Map<PosShortcutKind, String>.of(state);
    next[kind] = token;
    if (PosShortcutManager.firstConflict(next) != null) return false;
    state = Map.unmodifiable(next);
    await _dao.setString(kind.settingsKey, token, updatedBy: 'shortcuts');
    return true;
  }
}