import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/money/money.dart';
import '../../../../core/pdf/pdf_arabic.dart';
import '../../../../core/pdf/pdf_documents.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/entities/pos_invoice.dart';
import '../../domain/repositories/sales_repository.dart';

/// §5/§18.4 invoice/receipt view — persisted sale invoice with status,
/// payment, cashier and per-line sale mode, printable as a PDF and actionable
/// (line returns + void) through the existing sale/return services.
class PosInvoicePage extends ConsumerStatefulWidget {
  const PosInvoicePage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<PosInvoicePage> createState() => _PosInvoicePageState();
}

class _PosInvoicePageState extends ConsumerState<PosInvoicePage> {
  late Future<PosInvoiceView?> _future;
  PosInvoiceView? _invoice;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PosInvoiceView?> _load() async {
    final value = await ref
        .read(salesRepositoryProvider)
        .invoiceViewById(widget.invoiceId);
    if (mounted) _invoice = value;
    return value;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _printInvoice() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final pharmacy =
        await ref.read(settingsDaoProvider).getString(pharmacyNameSettingKey) ??
        pharmacyFallbackName();
    try {
      await InvoicePdfService().print(invoice, pharmacy);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).posPrintFailed)),
        );
    }
  }

  bool _has(String code) =>
      ref.read(authControllerProvider).permissions.contains(code);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _returnLine(PosInvoiceLineView line) async {
    final l10n = AppLocalizations.of(context);
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final returnable = line.returnableBase;
    if (returnable <= 0) return;
    final qtyController = TextEditingController(text: '$returnable');
    final reasonController = TextEditingController();
    final requested = await showDialog<({int qty, String? reason})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.posReturnButton} — ${line.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.posReturnableQuantity,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(labelText: l10n.posReturnReason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              if (qty <= 0 || qty > returnable) {
                ScaffoldMessenger.of(ctx)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l10n.posOverReturnBlocked)),
                  );
                return;
              }
              Navigator.of(ctx).pop((
                qty: qty,
                reason: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
              ));
            },
            child: Text(l10n.posReturnButton),
          ),
        ],
      ),
    );
    if (requested == null || !mounted) return;

    setState(() => _mutating = true);
    try {
      final returnNumber = await ref
          .read(salesRepositoryProvider)
          .nextReturnNumber();
      await ref
          .read(salesRepositoryProvider)
          .returnSaleLine(
            PosReturnCommand(
              returnNumber: returnNumber,
              originalInvoiceItemId: line.id,
              quantityBase: requested.qty,
              userId: userId,
              reason: requested.reason,
            ),
          );
      _showMessage(l10n.posReturnSuccess);
      await _reload();
    } on AppException catch (e) {
      _showMessage(e.failure.message);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _voidInvoice() async {
    final l10n = AppLocalizations.of(context);
    final invoice = _invoice;
    if (invoice == null || !invoice.isVoidable) return;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.posVoidInvoice),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.posVoidInvoiceConfirm),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.posVoidReason),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.posVoidInvoice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutating = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .voidInvoice(
            invoice.id,
            userId: userId,
            reason: reasonController.text.trim().isEmpty
                ? 'إلغاء من فاتورة البيع'
                : reasonController.text.trim(),
          );
      _showMessage(l10n.posInvoiceVoided);
      await _reload();
    } on AppException catch (e) {
      _showMessage(e.failure.message);
    } on Exception catch (_) {
      _showMessage(l10n.posVoidInvoiceFailed);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoice = _invoice;
    final canReturn = _has(Perm.salesReturnCreate) || _has(Perm.returnProducts);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.posInvoiceTitle),
        actions: [
          IconButton(
            tooltip: l10n.posPrintReceipt,
            onPressed: invoice == null || _mutating
                ? null
                : () async {
                    await _printInvoice();
                  },
            icon: const Icon(Icons.print_outlined),
          ),
          if (invoice != null && invoice.isVoidable && _has(Perm.salesVoid))
            IconButton(
              tooltip: l10n.posVoidInvoice,
              onPressed: _mutating ? null : _voidInvoice,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: FutureBuilder<PosInvoiceView?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final invoice = snapshot.data;
          if (invoice == null) {
            return Center(child: Text(l10n.posNoInvoices));
          }
          return _InvoiceBody(
            invoice: invoice,
            canReturn: canReturn,
            onReturnLine: _returnLine,
          );
        },
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({
    required this.invoice,
    required this.canReturn,
    required this.onReturnLine,
  });

  final PosInvoiceView invoice;
  final bool canReturn;
  final void Function(PosInvoiceLineView line) onReturnLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(invoice: invoice),
              const SizedBox(height: AppSpacing.m),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: AppLayoutTokens.tableHeaderHeight,
                      dataRowMinHeight: AppLayoutTokens.tableRowHeight,
                      columns: [
                        DataColumn(label: Text(l10n.posLineItem)),
                        DataColumn(label: Text(l10n.posLineQty)),
                        DataColumn(label: Text(l10n.posSaleModeLabel)),
                        DataColumn(label: Text(l10n.posLineUnitPrice)),
                        DataColumn(label: Text(l10n.posLineDiscount)),
                        DataColumn(label: Text(l10n.posLineTotal)),
                        if (canReturn) DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final line in invoice.lines)
                          DataRow(
                            cells: [
                              DataCell(Text(line.itemName)),
                              DataCell(
                                Text(
                                  line.sellUnitQuantity != null
                                      ? '${line.sellUnitQuantity} ${line.unitTypeName}'
                                      : '${line.quantityBaseSigned}',
                                ),
                              ),
                              DataCell(Text(_saleModeLabel(l10n, line))),
                              DataCell(
                                Text(
                                  Money.fromUnits(
                                    line.unitPriceMicros,
                                  ).formatArabicDigits(),
                                  style: context.appTypography.numericStrong,
                                ),
                              ),
                              DataCell(
                                Text(
                                  line.lineDiscountMicros > 0
                                      ? Money.fromUnits(
                                          line.lineDiscountMicros,
                                        ).formatArabicDigits()
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  Money.fromUnits(
                                    line.lineTotalMicros,
                                  ).formatArabicDigits(),
                                  style: context.appTypography.numericStrong,
                                ),
                              ),
                              if (canReturn) ...[
                                DataCell(
                                  line.returnableBase > 0
                                      ? IconButton(
                                          tooltip: l10n.posReturnButton,
                                          icon: const Icon(Icons.undo_outlined),
                                          onPressed: () => onReturnLine(line),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              _TotalsCard(invoice: invoice),
            ],
          ),
        ),
      ),
    );
  }

  String _saleModeLabel(AppLocalizations l10n, PosInvoiceLineView line) {
    if (line.isPackageSale) return l10n.posSaleModePackage;
    if (line.isPartialSale) return l10n.posSaleModePart;
    return line.unitTypeName;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final PosInvoiceView invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = DateTime.fromMillisecondsSinceEpoch(invoice.createdAt);
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    final remaining = invoice.totalMicros - invoice.paidMicros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(invoice.invoiceNumber, style: context.appTypography.invoiceNumber),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${l10n.posCustomerLabel}: '
          '${invoice.customerName.isEmpty ? '—' : invoice.customerName}',
          style: context.appTypography.body,
        ),
        Text(
          '${l10n.posSaleDate}: $date',
          style: context.appTypography.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InfoChip(
              label: '${l10n.posStatusLabel}: ${_saleStatusName(l10n)}',
            ),
            _InfoChip(label: '${l10n.posPaymentLabel}: ${_paymentName(l10n)}'),
            _InfoChip(
              label:
                  '${l10n.posCashierLabel}: '
                  '${invoice.userName.isEmpty ? '—' : invoice.userName}',
            ),
            if (remaining > 0)
              _InfoChip(
                label:
                    '${l10n.posCreditRemaining}: '
                    '${Money.fromUnits(remaining).formatArabicDigits()}',
              ),
          ],
        ),
      ],
    );
  }

  String _saleStatusName(AppLocalizations l10n) => switch (invoice.saleStatus) {
    SaleStatus.draft => l10n.saleStatusDraft,
    SaleStatus.completed => l10n.saleStatusCompleted,
    SaleStatus.partially_returned => l10n.saleStatusPartiallyReturned,
    SaleStatus.fully_returned => l10n.saleStatusFullyReturned,
    SaleStatus.voided => l10n.saleStatusVoided,
  };

  String _paymentName(AppLocalizations l10n) => switch (invoice.paymentMethod) {
    PaymentMethod.cash => l10n.posCashLabel,
    PaymentMethod.card => l10n.posCardLabel,
    PaymentMethod.mixed => l10n.posMixedLabel,
    PaymentMethod.credit => l10n.posCreditLabel,
  };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label, style: context.appTypography.labelSmall),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice});

  final PosInvoiceView invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = invoice.totalMicros - invoice.paidMicros;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            _row(context, l10n.commonSubtotal, invoice.subtotalMicros),
            if (invoice.discountTotalMicros > 0)
              _row(context, l10n.commonDiscount, -invoice.discountTotalMicros),
            if (invoice.vatTotalMicros > 0)
              _row(context, l10n.commonTax, invoice.vatTotalMicros),
            const Divider(),
            _row(context, l10n.posTotalLabel, invoice.totalMicros, bold: true),
            _row(context, l10n.commonPaid, invoice.paidMicros),
            _row(context, l10n.commonChange, invoice.changeMicros),
            if (remaining > 0)
              _row(context, l10n.posCreditRemaining, remaining),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int micros, {
    bool bold = false,
  }) {
    final style = bold
        ? context.appTypography.numericStrong.copyWith(fontSize: 18)
        : context.appTypography.numeric;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Money.fromUnits(micros).formatArabicDigits(), style: style),
        ],
      ),
    );
  }
}
