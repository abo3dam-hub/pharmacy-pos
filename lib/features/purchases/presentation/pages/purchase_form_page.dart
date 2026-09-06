import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/repositories/purchases_repository.dart';

/// Purchase invoice form — create (`/purchases/new`) or edit a pending invoice
/// (`/purchases/edit/:id`). Lines carry paid quantities, unit costs, discounts
/// and the bonus editor (§12, §13). Totals are previewed client-side.
class PurchaseFormPage extends ConsumerStatefulWidget {
  const PurchaseFormPage({super.key, this.invoiceId});

  final String? invoiceId;

  @override
  ConsumerState<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _BonusDraft {
  _BonusDraft(this.bonusType, this.quantityBase, this.itemId);

  PurchaseBonusType bonusType;
  int quantityBase;
  String? itemId;
}

class _PurchLine {
  _PurchLine({
    required this.itemId,
    required this.itemName,
    required this.unitTypeId,
    required this.unitTypeName,
    this.quantityBase = 1,
    this.unitCostMicros = 0,
    this.discountBasisPoints = 0,
    List<_BonusDraft>? bonuses,
  }) : bonuses = bonuses ?? [];

  String itemId;
  String itemName;
  String unitTypeId;
  String unitTypeName;
  int quantityBase;
  int unitCostMicros;
  int discountBasisPoints;
  final List<_BonusDraft> bonuses;
}

class _PurchaseFormPageState extends ConsumerState<PurchaseFormPage> {
  final _formKey = GlobalKey<FormState>();

  final List<_PurchLine> _lines = [];
  final List<({String id, String name})> _suppliers = [];
  String? _supplierId;
  bool _loading = true;
  bool _saving = false;

  final _invoiceNumber = TextEditingController();
  final _notes = TextEditingController();
  final _paidAmount = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  DateTime? _expectedDate;

  bool get _isEdit => widget.invoiceId != null;

  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.permissions.contains(Perm.purchasesView)) return;
    final rows = await ref
        .read(allSuppliersUseCaseProvider)
        .call(actingRoleId: auth.actingRoleId);
    if (mounted) {
      setState(() => _suppliers.addAll([
            for (final r in rows) (id: r.id, name: r.name),
          ]));
    }
    if (_isEdit) {
      await _loadForEdit();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadForEdit() async {
    try {
      final detail = await ref
          .read(getPurchaseDetailUseCaseProvider)
          .call(widget.invoiceId!, actingRoleId: _actingRoleId);
      if (!mounted) return;
      _invoiceNumber.text = detail.invoice.invoiceNumber;
      _invoiceDate =
          DateTime.fromMillisecondsSinceEpoch(detail.invoice.invoiceDate);
      if (detail.invoice.expectedDate != null) {
        _expectedDate =
            DateTime.fromMillisecondsSinceEpoch(detail.invoice.expectedDate!);
      }
      if (detail.invoice.paidMicros > 0) {
        _paidAmount.text = Money.fromUnits(detail.invoice.paidMicros).format(4);
      }
      if (detail.invoice.notes != null) _notes.text = detail.invoice.notes!;
      _supplierId = detail.invoice.supplierId;
      for (final v in detail.lines) {
        _lines.add(_PurchLine(
          itemId: v.line.itemId,
          itemName: v.itemName,
          unitTypeId: v.line.unitTypeId,
          unitTypeName: '',
          quantityBase: v.line.quantityBase,
          unitCostMicros: v.line.unitCostMicros,
          discountBasisPoints: v.line.discountBasisPoints,
          bonuses: [
            for (final b in detail.bonuses
                .where((b2) => b2.bonus.purchaseInvoiceItemId == v.line.id)
                .toList())
              _BonusDraft(b.bonus.bonusType, b.bonus.bonusQuantityBase,
                  b.bonus.itemId),
          ],
        ));
      }
      setState(() => _loading = false);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(e.failure);
    }
  }

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _notes.dispose();
    _paidAmount.dispose();
    super.dispose();
  }

  void _showSnack(Failure? failure) {
    if (failure == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      UnauthorizedFailure() => l10n.authPermissionDenied,
      _ => l10n.authSaveError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _invoiceDate = picked);
  }

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedDate ?? _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _expectedDate = picked);
  }

  Future<void> _pickItem(StateSetter setCard, _PurchLine line) async {
    final item = await _showItemSearchDialog(context);
    if (item == null || !mounted) return;
    final units = await ref
        .read(inventoryRepositoryProvider)
        .itemUnitsFor(item.id);
    if (units == null) {
      _showSnack(const DatabaseFailure('no item units'));
      return;
    }
    final unitName = (await ref
            .read(inventoryRepositoryProvider)
            .unitById(units.baseUnitId))
        ?.name ?? '';
    setCard(() {
      line.itemId = item.id;
      line.itemName = item.tradeName.isEmpty
          ? (item.primaryBarcode ?? item.id)
          : item.tradeName;
      line.unitTypeId = units.baseUnitId;
      line.unitTypeName = unitName;
      if (line.unitCostMicros == 0) line.unitCostMicros = item.costMicros;
    });
  }

  Future<void> _editBonuses(StateSetter setCard, _PurchLine line) async {
    final result = await _showBonusEditorDialog(
      context,
      itemName: line.itemName,
      bonuses: List.of(line.bonuses),
    );
    if (result == null || !mounted) return;
    setCard(() {
      line.bonuses
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _addLine() async {
    final item = await _showItemSearchDialog(context);
    if (item == null || !mounted) return;
    final units = await ref
        .read(inventoryRepositoryProvider)
        .itemUnitsFor(item.id);
    if (units == null) {
      _showSnack(const DatabaseFailure('no item units'));
      return;
    }
    final unitName = (await ref
            .read(inventoryRepositoryProvider)
            .unitById(units.baseUnitId))
        ?.name ?? '';
    setState(() {
      _lines.add(_PurchLine(
        itemId: item.id,
        itemName: item.tradeName.isEmpty
            ? (item.primaryBarcode ?? item.id)
            : item.tradeName,
        unitTypeId: units.baseUnitId,
        unitTypeName: unitName,
        unitCostMicros: item.costMicros,
      ));
    });
  }

  void _removeLine(_PurchLine line) => setState(() => _lines.remove(line));

  bool _validate() {
    final l10n = AppLocalizations.of(context);
    if (_supplierId == null) {
      _showSnack(ValidationFailure(l10n.purchaseRequiredSupplier));
      return false;
    }
    if (_invoiceNumber.text.trim().isEmpty) {
      _showSnack(ValidationFailure(l10n.purchaseRequiredNumber));
      return false;
    }
    if (_lines.isEmpty) {
      _showSnack(ValidationFailure(l10n.purchaseRequiredLines));
      return false;
    }
    for (final l in _lines) {
      if (l.itemId.isEmpty) {
        _showSnack(ValidationFailure(l10n.purchaseItemNotNull));
        return false;
      }
      if (l.quantityBase <= 0) {
        _showSnack(ValidationFailure(l10n.purchaseQtyPositive));
        return false;
      }
      if (l.unitCostMicros < 0) {
        _showSnack(ValidationFailure(l10n.purchaseCostPositive));
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validate()) return;
    setState(() => _saving = true);
    final draft = PurchaseDraft(
      invoiceNumber: _invoiceNumber.text.trim(),
      supplierId: _supplierId!,
      invoiceDate: DateTime(_invoiceDate.year, _invoiceDate.month, _invoiceDate.day)
          .millisecondsSinceEpoch,
      expectedDate: _expectedDate == null
          ? null
          : DateTime(_expectedDate!.year, _expectedDate!.month, _expectedDate!.day)
              .millisecondsSinceEpoch,
      paidMicros: _parseMoney(_paidAmount.text),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      userId: _actingUserId ?? '',
      lines: [
        for (final l in _lines)
          PurchaseLineDraft(
            itemId: l.itemId,
            unitTypeId: l.unitTypeId,
            quantityBase: l.quantityBase,
            unitCostMicros: l.unitCostMicros,
            discountBasisPoints: l.discountBasisPoints,
            bonuses: [
              for (final b in l.bonuses)
                PurchaseBonusDraft(
                  bonusType: b.bonusType,
                  quantityBase: b.quantityBase,
                  itemId: b.itemId,
                ),
            ],
          ),
      ],
    );
    final controller = ref.read(purchasesControllerProvider.notifier);
    final Failure? outcome = _isEdit
        ? await controller.updatePending(widget.invoiceId!, draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId)
        : await controller.create(draft,
            actingUserId: _actingUserId, actingRoleId: _actingRoleId);
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome != null) {
      _showSnack(outcome);
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(_isEdit
              ? l10n.purchaseUpdatedMessage
              : l10n.purchaseCreatedMessage)));
    context.go('/purchases');
  }

  int _parseMoney(String text) {
    final v = text.trim();
    if (v.isEmpty) return 0;
    try {
      return Money.parse(v).units;
    } on FormatException {
      return 0;
    }
  }

  int get _subtotalMicros {
    var total = 0;
    for (final l in _lines) {
      total += l.quantityBase * l.unitCostMicros;
    }
    return total;
  }

  int get _discountMicros {
    var total = 0;
    for (final l in _lines) {
      if (l.discountBasisPoints > 0) {
        total +=
            (l.quantityBase * l.unitCostMicros) * l.discountBasisPoints ~/ 10000;
      }
    }
    return total;
  }

  int get _totalMicros => _subtotalMicros - _discountMicros;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.commonBack,
            onPressed: () => context.go('/purchases'),
          ),
          Text(
            _isEdit ? l10n.purchaseEditTitle : l10n.purchaseCreateTitle,
            style: typography.pageTitle,
          ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: _loading || _saving,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
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
                    _headerSection(l10n),
                    const SizedBox(height: AppSpacing.l),
                    _linesSection(l10n, typography),
                    const SizedBox(height: AppSpacing.l),
                    _totalsSection(l10n, typography),
                    const SizedBox(height: AppSpacing.l),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(l10n.commonSave),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _supplierId,
              decoration: InputDecoration(labelText: l10n.purchasesFilterSupplier),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.purchaseRequiredSupplier),
                ),
                for (final s in _suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) =>
                  setState(() => _supplierId = v?.isEmpty ?? true ? null : v),
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _invoiceNumber,
                    decoration: InputDecoration(
                      labelText: l10n.purchaseOrderNumber,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.purchaseRequiredNumber
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_fmtDate(_invoiceDate)),
                ),
                const SizedBox(width: AppSpacing.m),
                OutlinedButton.icon(
                  onPressed: _pickExpectedDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_expectedDate == null
                      ? l10n.purchaseExpectedDate
                      : _fmtDate(_expectedDate!)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: [
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _paidAmount,
                    decoration: InputDecoration(
                      labelText: l10n.purchasePaidAmount,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: TextFormField(
                    controller: _notes,
                    decoration: InputDecoration(labelText: l10n.purchaseNotes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linesSection(AppLocalizations l10n, AppTypography typography) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.purchaseItemPlaceholder, style: typography.sectionTitle),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: Text(l10n.purchaseAddLine),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        if (_lines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(l10n.purchaseNoLines,
                style: context.appTypography.bodySecondary),
          )
        else
          for (int i = 0; i < _lines.length; i++) _lineCard(l10n, i, _lines[i]),
      ],
    );
  }

  Widget _lineCard(AppLocalizations l10n, int index, _PurchLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: StatefulBuilder(
        builder: (context, setCard) {
          final lineTotal = line.quantityBase * line.unitCostMicros;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${index + 1}. ${line.itemName}',
                        style: context.appTypography.label,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.purchaseRemoveLine,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                          width: 32, height: 32),
                      onPressed: () => _removeLine(line),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                Wrap(
                  spacing: AppSpacing.m,
                  runSpacing: AppSpacing.m,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        initialValue: '${line.quantityBase}',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.purchaseQty),
                        onChanged: (v) => setCard(() {
                          line.quantityBase =
                              int.tryParse(v.trim()) ?? (line.quantityBase);
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextFormField(
                        initialValue: line.unitCostMicros == 0
                            ? ''
                            : Money.fromUnits(line.unitCostMicros).format(4),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                            labelText: l10n.purchaseUnitCost),
                        onChanged: (v) => setCard(() {
                          line.unitCostMicros = _parseMoney(v);
                        }),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        initialValue: line.discountBasisPoints == 0
                            ? ''
                            : '${(line.discountBasisPoints / 100).round()}',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: l10n.purchaseDiscountPct),
                        onChanged: (v) => setCard(() {
                          final pct = int.tryParse(v.trim()) ?? 0;
                          line.discountBasisPoints = pct * 100;
                        }),
                      ),
                    ),
                    Text(
                      '${l10n.purchaseUnitType}: ${line.unitTypeName}',
                      style: context.appTypography.bodySecondary,
                    ),
                    Text(
                      Money.fromUnits(lineTotal).format(),
                      style: context.appTypography.numericStrong,
                    ),
                    TextButton.icon(
                      onPressed: () => _editBonuses(setCard, line),
                      icon: const Icon(Icons.card_giftcard),
                      label: Text(
                        line.bonuses.isEmpty
                            ? l10n.purchaseBonusButton
                            : '${l10n.purchaseBonusButton} (${line.bonuses.length})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickItem(setCard, line),
                      icon: const Icon(Icons.search),
                      label: Text(l10n.purchaseItemSearchHint),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _totalsSection(AppLocalizations l10n, AppTypography typography) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _totalRow(l10n.purchaseSubtotal, Money.fromUnits(_subtotalMicros)),
            _totalRow(l10n.purchaseDiscount, Money.fromUnits(_discountMicros)),
            const Divider(height: AppSpacing.xl),
            _totalRow(l10n.purchaseGrandTotal, Money.fromUnits(_totalMicros)),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, Money amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.appTypography.body),
          Text(amount.format(), style: context.appTypography.numericStrong),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

/// Search-and-pick dialog for purchase items (uses the bounded inventory
/// search, §30).
Future<ItemRow?> _showItemSearchDialog(BuildContext context) {
  return showDialog<ItemRow>(
    context: context,
    builder: (_) => const _ItemSearchDialog(),
  );
}

class _ItemSearchDialog extends ConsumerStatefulWidget {
  const _ItemSearchDialog();

  @override
  ConsumerState<_ItemSearchDialog> createState() => _ItemSearchDialogState();
}

class _ItemSearchDialogState extends ConsumerState<_ItemSearchDialog> {
  final _search = TextEditingController();
  List<ItemRow> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_onChanged)
      ..dispose();
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
      title: Text(l10n.purchaseItemSearchHint),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.purchaseItemSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(l10n.purchasesEmpty,
                              style: context.appTypography.labelSmall),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final item = _results[i];
                            return ListTile(
                              title: Text(item.tradeName.isEmpty
                                  ? (item.primaryBarcode ?? item.id)
                                  : item.tradeName),
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

/// Bonus editor dialog — one or more bonus rows per line. `itemId == null`
/// means the bonus is granted on the purchased item itself; a chosen bonus
/// item models Buy A Get B (§4.18, §13).
Future<List<_BonusDraft>?> _showBonusEditorDialog(
  BuildContext context, {
  required String itemName,
  required List<_BonusDraft> bonuses,
}) {
  return showDialog<List<_BonusDraft>>(
    context: context,
    builder: (_) => _BonusEditorDialog(itemName: itemName, bonuses: bonuses),
  );
}

class _BonusEditorDialog extends ConsumerStatefulWidget {
  const _BonusEditorDialog({required this.itemName, required this.bonuses});

  final String itemName;
  final List<_BonusDraft> bonuses;

  @override
  ConsumerState<_BonusEditorDialog> createState() => _BonusEditorDialogState();
}

class _BonusEditorDialogState extends ConsumerState<_BonusEditorDialog> {
  late final List<_BonusDraft> _bonuses = List.of(widget.bonuses);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l10n.purchaseBonusButton} — ${widget.itemName}'),
      content: SizedBox(
        width: 480,
        child: _bonuses.isEmpty
            ? Text(l10n.purchaseNoLines,
                style: context.appTypography.bodySecondary)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (int i = 0; i < _bonuses.length; i++) _bonusRow(i),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _bonuses.add(_BonusDraft(
              PurchaseBonusType.bonus_1, 1, null))),
          icon: const Icon(Icons.add),
          label: Text(l10n.purchaseAddLine),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_bonuses),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  Widget _bonusRow(int index) {
    final l10n = AppLocalizations.of(context);
    final b = _bonuses[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<PurchaseBonusType>(
              initialValue: b.bonusType,
              items: [
                for (final t in PurchaseBonusType.values)
                  DropdownMenuItem(value: t, child: Text(_bonusLabel(l10n, t))),
              ],
              onChanged: (v) => setState(() => b.bonusType = v ?? b.bonusType),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: '${b.quantityBase}',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.purchaseQty),
              onChanged: (v) => setState(() {
                b.quantityBase = int.tryParse(v.trim()) ?? b.quantityBase;
              }),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () => _pickBonusItem(index),
              icon: const Icon(Icons.search),
              label: Text(b.itemId == null
                  ? l10n.purchaseItemPlaceholder
                  : l10n.purchaseBonusItem),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _bonuses.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBonusItem(int index) async {
    final item = await _showItemSearchDialog(context);
    if (item == null || !mounted) return;
    setState(() => _bonuses[index].itemId = item.id);
  }

  String _bonusLabel(AppLocalizations l10n, PurchaseBonusType t) {
    return switch (t) {
      PurchaseBonusType.bonus_1 => l10n.purchaseBonus1,
      PurchaseBonusType.bonus_2 => l10n.purchaseBonus2,
      PurchaseBonusType.gift => l10n.purchaseBonusGift,
    };
  }
}