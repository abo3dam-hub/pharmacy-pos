import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/rbac_controller.dart';
import '../../domain/entities/rbac.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/role_dialog.dart';

/// Phase 12 Role management (الأدوار): list roles with permission/user counts,
/// create/edit Arabic labels, assign permissions, delete custom roles.
/// Requires `roles.view` for the page and `roles.edit` for actions.
class RolesPage extends ConsumerStatefulWidget {
  const RolesPage({super.key});

  @override
  ConsumerState<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends ConsumerState<RolesPage> {
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
    final canEdit =
        ref.read(authControllerProvider).permissions.contains(Perm.rolesEdit);

    return LoadingOverlay(
      visible: state.status == RbacStatus.loading && state.roles.isEmpty,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.l,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.s,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.rolesSubtitle, style: context.appTypography.bodySecondary),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: () => _createRole(context, ref),
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(l10n.rolesAdd),
                  ),
              ],
            ),
          ),
          Expanded(
            child: state.status == RbacStatus.error && state.roles.isEmpty
                ? Center(child: Text(l10n.rolesEmpty, style: context.appTypography.labelSmall))
                : _buildList(context, ref, state, canEdit, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    RbacViewState state,
    bool canEdit,
    AppLocalizations l10n,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      children: [
        for (final role in state.roles) _RoleCard(role: role, canEdit: canEdit),
      ],
    );
  }

  Future<void> _createRole(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final state = ref.read(rbacControllerProvider);
    final result = await showRoleDialog(
      context,
      title: l10n.rolesCreateTitle,
      permissions: state.permissions,
      allowEdit: true,
    );
    if (result == null || !context.mounted) return;
    final auth = ref.read(authControllerProvider);
    final failure = await ref.read(rbacControllerProvider.notifier).create(
          name: result.nameAr,
          nameAr: result.nameAr,
          actingUserId: auth.user?.id,
          actingRoleId: auth.actingRoleId,
        );
    if (!context.mounted) return;
    _report(context, ref, failure, l10n.rolesCreatedMessage);
  }

  void _report(
    BuildContext context,
    WidgetRef ref,
    Failure? failure,
    String successMessage,
  ) {
    if (!context.mounted) return;
    final message = failure == null
        ? successMessage
        : failureMessage(AppLocalizations.of(context), failure);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}

class _RoleCard extends ConsumerWidget {
  const _RoleCard({required this.role, required this.canEdit});

  final RoleRecord role;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final auth = ref.read(authControllerProvider);

    Future<void> permissions() async {
      if (!canEdit) return;
      final state = ref.read(rbacControllerProvider);
      final detail = await ref.read(rbacControllerProvider.notifier).getDetail(
            auth.actingRoleId,
            role.id,
          );
      if (detail == null || !context.mounted) return;
      final result = await showPermissionDialog(
        context,
        title: l10n.rolesPermissionsFor(role.nameAr),
        permissions: state.permissions,
        initial: detail.permissionCodes,
        allowEdit: true,
      );
      if (result == null || !context.mounted) return;
      final failure = await ref
          .read(rbacControllerProvider.notifier)
          .setRolePermissions(
            roleId: role.id,
            codes: result,
            isSystemRole: role.isSystem,
            actingUserId: auth.user?.id,
            actingRoleId: auth.actingRoleId,
          );
      if (failure == null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.rolesPermissionsSaved)));
      } else if (failure != null && context.mounted) {
        _report(context, ref, failure, '');
      }
    }

    Future<void> edit() async {
      if (!canEdit) return;
      final state = ref.read(rbacControllerProvider);
      final detail = await ref.read(rbacControllerProvider.notifier).getDetail(
            auth.actingRoleId,
            role.id,
          );
      if (detail == null || !context.mounted) return;
      final result = await showRoleDialog(
        context,
        title: l10n.rolesEditTitle,
        permissions: state.permissions,
        initialNameAr: role.nameAr,
        initialPermissions: detail.permissionCodes,
        allowEdit: true,
      );
      if (result == null || !context.mounted) return;
      final failure = await ref.read(rbacControllerProvider.notifier).update(
            id: role.id,
            nameAr: result.nameAr,
            actingUserId: auth.user?.id,
            actingRoleId: auth.actingRoleId,
          );
      if (failure == null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.rolesUpdatedMessage)));
      } else if (failure != null && context.mounted) {
        _report(context, ref, failure, '');
      }
    }

    Future<void> delete() async {
      if (!canEdit) return;
      final confirmed = await showAppConfirmDialog(
        context,
        title: l10n.rolesDeleteTitle,
        message: l10n.rolesDeleteConfirm(role.nameAr),
        confirmLabel: l10n.rolesDelete,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
      final failure = await ref.read(rbacControllerProvider.notifier).delete(
            id: role.id,
            actingUserId: auth.user?.id,
            actingRoleId: auth.actingRoleId,
          );
      if (failure == null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.rolesDeletedMessage)));
      } else if (failure != null && context.mounted) {
        _report(context, ref, failure, '');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(role.nameAr, style: typography.sectionTitle),
                          ),
                          if (role.isSystem) ...[
                            const SizedBox(width: AppSpacing.s),
                            _SystemBadge(enabled: role.isActive),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${l10n.rolesPermissionsCount(role.permissionCount)}'
                        ' · ${l10n.rolesUsersCount(role.userCount)}',
                        style: typography.bodySecondary,
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: edit,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.commonEdit,
                      ),
                      IconButton(
                        onPressed: permissions,
                        icon: const Icon(Icons.key_outlined),
                        tooltip: l10n.rolesPermissionsTitle,
                      ),
                      if (!role.isSystem)
                        IconButton(
                          onPressed: delete,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.rolesDelete,
                          color: AppColors.error,
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _report(
    BuildContext context,
    WidgetRef ref,
    Failure? failure,
    String successMessage,
  ) {
    if (!context.mounted || failure == null) return;
    showFailureSnack(context, failure);
  }
}

class _SystemBadge extends StatelessWidget {
  const _SystemBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = enabled ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        enabled ? l10n.rolesSystemBadge : l10n.rolesInactiveBadge,
        style: context.appTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}