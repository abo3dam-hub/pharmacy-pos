import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/customer_repository.dart';

/// Shows the customer/patient create/edit form dialog (§4.11). Returns a
/// validated [CustomerDraft] or null when cancelled. Money fields are integer
/// micro-units (§23).
Future<CustomerDraft?> showCustomerFormDialog(
  BuildContext context, {
  required String title,
  CustomerRow? initial,
}) async {
  final result = await showDialog<CustomerDraft>(
    context: context,
    builder: (_) => _CustomerFormDialog(title: title, initial: initial),
  );
  return result;
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({required this.title, this.initial});

  final String title;
  final CustomerRow? initial;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _hasAccount = false;
  bool _isActive = true;
  String? _gender;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final k in _fieldKeys) k: TextEditingController(),
    };
    final c = widget.initial;
    if (c != null) {
      _set('name', c.name);
      _set('phone', c.phone);
      _set('secondaryPhone', c.secondaryPhone);
      _set('email', c.email);
      _set('address', c.address);
      _set('notes', c.notes);
      _set('taxVatNumber', c.taxVatNumber);
      _set('medicalHistory', c.medicalHistory);
      _setMoney('openingBalance', c.openingBalanceMicros);
      _setMoney('creditLimit', c.creditLimitMicros);
      _hasAccount = c.hasAccount;
      _isActive = c.isActive;
      _gender = c.gender;
      if (c.dateOfBirth != null) {
        _dateOfBirth = DateTime.fromMillisecondsSinceEpoch(c.dateOfBirth!);
      }
    }
  }

  static const _fieldKeys = <String>[
    'name',
    'phone',
    'secondaryPhone',
    'email',
    'address',
    'notes',
    'taxVatNumber',
    'medicalHistory',
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final name = _controllers['name']!.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.customerNameRequired)));
      return;
    }
    final draft = CustomerDraft(
      name: name,
      phone: _textOrNull(_controllers['phone']),
      secondaryPhone: _textOrNull(_controllers['secondaryPhone']),
      email: _textOrNull(_controllers['email']),
      address: _textOrNull(_controllers['address']),
      notes: _textOrNull(_controllers['notes']),
      taxVatNumber: _textOrNull(_controllers['taxVatNumber']),
      medicalHistory: _textOrNull(_controllers['medicalHistory']),
      hasAccount: _hasAccount,
      openingBalanceMicros: _moneyMicros('openingBalance'),
      creditLimitMicros: _moneyMicros('creditLimit'),
      dateOfBirth: _dateOfBirth?.millisecondsSinceEpoch,
      gender: _gender,
      isActive: _isActive,
    );
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
                _textField('name', l10n.customerName,
                    required: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.customerNameRequired
                        : null),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _textField('phone', l10n.customerPhone),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('secondaryPhone', l10n.customerSecondaryPhone),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _textField('email', l10n.customerEmail),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _textField('taxVatNumber', l10n.customerTaxVatNumber),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                _textField('address', l10n.customerAddress),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(l10n),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: _genderField(l10n),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                _textField('medicalHistory', l10n.customerMedicalHistory),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _amountField('openingBalance', l10n.customerOpeningBalance),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child:
                          _amountField('creditLimit', l10n.customerCreditLimit),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                _textField('notes', l10n.customerNotes),
                const SizedBox(height: AppSpacing.m),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.customerHasAccount, style: typography.body),
                  value: _hasAccount,
                  onChanged: (v) => setState(() => _hasAccount = v),
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

  Widget _dateField(AppLocalizations l10n) {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.customerDateOfBirth,
          suffixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(
          _dateOfBirth == null
              ? ''
              : '${_dateOfBirth!.year}-${_two(_dateOfBirth!.month)}-${_two(_dateOfBirth!.day)}',
          style: context.appTypography.body,
        ),
      ),
    );
  }

  Widget _genderField(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: InputDecoration(labelText: l10n.customerGender),
      items: [
        DropdownMenuItem(value: 'male', child: Text(l10n.customerGenderMale)),
        DropdownMenuItem(value: 'female', child: Text(l10n.customerGenderFemale)),
      ],
      onChanged: (v) => setState(() => _gender = v),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}