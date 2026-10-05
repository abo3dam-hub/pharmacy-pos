/// Permission-gated UI: show disabled with a reason instead of hiding.
///
/// Ali (2026-10-05) asked that permission-restricted controls remain visible
/// but disabled, with the missing permission named — hiding them entirely
/// made features undiscoverable (the void icon was reported "missing").
///
/// The rule: **state** gates visibility (e.g. a void button stays hidden for
/// a returned invoice — voiding it is invalid, not unauthorized), while
/// **permissions** gate the enabled state. [PermissionGate] supplies both
/// the [granted] flag and the localized [reason]; the caller wires
/// `onPressed`/`tooltip` accordingly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

/// Arabic display name for a permission code (falls back to the code).
String permissionDisplayName(String code) {
  for (final p in kSeedPermissions) {
    if (p.code == code) return p.name;
  }
  return code;
}

/// Builds [builder] with the current permission state.
///
/// Granted when the user holds **any** of [permissions]. When [granted] is
/// false the caller should render its control disabled (`onPressed: null`)
/// and surface [reason] (e.g. as the tooltip text), so the user understands
/// *why* the action is unavailable.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permissions,
    required this.builder,
  });

  /// Convenience for a single permission.
  PermissionGate.single({
    super.key,
    required String permission,
    required this.builder,
  }) : permissions = [permission];

  /// Permission codes — granted if the user holds any of them.
  final List<String> permissions;
  final Widget Function(BuildContext context, bool granted, String reason)
      builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held =
        ref.watch(authControllerProvider).permissions;
    final granted = permissions.any(held.contains);
    final l10n = AppLocalizations.of(context);
    final reason = permissions.length == 1
        ? l10n.permissionRequired(permissionDisplayName(permissions.first))
        : l10n.permissionRequired(
            permissions.map(permissionDisplayName).join(' أو '),
          );
    return builder(context, granted, reason);
  }
}
