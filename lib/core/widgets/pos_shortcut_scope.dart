import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_sections.dart';
import '../di/providers.dart';
import '../shortcuts/pos_shortcuts.dart';
import '../shortcuts/shortcut_manager.dart';

/// App-wide keyboard registration (§21): mounts ONE `Shortcuts` + `Actions`
/// pair above every authenticated screen.
///
/// While the POS workspace is focused, its inner `Shortcuts`/`Actions`
/// (registration in `pos_workspace_page`) win — the actions keep their
/// workspace context. On any other screen the shell fallback opens the POS
/// workspace, so F1/F2/F5/F12/Alt+S remain meaningful no matter where the
/// user is. Rebinds from the settings screen apply immediately because the
/// bindings are watched from [shortcutBindingsProvider].
class PosShortcutScope extends ConsumerWidget {
  const PosShortcutScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(shortcutBindingsProvider.notifier).ensureLoaded();
    final bindings = ref.watch(shortcutBindingsProvider);

    // Fallback handler used outside the POS workspace — navigates to POS
    // where the action is available. The inner workspace actions take
    // precedence whenever the workspace is focused.
    void openPos() => context.go(AppSection.sale.path);

    return Shortcuts(
      shortcuts: PosShortcutManager.buildIntentMap(bindings),
      child: Actions(
        actions: {
          SearchFocusIntent: CallbackAction<SearchFocusIntent>(
              onInvoke: (_) {
                openPos();
                return null;
              }),
          ToggleUnitModeIntent: CallbackAction<ToggleUnitModeIntent>(
              onInvoke: (_) {
                openPos();
                return null;
              }),
          HoldBillIntent: CallbackAction<HoldBillIntent>(
              onInvoke: (_) {
                openPos();
                return null;
              }),
          CheckoutIntent: CallbackAction<CheckoutIntent>(
              onInvoke: (_) {
                openPos();
                return null;
              }),
          ShowAlternativesIntent: CallbackAction<ShowAlternativesIntent>(
              onInvoke: (_) {
                openPos();
                return null;
              }),
        },
        child: child,
      ),
    );
  }
}