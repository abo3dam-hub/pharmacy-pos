import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/pdf/pdf_arabic.dart';
import '../../../../core/pdf/pdf_documents.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/z_report.dart';

/// End-of-shift summary (Z-Report) for a chosen period, printable as a PDF via
/// [ZReportPdfService]. Requires `reports.view_sales` (router redirect).
class ZReportPage extends ConsumerStatefulWidget {
  const ZReportPage({super.key});

  @override
  ConsumerState<ZReportPage> createState() => _ZReportPageState();
}

class _ZReportPageState extends ConsumerState<ZReportPage> {
  late DateTime _from;
  late DateTime _to;
  ZReport? _report;

  @override
  void initState() {
    super.initState();
    _setToday();
    // Load today's period immediately so the report opens populated rather
    // than sitting in the pre-load empty state until the user acts (§33).
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _setToday() {
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day);
    _to = _from.add(const Duration(days: 1));
  }

  Future<void> _load() async {
    final dao = ref.read(zReportDaoProvider);
    final report = await dao.aggregate(
      fromMillis: _from.millisecondsSinceEpoch,
      toMillis: _to.millisecondsSinceEpoch,
    );
    if (mounted) setState(() => _report = report);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to.subtract(const Duration(days: 1))),
      locale: Localizations.localeOf(context),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end.add(const Duration(days: 1));
      _report = null;
    });
    await _load();
  }

  Future<void> _print() async {
    final report = _report;
    if (report == null) return;
    final pharmacy = await ref.read(settingsDaoProvider).getString(
          pharmacyNameSettingKey,
        ) ??
        pharmacyFallbackName();
    try {
      await ZReportPdfService().print(report, pharmacy);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).posPrintFailed)));
    }
  }

  int get _window =>
      (_to.millisecondsSinceEpoch - _from.millisecondsSinceEpoch) ~/ 86400000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final window = _window;
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.zReportTitle),
        actions: [
          IconButton(
            tooltip: l10n.zReportPrint,
            onPressed: _report == null ? null : () async => _print(),
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Wrap(
                spacing: AppSpacing.m,
                runSpacing: AppSpacing.m,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickRange(),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${l10n.zReportFrom} ${_fmt(_from)} '
                      '${l10n.zReportTo} ${_fmt(_to.subtract(const Duration(days: 1)))}'
                      '${window != 1 ? '  ($window ${l10n.zReportDays})' : ''}',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _report == null ? null : () async => _print(),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(l10n.zReportPrint),
                  ),
                ],
              ),
            ),
            Expanded(
              child: report == null
                  ? const Center(child: SizedBox.shrink())
                  : report.invoiceCount == 0
                      ? _EmptyPeriod(message: l10n.zReportEmptyPeriod)
                      : _ReportBody(report: report),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final ZReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.l, 0, AppSpacing.l, AppSpacing.l),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: l10n.zReportSalesSummary,
                rows: [
                  _Row(l10n.zReportInvoicesCount, '${report.invoiceCount}'),
                  _Row(l10n.zReportUnitsSold, '${report.unitsSold}'),
                  _Row(l10n.commonSubtotal, _m(report.subtotalMicros)),
                  if (report.discountMicros != 0)
                    _Row(l10n.commonDiscount,
                        '-${_m(report.discountMicros)}'),
                  if (report.vatMicros != 0)
                    _Row(l10n.commonTax, _m(report.vatMicros)),
                  _Row(l10n.zReportTotalSales, _m(report.totalMicros),
                      bold: true),
                  _Row(l10n.zReportCash, _m(report.cashMicros)),
                  _Row(l10n.zReportCard, _m(report.cardMicros)),
                  _Row(l10n.zReportCredit, _m(report.creditMicros)),
                  _Row(l10n.commonPaid, _m(report.paidMicros)),
                  _Row(l10n.commonChange, _m(report.changeMicros)),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              _SectionCard(
                title: l10n.zReportReturnsSection,
                rows: [
                  _Row(
                    l10n.zReportReturnsBrief,
                    '${report.returnsCount} / ${_m(report.returnsTotalMicros)}',
                  ),
                  _Row(
                    l10n.zReportVoidsBrief,
                    '${report.voidCount} / ${_m(report.voidTotalMicros)}',
                  ),
                  _Row(l10n.zReportCustomerCollected,
                      _m(report.customerPaidMicros)),
                  _Row(l10n.zReportCustomerRefunded,
                      _m(report.customerRefundMicros)),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              _SectionCard(
                title: l10n.zReportDrawerSection,
                rows: [
                  _Row(l10n.zReportDrawerOpening, _m(report.drawerOpeningMicros)),
                  _Row(l10n.zReportDrawerNet, _m(report.drawerNetMovesMicros)),
                  _Row(
                    l10n.zReportDrawerExpected,
                    _m(report.expectedClosingMicros),
                  ),
                  _Row(l10n.zReportDrawerLedger, _m(report.lastRemainingMicros)),
                  if (report.drawerDeclaredCloseMicros != null) ...[
                    _Row(l10n.zReportDrawerDeclared,
                        _m(report.drawerDeclaredCloseMicros!)),
                    _Row(l10n.zReportDrawerDiff,
                        _m(report.drawerDifferenceMicros ?? 0)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _m(int micros) => Money.fromUnits(micros).formatArabicDigits();
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.appTypography.sectionTitle),
            const SizedBox(height: AppSpacing.s),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.label,
                        style: row.bold
                            ? context.appTypography.numericStrong
                            : context.appTypography.body),
                    Text(row.value,
                        style: row.bold
                            ? context.appTypography.numericStrong
                            : context.appTypography.numeric),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;
}

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.m),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTypography.body,
            ),
          ],
        ),
      ),
    );
  }
}