import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import 'permissions_page.dart';
import 'roles_page.dart';
import 'users_page.dart';

/// Tabs inside the administration hub.
enum AdminTab { users, roles, permissions }

/// Phase 12 Administration hub: consolidates User management (existing Phase 6
/// page, untouched), Role management and the Permissions catalog.
/// Tab visibility is permission-driven; the route guard additionally blocks
/// the whole hub when the user holds neither `users.view` nor `roles.view`.
class AdminHubPage extends ConsumerWidget {
  const AdminHubPage({super.key, this.initialTab = AdminTab.users});

  final AdminTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final permissions = ref.watch(authControllerProvider).permissions;

    final tabs = <(AdminTab, String, Widget)>[
      if (permissions.contains(Perm.usersView))
        (AdminTab.users, l10n.navUsers, const UsersPage()),
      if (permissions.contains(Perm.rolesView))
        (
          AdminTab.roles,
          l10n.rolesTabTitle,
          const RolesPage(),
        ),
      if (permissions.contains(Perm.rolesView))
        (
          AdminTab.permissions,
          l10n.permissionsTabTitle,
          const PermissionsPage(),
        ),
    ];

    if (tabs.isEmpty) {
      return const _EmptyHub();
    }

    var initialIndex = 0;
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].$1 == initialTab) {
        initialIndex = i;
        break;
      }
    }

    return DefaultTabController(
      initialIndex: initialIndex,
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in tabs) Tab(text: tab.$2)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [for (final tab in tabs) tab.$3],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHub extends StatelessWidget {
  const _EmptyHub();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(l10n.accessDeniedMessage,
            style: context.appTypography.bodySecondary),
      ),
    );
  }
}