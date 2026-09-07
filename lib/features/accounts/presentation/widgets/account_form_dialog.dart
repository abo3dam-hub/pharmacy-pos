import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';

/// Result of the account form dialog.
class AccountFormResult {
  const AccountFormResult({
    required this.type,
    required this.code,
    required this.name,
    this.nameEn,
    this.parentId,
    this.openingBalanceMicros = 0,
    this.notes,
  });

  final AccountType type;
  final String code;
  final String name;
  final String? nameEn;
  final String? parentId;
  final int openingBalanceMicros;
  final String? notes;
}

/// Shows an account create/edit dialog.
Future<AccountFormResult?> showAccountFormDialog(
  BuildContext context, {
  AccountRow? existing,
}) {
  return showDialog<AccountFormResult>(
    context: context,
    builder: (_) => _AccountFormDialog(existing: existing),
  );
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({this.existing});

  final AccountRow? existing;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late AccountType _type;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _openingBalCtrl;
  late final TextEditingController _notesCtrl;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.accountType ?? AccountType.asset;
    _codeCtrl = TextEditingController(text: e?.code ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _nameEnCtrl = TextEditingController(text: e?.nameEn ?? '');
    _openingBalCtrl = TextEditingController(
        text: e != null && e.openingBalanceMicros != 0
            ? (e.openingBalanceMicros / 10000).toStringAsFixed(2)
            : '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _openingBalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    var openingBalanceMicros = 0;
    final balText = _openingBalCtrl.text.trim();
    if (balText.isNotEmpty) {
      try {
        openingBalanceMicros = Money.parse(balText).micros;
      } on FormatException {
        openingBalanceMicros = 0;
      }
    }
    Navigator.of(context).pop(AccountFormResult(
      type: _type,
      code: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      nameEn: _nameEnCtrl.text.trim().isEmpty
          ? null
          : _nameEnCtrl.text.trim(),
      parentId: widget.existing?.parentId,
      openingBalanceMicros: openingBalanceMicros,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(_isEdit ? l10n.accountsEditTitle : l10n.accountsAddTitle),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n.accountsColType,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: AccountType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_typeLabel(l10n, t)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: AppSpacing.m),

              // Code
              TextFormField(
                controller: _codeCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountsColCode,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                enabled: !_isEdit || !widget.existing!.isSystem,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.accountsCodeRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.m),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountsColName,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l10n.accountsNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.m),

              // NameEn
              TextFormField(
                controller: _nameEnCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountsNameEn,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.m),

              // Opening balance
              TextFormField(
                controller: _openingBalCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountsOpeningBalance,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,\-]')),
                ],
                enabled: !_isEdit || !widget.existing!.isSystem,
              ),
              const SizedBox(height: AppSpacing.m),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.accountsNotes,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
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

  static String _typeLabel(AppLocalizations l10n, AccountType type) =>
      switch (type) {
        AccountType.asset => l10n.accountTypeAsset,
        AccountType.liability => l10n.accountTypeLiability,
        AccountType.equity => l10n.accountTypeEquity,
        AccountType.revenue => l10n.accountTypeRevenue,
        AccountType.expense => l10n.accountTypeExpense,
      };
}
