import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/rbac.dart';
import '../../data/daos/rbac_dao.dart';

/// Permission assignment dialog (Phase 12). Groups all permissions by module
/// with a checkbox per permission; returns the selected code set (null on
/// cancel). Read-only when [allowEdit] is false (viewer role).
Future<Set<String>?> showPermissionDialog(
  BuildContext context, {
  required String title,
  required List<PermissionInfo> permissions,
  required Set<String> initial,
  required bool allowEdit,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => _PermissionDialog(
      title: title,
      permissions: permissions,
      initial: initial,
      allowEdit: allowEdit,
    ),
  );
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.title,
    required this.permissions,
    required this.initial,
    required this.allowEdit,
  });

  final String title;
  final List<PermissionInfo> permissions;
  final Set<String> initial;
  final bool allowEdit;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  late final Set<String> _selected = Set<String>.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final groups = PermissionGroups.group(widget.permissions);

    return AlertDialog(
      title: Text(widget.title, style: context.appTypography.sectionTitle),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allowEdit) ...[
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _selected.addAll(
                        widget.permissions.map((p) => p.code),
                      );
                    }),
                    child: Text(l10n.permissionsSelectAll),
                  ),
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: Text(l10n.permissionsClearAll),
                  ),
                  const Spacer(),
                  Text(
                    '${_selected.length} / ${widget.permissions.length}',
                    style: context.appTypography.bodySecondary,
                  ),
                ],
              ),
              const Divider(),
            ],
            Expanded(
              child: ListView(
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s,
                      ),
                      child: Text(
                        PermissionGroups.label(group.module, isEn ? 'en' : 'ar'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (widget.allowEdit)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: Text(l10n.commonSave),
          ),
      ],
    );
  }
}