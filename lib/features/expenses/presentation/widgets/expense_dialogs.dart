import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/amount_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/repositories/expense_repository.dart';

Money? _parseMoney(String text) {
  try {
    return Money.parse(text);
  } on FormatException {
    return null;
  }
}

/// Record-expense dialog result: the validated draft (+ optional picked
/// receipt source), or null when dismissed.
Future<ExpenseDraft?> showExpenseRecordDialog(
  BuildContext context, {
  required List<ExpenseCategoryRow> categories,
  required List<SupplierRow> suppliers,
  ExpensePaymentMethod initialPayment = ExpensePaymentMethod.cash,
}) async {
  final result = await showDialog<ExpenseDraft>(
    context: context,
    builder: (_) => _ExpenseFormDialog(
      categories: categories,
      suppliers: suppliers,
      initialPayment: initialPayment,
    ),
  );
  return result;
}

/// Edit dialog for the only mutable fields (description/notes).
Future<ExpenseEditDraft?> showExpenseEditDialog(
  BuildContext context, {
  required String description,
  String? notes,
}) async {
  final result = await showDialog<ExpenseEditDraft>(
    context: context,
    builder: (_) => _ExpenseEditDialog(
      description: description,
      notes: notes ?? '',
    ),
  );
  return result;
}

/// Cancel-void dialog with a mandatory reason.
Future<String?> showExpenseCancelDialog(
  BuildContext context, {
  required String expenseNumber,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _ExpenseCancelDialog(expenseNumber: expenseNumber),
  );
  return result;
}

/// Category master form (create/edit). System categories are read-only.
Future<ExpenseCategoryDraft?> showExpenseCategoryDialog(
  BuildContext context, {
  required bool isEdit,
  ExpenseCategoryRow? initial,
}) async {
  final result = await showDialog<ExpenseCategoryDraft>(
    context: context,
    builder: (_) => _ExpenseCategoryDialog(isEdit: isEdit, initial: initial),
  );
  return result;
}

/// Full-screen receipt preview (image file or PDF).
Future<void> showExpenseReceiptDialog(
  BuildContext context, {
  required String path,
}) async {
  final isPdf = path.toLowerCase().endsWith('.pdf');
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: isPdf
          ? PdfPreview(
              build: (_) => File(path).readAsBytes(),
              pdfFileName: 'expense-receipt.pdf',
            )
          : _ImageReceiptView(path: path),
    ),
  );
}

class _ImageReceiptView extends StatelessWidget {
  const _ImageReceiptView({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        Expanded(
          child: Image.file(File(path), fit: BoxFit.contain, errorBuilder: (_, _, _) {
            return Center(child: Text(l10n.expenseReceiptUnreadable));
          }),
        ),
      ],
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.categories,
    required this.suppliers,
    required this.initialPayment,
  });

  final List<ExpenseCategoryRow> categories;
  final List<SupplierRow> suppliers;
  final ExpensePaymentMethod initialPayment;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String? _categoryCode;
  String? _supplierId;
  ExpensePaymentMethod _payment = ExpensePaymentMethod.cash;
  DateTime _date = DateTime.now();
  String? _receiptPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payment = widget.initialPayment;
    if (widget.categories.isNotEmpty) {
      _categoryCode = widget.categories.first.code;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null || picked.path == null || !mounted) return;
    setState(() => _receiptPath = picked.path);
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final amount = _parseMoney(_amount.text.trim());
    if (_amount.text.trim().isEmpty || amount == null) {
      setState(() => _error = l10n.expenseAmountRequired);
      return;
    }
    if (amount.micros <= 0) {
      setState(() => _error = l10n.expenseAmountInvalid);
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = l10n.expenseDescriptionRequired);
      return;
    }
    if (_categoryCode == null) {
      setState(() => _error = l10n.expenseCategoryRequired);
      return;
    }
    Navigator.of(context).pop(
      ExpenseDraft(
        categoryCode: _categoryCode!,
        description: _description.text.trim(),
        amountMicros: amount.micros,
        paymentMethod: _payment,
        date: _date.millisecondsSinceEpoch,
        supplierId: _supplierId,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        receiptSourcePath: _receiptPath,
      ),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return AlertDialog(
      title: Text(l10n.expensesAddTitle),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmountField(
                controller: _amount,
                hintText: l10n.expenseAmount,
                autofocus: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.expenseDescription,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String>(
                initialValue: _categoryCode,
                decoration: InputDecoration(
                  labelText: l10n.expenseCategory,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.code, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryCode = v),
              ),
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String>(
                initialValue: _supplierId,
                decoration: InputDecoration(
                  labelText: l10n.expenseSupplier,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(
                      value: null, child: Text(l10n.expenseNoSupplier)),
                  for (final s in widget.suppliers)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _supplierId = v),
              ),
              const SizedBox(height: AppSpacing.m),
              SegmentedButton<ExpensePaymentMethod>(
                segments: [
                  ButtonSegment(
                    value: ExpensePaymentMethod.cash,
                    label: Text(l10n.expensesCash),
                    icon: const Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: ExpensePaymentMethod.card,
                    label: Text(l10n.expensesCard),
                    icon: const Icon(Icons.credit_card),
                  ),
                ],
                selected: {_payment},
                onSelectionChanged: (s) => setState(() => _payment = s.first),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(l10n.expensePaymentNote, style: context.appTypography.labelSmall),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$l10n.expenseDate: '
                      '${_date.toLocal().toIso8601String().split('T').first}',
                      style: context.appTypography.body,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(l10n.commonEdit),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: _notes,
                decoration: InputDecoration(
                  labelText: l10n.expenseNotesOptional,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              OutlinedButton.icon(
                onPressed: _pickReceipt,
                icon: const Icon(Icons.attach_file),
                label: Text(_receiptPath == null
                    ? l10n.expensesAttachReceipt
                    : _receiptPath!.split('/').last),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.m),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _ExpenseEditDialog extends StatefulWidget {
  const _ExpenseEditDialog({required this.description, required this.notes});

  final String description;
  final String notes;

  @override
  State<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<_ExpenseEditDialog> {
  late final TextEditingController _description =
      TextEditingController(text: widget.description);
  late final TextEditingController _notes =
      TextEditingController(text: widget.notes);

  @override
  void dispose() {
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseDescriptionRequired)));
      return;
    }
    Navigator.of(context).pop(
      ExpenseEditDraft(
        description: _description.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.expenseEditDescription),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _description,
              decoration: InputDecoration(
                labelText: l10n.expenseDescription,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _notes,
              decoration: InputDecoration(
                labelText: l10n.expenseNotesOptional,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(l10n.expenseAmountImmutableHint,
                style: context.appTypography.labelSmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _ExpenseCancelDialog extends StatefulWidget {
  const _ExpenseCancelDialog({required this.expenseNumber});

  final String expenseNumber;

  @override
  State<_ExpenseCancelDialog> createState() => _ExpenseCancelDialogState();
}

class _ExpenseCancelDialogState extends State<_ExpenseCancelDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_reason.text.trim().isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.expenseCancelReasonRequired)));
      return;
    }
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.expenseCancelTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.expenseCancelConfirmMessage(widget.expenseNumber),
              style: context.appTypography.body,
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _reason,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.expenseCancelReason,
                border: const OutlineInputBorder(),
                isDense: true,
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
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(l10n.expensesCancelAction),
        ),
      ],
    );
  }
}

class _ExpenseCategoryDialog extends StatefulWidget {
  const _ExpenseCategoryDialog({required this.isEdit, this.initial});

  final bool isEdit;
  final ExpenseCategoryRow? initial;

  @override
  State<_ExpenseCategoryDialog> createState() => _ExpenseCategoryDialogState();
}

class _ExpenseCategoryDialogState extends State<_ExpenseCategoryDialog> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _nameEn =
      TextEditingController(text: widget.initial?.nameEn ?? '');
  late final TextEditingController _account =
      TextEditingController(text: widget.initial?.accountCode ?? '');

  bool get _systemBlocked => widget.initial?.isSystem ?? false;

  void _submit() {
    Navigator.of(context).pop(
      ExpenseCategoryDraft(
        code: _code.text.trim(),
        name: _name.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        accountCode: _account.text.trim(),
        isActive: widget.initial?.isActive ?? true,
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _nameEn.dispose();
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.isEdit
          ? l10n.expenseCategoryEditTitle
          : l10n.expenseCategoryAddTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              enabled: !widget.isEdit,
              decoration: InputDecoration(
                labelText: l10n.expenseCategoryCode,
                hintText: l10n.expenseCategoryCodeHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.expenseCategoryName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _nameEn,
              decoration: InputDecoration(
                labelText: l10n.expenseCategoryNameEn,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: _account,
              decoration: InputDecoration(
                labelText: l10n.expenseCategoryAccount,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_systemBlocked) ...[
              const SizedBox(height: AppSpacing.m),
              Text(l10n.expenseCategorySystemBlock,
                  style: context.appTypography.labelSmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _systemBlocked && widget.isEdit ? null : _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}