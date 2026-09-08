import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/rbac_controller.dart';
import '../../data/daos/rbac_dao.dart';
import '../../domain/entities/rbac.dart';

/// Phase 12 Permissions catalog (الصلاحيات): read-only reference of every
/// canonical permission code grouped by module. Editing happens per role.
/// Requires `roles.view` (route guard re-applies).
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authControllerProvider);
      ref.read(rbacControllerProvider.notifier).reload(auth.actingRoleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(rbacControllerProvider);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final groups = PermissionGroups.group(state.permissions);

    return LoadingOverlay(
      visible: state.status == RbacStatus.loading && state.permissions.isEmpty,
      label: l10n.commonLoading,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.l,
          AppSpacing.xl,
          AppSpacing.l,
        ),
        children: [
          Text(l10n.permissionsSubtitle, style: context.appTypography.bodySecondary),
          const SizedBox(height: AppSpacing.l),
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              child: Text(
                PermissionGroups.label(group.module, isEn ? 'en' : 'ar'),
                style: context.appTypography.sectionTitle,
              ),
            ),
            Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                for (final permission in group.permissions)
                  _PermissionChip(permission: permission),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
          ],
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.permission});

  final PermissionInfo permission;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(permission.nameAr, style: context.appTypography.label),
          const SizedBox(height: 2),
          Text(
            permission.code,
            style: context.appTypography.labelSmall.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}