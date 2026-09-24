import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sections.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_rtl_icons.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/entities/pos_invoice.dart';

/// §18.4 permanent sales history — a searchable, filterable, paginated grid of
/// persisted sale invoices served by [SalesRepository.searchSaleInvoices].
///
/// Filters (status / payment / cashier / date range / free-text) are additive
/// and applied DB-side; tapping a row opens the invoice detail and the list
/// reloads when the user returns so post-return/void state is always fresh
/// (no timers — mutation-then-refresh only).
class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  static const int _pageSize = 30;

  int _page = 1;
  String _query = '';
  SaleStatus? _status;
  PaymentMethod? _paymentMethod;
  String? _cashierId;

  /// Inclusive range millis (null = open-ended).
  int? _fromMillis;
  int? _toMillis;

  List<({String id, String name})> _cashiers = const [];
  PageResult<PosInvoiceView>? _result;
  bool _loading = false;
  Object? _error;

  /// Invoices expanded inline to show their lines (items + prices) without
  /// opening the detail page — lets the pharmacist browse chronologically and
  /// identify an invoice for returns without knowing its number.
  final Set<String> _expandedIds = {};
  final Map<String, PosInvoiceView> _detailCache = {};
  final Set<String> _loadingDetails = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCashiers();
      if (mounted) await _load();
    });
  }

  Future<void> _loadCashiers() async {
    try {
      final users = await ref
          .read(userDaoProvider)
          .listUsers(const PageRequest(page: 1, pageSize: 1000));
      if (!mounted) return;
      setState(() {
        _cashiers = [
          for (final u in users.items)
            (
              id: u.id,
              name: (u.displayName.isEmpty) ? u.username : u.displayName,
            ),
        ];
      });
    } catch (_) {
      // Cashier filter is optional — the list still works without it.
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(salesRepositoryProvider)
          .searchSaleInvoices(
            PageRequest(
              page: _page,
              pageSize: _pageSize,
              search: _query.trim(),
            ),
            status: _status,
            paymentMethod: _paymentMethod,
            userId: _cashierId,
            fromMillis: _fromMillis,
            toMillis: _toMillis,
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetAndReload() {
    setState(() => _page = 1);
    _load();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _fromMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(_fromMillis!)
        : DateTime(now.year, now.month, now.day);
    final initialEnd = _toMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(_toMillis!)
        : initialStart;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromMillis = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ).millisecondsSinceEpoch;
      _toMillis = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;
    });
    _resetAndReload();
  }

  String _statusLabel(SaleStatus status) => switch (status) {
    SaleStatus.draft => _l10n.saleStatusDraft,
    SaleStatus.completed => _l10n.saleStatusCompleted,
    SaleStatus.partially_returned => _l10n.saleStatusPartiallyReturned,
    SaleStatus.fully_returned => _l10n.saleStatusFullyReturned,
    SaleStatus.voided => _l10n.saleStatusVoided,
  };

  String _paymentLabel(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => _l10n.posCashLabel,
    PaymentMethod.card => _l10n.posCardLabel,
    PaymentMethod.mixed => _l10n.posMixedLabel,
    PaymentMethod.credit => _l10n.posCreditLabel,
  };

  Future<void> _openDetail(String invoiceId) async {
    await context.push(saleInvoiceDetailPath(invoiceId));
    // Mutation-then-refresh: returns/voids inside the detail invalidate this
    // list, so reload the current page on return (§18.4 state invalidation).
    if (mounted) await _load();
  }

  Future<void> _toggleExpand(String invoiceId) async {
    if (_expandedIds.contains(invoiceId)) {
      setState(() => _expandedIds.remove(invoiceId));
      return;
    }
    setState(() {
      _expandedIds.add(invoiceId);
      _loadingDetails.add(invoiceId);
    });
    try {
      final detail = _detailCache[invoiceId] ??
          await ref.read(salesRepositoryProvider).invoiceViewById(invoiceId);
      if (!mounted) return;
      if (detail != null) _detailCache[invoiceId] = detail;
      setState(() => _loadingDetails.remove(invoiceId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDetails.remove(invoiceId);
        _expandedIds.remove(invoiceId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.m,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: SearchField(
              hintText: _l10n.salesHistorySearchHint,
              onChanged: (q) {
                _query = q.trim();
                _resetAndReload();
              },
            ),
          ),
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.m,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<SaleStatus?>(
                  value: _status,
                  hint: Text(_l10n.salesHistoryFilterStatus),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(_l10n.salesHistoryFilterStatus),
                    ),
                    for (final s in SaleStatus.values)
                      DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                  ],
                  onChanged: (s) {
                    setState(() => _status = s);
                    _resetAndReload();
                  },
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<PaymentMethod?>(
                  value: _paymentMethod,
                  hint: Text(_l10n.salesHistoryFilterPayment),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(_l10n.salesHistoryFilterPayment),
                    ),
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(value: m, child: Text(_paymentLabel(m))),
                  ],
                  onChanged: (m) {
                    setState(() => _paymentMethod = m);
                    _resetAndReload();
                  },
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _cashierId,
                  hint: Text(_l10n.salesHistoryFilterCashier),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(_l10n.salesHistoryFilterCashier),
                    ),
                    for (final c in _cashiers)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (id) {
                    setState(() => _cashierId = id);
                    _resetAndReload();
                  },
                ),
              ),
              TextButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_dateRangeLabel()),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: _error != null
              ? Center(child: Text('$_error', style: typography.labelSmall))
              : AppResponsiveLayout(
                  desktop: _buildTable(),
                  tablet: _buildTable(),
                  compact: _buildCards(typography),
                ),
        ),
        _buildPager(),
      ],
    );
  }

  String _dateRangeLabel() {
    if (_fromMillis == null && _toMillis == null) {
      return _l10n.zReportTo;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    String fmt(int millis) {
      final d = DateTime.fromMillisecondsSinceEpoch(millis);
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    }

    final from = _fromMillis != null ? fmt(_fromMillis!) : '…';
    final to = _toMillis != null ? fmt(_toMillis!) : '…';
    return '$from → $to';
  }

  Widget _buildTable() {
    final invoices = _result?.items ?? const <PosInvoiceView>[];
    if (invoices.isEmpty) {
      return Center(child: Text(_l10n.salesHistoryEmpty));
    }
    // Expandable invoice list: each invoice shows its lines (items + prices)
    // inline when expanded, so the pharmacist can browse chronologically and
    // identify an invoice for returns without knowing its number.
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      itemCount: invoices.length,
      itemBuilder: (context, index) => _invoiceCard(invoices[index]),
    );
  }

  Widget _invoiceCard(PosInvoiceView v) {
    final expanded = _expandedIds.contains(v.id);
    final detail = _detailCache[v.id];
    final loadingDetail = _loadingDetails.contains(v.id);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpand(v.id),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.invoiceNumber,
                          style: context.appTypography.invoiceNumber,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          v.customerName.isEmpty ? '—' : v.customerName,
                          style: context.appTypography.bodySecondary,
                        ),
                        Text(
                          v.userName,
                          style: context.appTypography.labelSmall,
                        ),
                        Text(
                          _fmtDate(v.createdAt),
                          style: context.appTypography.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Money.fromUnits(v.totalMicros).format(),
                        style: context.appTypography.numericStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _statusLabel(v.saleStatus),
                        style: context.appTypography.labelSmall,
                      ),
                      Text(
                        _paymentLabel(v.paymentMethod),
                        style: context.appTypography.labelSmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new),
                    tooltip: _l10n.salesHistoryOpenDetail,
                    onPressed: () => _openDetail(v.id),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.m,
                0,
                AppSpacing.m,
                AppSpacing.m,
              ),
              child: loadingDetail
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.m),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _invoiceLines(detail?.lines ?? v.lines),
            ),
        ],
      ),
    );
  }

  Widget _invoiceLines(List<PosInvoiceLineView> lines) {
    if (lines.isEmpty) {
      return Text(
        _l10n.salesHistoryNoLines,
        style: context.appTypography.labelSmall,
      );
    }
    return Column(
      children: [
        const Divider(height: 1),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    line.itemName,
                    style: context.appTypography.body,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.sellUnitQuantity != null
                        ? '${line.sellUnitQuantity} ${line.unitTypeName}'
                        : '${line.quantityBaseSigned}',
                    style: context.appTypography.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    Money.fromUnits(line.unitPriceMicros).format(),
                    style: context.appTypography.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  child: Text(
                    Money.fromUnits(line.lineTotalMicros).format(),
                    style: context.appTypography.numericStrong,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCards(AppTypography typography) {
    final invoices = _result?.items ?? const <PosInvoiceView>[];
    if (invoices.isEmpty) {
      return Center(
        child: Text(_l10n.salesHistoryEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final v in invoices) _invoiceCard(v),
      ],
    );
  }

  Widget _buildPager() {
    final total = _result?.total ?? 0;
    final pageCount = (total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.m,
                right: AppSpacing.m,
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Text(
            '$_page / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: _page <= 1
                ? null
                : () {
                    setState(() => _page -= 1);
                    _load();
                  },
            icon: Icon(AppDirectionalIcons.previous(context)),
            tooltip: _l10n.commonPrevious,
          ),
          IconButton(
            onPressed: _page >= pageCount || pageCount == 0
                ? null
                : () {
                    setState(() => _page += 1);
                    _load();
                  },
            icon: Icon(AppDirectionalIcons.next(context)),
            tooltip: _l10n.commonNext,
          ),
        ],
      ),
    );
  }

  String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
