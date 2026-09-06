import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_invoice.dart';

/// §5 invoice/receipt view — read-only persisted sale invoice. Printing is a
/// documented Phase-7 limitation (no PDF pipeline yet).
class PosInvoicePage extends ConsumerStatefulWidget {
  const PosInvoicePage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<PosInvoicePage> createState() => _PosInvoicePageState();
}

class _PosInvoicePageState extends ConsumerState<PosInvoicePage> {
  late Future<PosInvoiceView?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(salesRepositoryProvider).invoiceViewById(widget.invoiceId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.posInvoiceTitle),
        actions: [
          IconButton(
            tooltip: l10n.posPrintReceipt,
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('الطباعة غير متاحة في هذه النسخة')),
                );
            },
            icon: const Icon(Icons.print_outlined),
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
          return _InvoiceBody(invoice: invoice);
        },
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice});

  final PosInvoiceView invoice;

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
                  child: DataTable(
                    headingRowHeight: AppLayoutTokens.tableHeaderHeight,
                    dataRowMinHeight: AppLayoutTokens.tableRowHeight,
                    columns: [
                      DataColumn(label: Text(l10n.posLineItem)),
                      DataColumn(label: Text(l10n.posLineQty)),
                      DataColumn(label: Text(l10n.posLineUnitPrice)),
                      DataColumn(label: Text(l10n.posLineDiscount)),
                      DataColumn(label: Text(l10n.posLineTotal)),
                    ],
                    rows: [
                      for (final line in invoice.lines)
                        DataRow(cells: [
                          DataCell(Text(line.itemName)),
                          DataCell(Text('${line.quantityBaseSigned}')),
                          DataCell(Text(
                              Money.fromUnits(line.unitPriceMicros).formatArabicDigits(),
                              style: context.appTypography.numericStrong)),
                          DataCell(Text(
                            line.lineDiscountMicros > 0
                                ? Money.fromUnits(line.lineDiscountMicros)
                                    .formatArabicDigits()
                                : '-',
                          )),
                          DataCell(Text(
                            Money.fromUnits(line.lineTotalMicros)
                                .formatArabicDigits(),
                            style: context.appTypography.numericStrong,
                          )),
                        ]),
                    ],
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
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});

  final PosInvoiceView invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = DateTime.fromMillisecondsSinceEpoch(invoice.createdAt);
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
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
        Text('${l10n.posSaleDate}: $date',
            style: context.appTypography.bodySecondary),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.invoice});

  final PosInvoiceView invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int micros,
      {bool bold = false}) {
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