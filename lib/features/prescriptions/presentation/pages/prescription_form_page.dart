import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../features/inventory/domain/entities/inventory_item.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/prescription_repository.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §4.12 create-prescription form. One header (patient + doctor) and a list of
/// item lines (dose schedule). Saved via the prescriptions controller; the
/// total is computed from the items master selling price (£4.13).
class PrescriptionFormPage extends ConsumerStatefulWidget {
  const PrescriptionFormPage({super.key});

  @override
  ConsumerState<PrescriptionFormPage> createState() =>
      _PrescriptionFormPageState();
}

class _PrescriptionFormPageState extends ConsumerState<PrescriptionFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _patientName = TextEditingController();
  final _patientAge = TextEditingController();
  final _doctorName = TextEditingController();
  final _doctorSpecialty = TextEditingController();
  final _clinicHospital = TextEditingController();
  final _notes = TextEditingController();
  final _imagePath = TextEditingController();

  String? _customerId;
  String? _patientGender;
  DateTime? _issuedAt;
  DateTime? _expiryAt;
  final _lines = <_RxItemLine>[];
  bool _saving = false;

  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  @override
  void initState() {
    super.initState();
    _issuedAt = DateTime.now();
  }

  @override
  void dispose() {
    _patientName.dispose();
    _patientAge.dispose();
    _doctorName.dispose();
    _doctorSpecialty.dispose();
    _clinicHospital.dispose();
    _notes.dispose();
    _imagePath.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool issued}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: issued
          ? (_issuedAt ?? DateTime.now())
          : (_expiryAt ?? (DateTime.now().add(const Duration(days: 30)))),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (issued) {
        _issuedAt = picked;
      } else {
        _expiryAt = picked;
      }
    });
  }

  Future<void> _addLine() async {
    final item = await _showItemSearchDialog(context);
    if (item == null || !mounted) return;
    setState(() => _lines.add(_RxItemLine(
          itemId: item.id,
          itemName: itemDisplayName(item),
        )));
  }

  void _removeLine(_RxItemLine line) => setState(() => _lines.remove(line));

  String _message(Failure failure) =>
      failureMessage(AppLocalizations.of(context), failure);

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      _showSnack(l10n.prescriptionRequiredCustomer);
      return;
    }
    if (_lines.isEmpty) {
      _showSnack(l10n.prescriptionRequiredItems);
      return;
    }
    for (final l in _lines) {
      if (l.itemId.isEmpty || int.tryParse(l.qty.text) == null) {
        _showSnack(l10n.prescriptionRequiredQuantity);
        return;
      }
      if ((int.tryParse(l.qty.text) ?? 0) <= 0) {
        _showSnack(l10n.prescriptionRequiredQuantity);
        return;
      }
    }
    final draft = PrescriptionDraft(
      customerId: _customerId!,
      patientName: _patientName.text.trim(),
      patientAge:
          int.tryParse(_patientAge.text.trim().isEmpty ? '' : _patientAge.text.trim()),
      patientGender: _patientGender,
      doctorName: _textOrNull(_doctorName),
      doctorSpecialty: _textOrNull(_doctorSpecialty),
      clinicHospital: _textOrNull(_clinicHospital),
      issuedAt: _issuedAt != null
          ? DateTime(_issuedAt!.year, _issuedAt!.month, _issuedAt!.day)
              .millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch,
      expiryAt: _expiryAt == null
          ? null
          : DateTime(_expiryAt!.year, _expiryAt!.month, _expiryAt!.day)
              .millisecondsSinceEpoch,
      notes: _textOrNull(_notes),
      imagePath: _textOrNull(_imagePath),
      items: [
        for (final l in _lines)
          PrescriptionItemDraft(
            itemId: l.itemId,
            quantityBase: int.tryParse(l.qty.text.trim()) ?? 0,
            dosage: _textOrNull(l.dosage),
            frequency: _textOrNull(l.frequency),
            durationDays: int.tryParse(
                l.duration.text.trim().isEmpty ? '' : l.duration.text.trim()),
            notes: _textOrNull(l.lineNotes),
          ),
      ],
    );
    setState(() => _saving = true);
    final failure = await ref
        .read(prescriptionsControllerProvider.notifier)
        .create(draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.prescriptionCreatedMessage)));
      context.pop();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_message(failure))));
    }
  }

  String? _textOrNull(TextEditingController? c) {
    final v = c?.text.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;

    return LoadingOverlay(
      visible: _saving,
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
            child: Row(
              children: [
                IconButton(
                  icon: Icon(AppDirectionalIcons.back(context)),
                  tooltip: l10n.commonBack,
                  onPressed: () => context.pop(),
                ),
                Text(l10n.prescriptionAddTitle, style: typography.pageTitle),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.s,
                AppSpacing.xl,
                AppSpacing.l,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _customerCard(l10n),
                    const SizedBox(height: AppSpacing.m),
                    _patientCard(l10n),
                    const SizedBox(height: AppSpacing.m),
                    _doctorCard(l10n),
                    const SizedBox(height: AppSpacing.m),
                    _itemsCard(l10n, typography),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.s,
              AppSpacing.xl,
              AppSpacing.l,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.commonSave),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(AppLocalizations l10n) {
    return _card(
      title: l10n.prescriptionCustomer,
      child: Consumer(builder: (context, ref, _) {
        final customers = ref.watch(_activeCustomersProvider);
        return DropdownButtonFormField<String>(
          initialValue: _customerId,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.prescriptionCustomer),
          items: [
            for (final c in customers.valueOrNull ?? const <CustomerRow>[])
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _customerId = v),
        );
      }),
    );
  }

  Widget _patientCard(AppLocalizations l10n) {
    return _card(
      title: l10n.prescriptionPatient,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _patientName,
                  decoration: InputDecoration(
                      labelText: '${l10n.prescriptionPatientName} *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.prescriptionRequiredPatient
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: TextFormField(
                  controller: _patientAge,
                  decoration: InputDecoration(labelText: l10n.prescriptionPatientAge),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          DropdownButtonFormField<String>(
            initialValue: _patientGender,
            decoration: InputDecoration(labelText: l10n.prescriptionPatientGender),
            items: [
              DropdownMenuItem(value: 'male', child: Text(l10n.customerGenderMale)),
              DropdownMenuItem(
                  value: 'female', child: Text(l10n.customerGenderFemale)),
            ],
            onChanged: (v) => setState(() => _patientGender = v),
          ),
        ],
      ),
    );
  }

  Widget _doctorCard(AppLocalizations l10n) {
    return _card(
      title: l10n.prescriptionDoctorName,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _doctorName,
                  decoration: InputDecoration(labelText: l10n.prescriptionDoctorName),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: TextField(
                  controller: _doctorSpecialty,
                  decoration:
                      InputDecoration(labelText: l10n.prescriptionDoctorSpecialty),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _clinicHospital,
            decoration: InputDecoration(labelText: l10n.prescriptionClinicHospital),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(issued: true),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.prescriptionIssuedAt,
                      suffixIcon: const Icon(Icons.event_outlined),
                    ),
                    child: Text(_fmtDate(_issuedAt), style: context.appTypography.body),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(issued: false),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.prescriptionExpiryAt,
                      suffixIcon: const Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _expiryAt == null ? l10n.commonNone : _fmtDate(_expiryAt),
                      style: context.appTypography.body,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _imagePath,
            decoration: InputDecoration(labelText: l10n.prescriptionImagePath),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _notes,
            decoration: InputDecoration(labelText: l10n.prescriptionNotes),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(AppLocalizations l10n, AppTypography typography) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.prescriptionItems, style: typography.sectionTitle)),
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.prescriptionAddItem),
                ),
              ],
            ),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Text(l10n.prescriptionRequiredItems,
                    style: typography.bodySecondary),
              ),
            for (final line in _lines) _itemLine(l10n, line),
          ],
        ),
      ),
    );
  }

  Widget _itemLine(AppLocalizations l10n, _RxItemLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.itemName, style: context.appTypography.sectionTitle),
              ),
              IconButton(
                onPressed: () => _removeLine(line),
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.commonDelete,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: line.qty,
                  decoration: InputDecoration(labelText: l10n.prescriptionQuantity),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: TextField(
                  controller: line.dosage,
                  decoration: InputDecoration(labelText: l10n.prescriptionDosage),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.frequency,
                  decoration: InputDecoration(labelText: l10n.prescriptionFrequency),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: TextField(
                  controller: line.duration,
                  decoration: InputDecoration(labelText: l10n.prescriptionDurationDays),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: line.lineNotes,
            decoration: InputDecoration(labelText: l10n.prescriptionLineNotes),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.appTypography.sectionTitle),
            const SizedBox(height: AppSpacing.m),
            child,
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<ItemRow?> _showItemSearchDialog(BuildContext context) async {
    return showDialog<ItemRow>(
      context: context,
      builder: (_) => _ItemSearchDialog(),
    );
  }
}

final _activeCustomersProvider = FutureProvider<List<CustomerRow>>((ref) async {
  final auth = ref.read(authControllerProvider);
  return ref
      .read(allCustomersUseCaseProvider)
      .call(actingRoleId: auth.actingRoleId);
});

/// One editable prescription line. Quantity is in base units (£4.13).
class _RxItemLine {
  _RxItemLine({required this.itemId, required this.itemName})
      : qty = TextEditingController(text: '1'),
        dosage = TextEditingController(),
        frequency = TextEditingController(),
        duration = TextEditingController(),
        lineNotes = TextEditingController();

  final String itemId;
  final String itemName;
  final TextEditingController qty;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController lineNotes;
}

/// Item picker — searches the catalog, returns the chosen [ItemRow].
class _ItemSearchDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ItemSearchDialog> createState() => _ItemSearchDialogState();
}

class _ItemSearchDialogState extends ConsumerState<_ItemSearchDialog> {
  final _search = TextEditingController();
  List<ItemRow> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _onChanged() async {
    final q = _search.text.trim();
    setState(() => _loading = true);
    final result = await ref
        .read(inventoryRepositoryProvider)
        .searchItems(PageRequest(pageSize: 20, search: q));
    if (!mounted) return;
    setState(() {
      _results = result.items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.prescriptionAddItem),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => _onChanged(),
              decoration: InputDecoration(
                hintText: l10n.prescriptionsSearchHint.isEmpty
                    ? ''
                    : l10n.prescriptionItem,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            l10n.prescriptionsEmpty,
                            style: context.appTypography.labelSmall,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final item = _results[i];
                            return ListTile(
                              title: Text(itemDisplayName(item)),
                              subtitle: Text(item.scientificName ?? ''),
                              onTap: () => Navigator.of(context).pop(item),
                            );
                          },
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
      ],
    );
  }
}