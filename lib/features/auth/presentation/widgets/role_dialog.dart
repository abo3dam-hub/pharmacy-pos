import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/daos/rbac_dao.dart';
import '../../domain/entities/rbac.dart';

/// Result of create/edit role dialog.
class RoleFormResult {
  const RoleFormResult({required this.nameAr, required this.permissions});

  final String nameAr;
  final Set<String> permissions;
}

/// Create / edit role dialog (Phase 12). The `name` code is generated from the
/// Arabic label for custom roles and never changes for system roles; here the
/// user edits the display label + the permission set in one pass.
/// [allowEdit] gates both fields (viewer mode shows read-only copy).
Future<RoleFormResult?> showRoleDialog(
  BuildContext context, {
  required String title,
  required List<PermissionInfo> permissions,
  String? initialNameAr,
  Set<String> initialPermissions = const {},
  required bool allowEdit,
}) {
  return showDialog<RoleFormResult>(
    context: context,
    builder: (context) => _RoleDialog(
      title: title,
      permissions: permissions,
      initialNameAr: initialNameAr,
      initialPermissions: initialPermissions,
      allowEdit: allowEdit,
    ),
  );
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({
    required this.title,
    required this.permissions,
    this.initialNameAr,
    this.initialPermissions = const {},
    required this.allowEdit,
  });

  final String title;
  final List<PermissionInfo> permissions;
  final String? initialNameAr;
  final Set<String> initialPermissions;
  final bool allowEdit;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameAr = TextEditingController(text: widget.initialNameAr ?? '');
  late final Set<String> _selected = Set<String>.of(widget.initialPermissions);

  @override
  void dispose() {
    _nameAr.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      RoleFormResult(nameAr: _nameAr.text.trim(), permissions: _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final groups = PermissionGroups.group(widget.permissions);

    return AlertDialog(
      title: Text(widget.title, style: context.appTypography.sectionTitle),
      content: SizedBox(
        width: 480,
        height: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameAr,
                enabled: widget.allowEdit,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.rolesNameAr,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.rolesNameRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.l),
              Text(l10n.rolesPermissionsTitle, style: context.appTypography.label),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: widget.permissions.isEmpty
                    ? Center(child: Text(l10n.rolesEmpty, style: context.appTypography.bodySecondary))
                    : ListView(
                        children: [
                          for (final group in groups) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s,
                              ),
                              child: Text(
                                PermissionGroups.label(
                                  group.module,
                                  isEn ? 'en' : 'ar',
                                ),
                                style: context.appTypography.label,
                              ),
                            ),
                            for (final permission in group.permissions)
                              CheckboxListTile(
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: _selected.contains(permission.code),
                                onChanged: widget.allowEdit
                                    ? (checked) => setState(() {
                                          if (checked ?? false) {
                                            _selected.add(permission.code);
                                          } else {
                                            _selected.remove(permission.code);
                                          }
                                        })
                                    : null,
                                title: Text(
                                  permission.nameAr,
                                  style: context.appTypography.body,
                                ),
                                subtitle: Text(
                                  permission.code,
                                  style: context.appTypography.labelSmall,
                                ),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (widget.allowEdit)
          FilledButton(
            onPressed: _submit,
            child: Text(l10n.commonSave),
          ),
      ],
    );
  }
}