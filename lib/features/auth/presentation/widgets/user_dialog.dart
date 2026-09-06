import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user.dart';

/// Result of the create/edit user dialog.
class UserFormResult {
  const UserFormResult({
    required this.displayName,
    required this.roleId,
    this.username,
    this.password,
    this.phone,
    this.notes,
    this.editMode = false,
  });

  final String displayName;
  final String roleId;
  final String? username;
  final String? password;
  final String? phone;
  final String? notes;
  final bool editMode;
}

/// Create / edit user form dialog (admin-only screen; §16 U3).
Future<UserFormResult?> showUserFormDialog(
  BuildContext context, {
  required String title,
  required List<RoleInfo> roles,
  String? initialUsername,
  String? initialDisplayName,
  String? initialRoleId,
  String? initialPhone,
  String? initialNotes,
  bool editMode = false,
}) {
  return showDialog<UserFormResult>(
    context: context,
    builder: (context) => _UserFormDialog(
      title: title,
      roles: roles,
      initialUsername: initialUsername,
      initialDisplayName: initialDisplayName,
      initialRoleId: initialRoleId,
      initialPhone: initialPhone,
      initialNotes: initialNotes,
      editMode: editMode,
    ),
  );
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.title,
    required this.roles,
    this.initialUsername,
    this.initialDisplayName,
    this.initialRoleId,
    this.initialPhone,
    this.initialNotes,
    this.editMode = false,
  });

  final String title;
  final List<RoleInfo> roles;
  final String? initialUsername;
  final String? initialDisplayName;
  final String? initialRoleId;
  final String? initialPhone;
  final String? initialNotes;
  final bool editMode;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.initialUsername ?? '');
  late final _displayName =
      TextEditingController(text: widget.initialDisplayName ?? '');
  late final _phone = TextEditingController(text: widget.initialPhone ?? '');
  late final _notes = TextEditingController(text: widget.initialNotes ?? '');
  late final _password = TextEditingController();
  late final _passwordConfirm = TextEditingController();
  late String? _roleId = widget.initialRoleId;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _phone.dispose();
    _notes.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(UserFormResult(
      username: _username.text.trim(),
      displayName: _displayName.text.trim(),
      roleId: _roleId!,
      password: _password.text,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      editMode: widget.editMode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title, style: context.appTypography.sectionTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.editMode) ...[
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.userUsername),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.userRequiredField
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.userNewPassword),
                  validator: (v) => (v == null || v.length < 6)
                      ? l10n.userPasswordMinLength
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordConfirm,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration:
                      InputDecoration(labelText: l10n.userConfirmPassword),
                  validator: (v) => v != _password.text
                      ? l10n.userPasswordMismatch
                      : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _displayName,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.userFullName),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.userRequiredField
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _roleId,
                items: [
                  for (final role in widget.roles)
                    DropdownMenuItem(
                      value: role.id,
                      child: Text(role.nameAr),
                    ),
                ],
                onChanged: (v) => setState(() => _roleId = v),
                decoration: InputDecoration(labelText: l10n.userRole),
                validator: (v) => v == null ? l10n.userRequiredField : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.userPhone),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.userNotes),
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
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// Change password dialog (returns the new password or null on cancel).
Future<String?> showChangePasswordDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.userChangePasswordTitle,
          style: context.appTypography.sectionTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration:
                  InputDecoration(labelText: l10n.userNewPassword),
              validator: (v) => (v == null || v.length < 6)
                  ? l10n.userPasswordMinLength
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration:
                  InputDecoration(labelText: l10n.userConfirmPassword),
              validator: (v) =>
                  v != _password.text ? l10n.userPasswordMismatch : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.userChangePassword),
        ),
      ],
    );
  }
}