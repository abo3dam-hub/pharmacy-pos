import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/supplier_repository.dart';

/// Shows the supplier create/edit form dialog (§4.10). Returns a validated
/// [SupplierDraft] or null when cancelled. Money fields are integer micro-units.
Future<SupplierDraft?> showSupplierFormDialog(
  BuildContext context, {
  required String title,
  SupplierRow? initial,
}) async {
  final result = await showDialog<SupplierDraft>(
    context: context,
    builder: (_) => _SupplierFormDialog(title: title, initial: initial),
  );
  return result;
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({required this.title, this.initial});

  final String title;
  final SupplierRow? initial;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final k in _fieldKeys) k: TextEditingController(),
    };
    _isActive = widget.initial?.isActive ?? true;
    final s = widget.initial;
    if (s != null) {
      _set('name', s.name);
      _set('code', s.code);
      _set('phone', s.phone);
      _set('secondaryPhone', s.secondaryPhone);
      _set('email', s.email);
      _set('address', s.address);
      _set('contactPerson', s.contactPerson);
      _set('taxVatNumber', s.taxVatNumber);
      _set('licenseRegistration', s.licenseRegistration);
      _set('notes', s.notes);
      _setMoney('openingBalance', s.openingBalanceMicros);
      _setMoney('creditLimit', s.creditLimitMicros);
    }
  }

  static const _fieldKeys = <String>[
    'name',
    'code',
    'phone',
    'secondaryPhone',
    'email',
    'address',
    'contactPerson',
    'taxVatNumber',
    'licenseRegistration',
    'notes',
  ];

  void _set(String key, String? value) => _controllers[key]!.text = value ?? '';

  void _setMoney(String key, int micros) => _controllers[key]!.text =
      micros == 0 ? '' : Money.fromUnits(micros).format(4).replaceFirst(
          RegExp(r'\.?0+$'), '');

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final draft = SupplierDraft(
      name: _controllers['name']!.text.trim(),
      code: _textOrNull(_controllers['code']),
      phone: _textOrNull(_controllers['phone']),
      secondaryPhone: _textOrNull(_controllers['secondaryPhone']),
      email: _textOrNull(_controllers['email']),
      address: _textOrNull(_controllers['address']),
      contactPerson: _textOrNull(_controllers['contactPerson']),
      taxVatNumber: _textOrNull(_controllers['taxVatNumber']),
      licenseRegistration: _textOrNull(_controllers['licenseRegistration']),
      openingBalanceMicros: _moneyMicros('openingBalance'),
      creditLimitMicros: _moneyMicros('creditLimit'),
      notes: _textOrNull(_controllers['notes']),
      isActive: _isActive,
    );
    if (draft.name.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.supplierNameRequired)));
      return;
    }
    Navigator.of(context).pop(draft);
  }

  String? _textOrNull(TextEditingController? c) {
    final v = c?.text.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  int _moneyMicros(String key) {
    final v = _controllers[key]?.text.trim() ?? '';
    if (v.isEmpty) return 0;
    try {
      final m = Money.parse(v);
      return m.units;
    } on FormatException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;

    return AlertDialog(
      title: Text(widget.title, style: typography.sectionTitle),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField('name', l10n.supplierName,
                    required: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.supplierNameRequired
                        : null),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _textField('code', l10n.supplierCode),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('phone', l10n.supplierPhone),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child:
                          _textField('secondaryPhone', l10n.supplierSecondaryPhone),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('email', l10n.supplierEmail),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                _textField('address', l10n.supplierAddress),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _textField('contactPerson', l10n.supplierContactPerson),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('taxVatNumber', l10n.supplierTaxVatNumber),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _textField('licenseRegistration',
                          l10n.supplierLicenseRegistration),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _amountField('openingBalance', l10n.supplierOpeningBalance),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _amountField('creditLimit', l10n.supplierCreditLimit),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('notes', l10n.supplierNotes),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.userStatusActive, style: typography.body),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
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

  Widget _textField(
    String key,
    String label, {
    String? Function(String?)? validator,
    bool required = false,
  }) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
      ),
      validator: validator,
    );
  }

  Widget _amountField(String key, String label) {
    return TextFormField(
      controller: _controllers[key],
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}