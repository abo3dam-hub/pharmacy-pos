import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/users_controller.dart';
import '../../domain/entities/user.dart';
import '../widgets/user_dialog.dart';

/// Admin user management page (§16 U3). Admin-only: the router requires
/// `users.view` and action buttons are hidden without `users.create/edit`.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(usersViewControllerProvider.notifier).load());
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.usersCreate);
  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.usersEdit);

  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  Future<void> _onSearch(String query) =>
      ref.read(usersViewControllerProvider.notifier).load(search: query);

  void _showFailure(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      DuplicateFailure() => l10n.userUsernameExists,
      UnauthorizedFailure() => l10n.authPermissionDenied,
      _ => l10n.authSaveError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createUser() async {
    final l10n = AppLocalizations.of(context);
    final roles = ref.read(usersViewControllerProvider).roles;
    final result = await showUserFormDialog(
      context,
      title: l10n.usersCreateTitle,
      roles: roles,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(usersViewControllerProvider.notifier).create(
          username: result.username!,
          displayName: result.displayName,
          roleId: result.roleId,
          password: result.password!,
          phone: result.phone,
          notes: result.notes,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (failure == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.userCreatedMessage)));
      }
    } else {
      _showFailure(failure);
    }
  }

  Future<void> _editUser(AppUser user) async {
    final l10n = AppLocalizations.of(context);
    final roles = ref.read(usersViewControllerProvider).roles;
    final result = await showUserFormDialog(
      context,
      title: l10n.usersEditTitle,
      roles: roles,
      editMode: true,
      initialUsername: user.username,
      initialDisplayName: user.displayName,
      initialRoleId: user.roleId,
      initialPhone: user.phone,
      initialNotes: user.notes,
    );
    if (result == null || !mounted) return;
    final failure = await ref.read(usersViewControllerProvider.notifier).update(
          id: user.id,
          displayName: result.displayName,
          roleId: result.roleId,
          phone: result.phone,
          notes: result.notes,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.userUpdatedMessage)));
    } else {
      _showFailure(failure);
    }
  }

  Future<void> _changePassword(AppUser user) async {
    final l10n = AppLocalizations.of(context);
    final password = await showChangePasswordDialog(context);
    if (password == null || !mounted) return;
    final failure = await ref
        .read(usersViewControllerProvider.notifier)
        .changePassword(
          id: user.id,
          newPassword: password,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.userPasswordChangedMessage)));
    } else {
      _showFailure(failure);
    }
  }

  Future<void> _toggleActive(AppUser user) async {
    final l10n = AppLocalizations.of(context);
    final activating = !user.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: activating
          ? l10n.userActivate
          : l10n.userDeactivateConfirmTitle,
      message: activating
          ? l10n.userActivateConfirmMessage(user.displayName)
          : l10n.userDeactivateConfirmMessage(user.displayName),
      confirmLabel: activating ? l10n.userActivate : l10n.userDeactivate,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(usersViewControllerProvider.notifier).setActive(
          id: user.id,
          active: activating,
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (failure == null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(activating
              ? l10n.userActivatedMessage
              : l10n.userDeactivatedMessage),
        ));
    } else {
      _showFailure(failure);
    }
  }

  void _toPage(int page) {
    final state = ref.read(usersViewControllerProvider);
    if (page < 1 || page > state.items.pageCount) return;
    ref.read(usersViewControllerProvider.notifier).load(search: state.search, page: page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(usersViewControllerProvider);
    final typography = context.appTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: SearchField(
              hintText: l10n.usersSearchHint,
              onChanged: _onSearch,
            ),
          ),
          if (_canCreate)
            FilledButton.icon(
              onPressed: _createUser,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.usersAdd),
            ),
        ],
      ),
    );

    final content = AppResponsiveLayout(
      desktop: _buildTable(l10n, state, typography),
      tablet: _buildTable(l10n, state, typography),
      compact: _buildCards(l10n, state, typography),
    );

    return LoadingOverlay(
      visible: state.status == UsersStatus.loading,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: content),
          _buildPager(l10n, state),
        ],
      ),
    );
  }

  Widget _buildPager(AppLocalizations l10n, UsersViewState state) {
    final pageCount = state.items.pageCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${state.page} / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: state.page <= 1 ? null : () => _toPage(state.page - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: state.page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(state.page + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    AppLocalizations l10n,
    UsersViewState state,
    AppTypography typography,
  ) {
    return AppDataTable(
      emptyMessage: l10n.usersEmpty,
      columns: [
        DataColumn(label: Text(l10n.userUsername)),
        DataColumn(label: Text(l10n.userFullName)),
        DataColumn(label: Text(l10n.userRole)),
        DataColumn(label: Text(l10n.userStatusActive)),
        DataColumn(label: Text(l10n.userLastLoginLabel)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final user in state.items.items)
          DataRow(cells: [
            DataCell(Text(user.username)),
            DataCell(Text(user.displayName)),
            DataCell(Text(user.roleLabel)),
            DataCell(_StatusChip(active: user.isActive, l10n: l10n)),
            DataCell(_lastLogin(l10n, user)),
            DataCell(_actions(l10n, user)),
          ]),
      ],
    );
  }

  Widget _buildCards(
    AppLocalizations l10n,
    UsersViewState state,
    AppTypography typography,
  ) {
    if (state.items.items.isEmpty) {
      return Center(
        child: Text(l10n.usersEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final user in state.items.items)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName, style: typography.sectionTitle),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${l10n.userFullName}: ${user.username}'
                              ' · ${user.roleLabel}',
                              style: typography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      _StatusChip(active: user.isActive, l10n: l10n),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    '${l10n.userLastLoginLabel}: ${_lastLoginText(l10n, user)}',
                    style: typography.label,
                  ),
                  if (_canEdit)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _actions(l10n, user),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(AppLocalizations l10n, AppUser user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_canEdit) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.commonEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _editUser(user),
          ),
          IconButton(
            icon: const Icon(Icons.password),
            tooltip: l10n.userChangePassword,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _changePassword(user),
          ),
          IconButton(
            icon: Icon(
              user.isActive ? Icons.block : Icons.check_circle_outline,
            ),
            tooltip: user.isActive ? l10n.userDeactivate : l10n.userActivate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _toggleActive(user),
          ),
        ],
      ],
    );
  }

  String _lastLoginText(AppLocalizations l10n, AppUser user) {
    final at = user.lastLoginAt;
    if (at == null) return l10n.userNeverLoggedIn;
    final d = DateTime.fromMillisecondsSinceEpoch(at);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  Widget _lastLogin(AppLocalizations l10n, AppUser user) =>
      Text(_lastLoginText(l10n, user));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active, required this.l10n});

  final bool active;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    final bg = active ? AppColors.successContainer : AppColors.surfaceContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              active ? l10n.userStatusActive : l10n.userStatusInactive,
              overflow: TextOverflow.ellipsis,
              style: context.appTypography.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}