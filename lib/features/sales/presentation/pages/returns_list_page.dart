import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sections.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/units/package_cost.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_invoice.dart';
import '../../domain/entities/pos_return.dart';

/// Returns workspace inside sales, with two tabs:
///  • invoices — every sales invoice, auto-loaded in chronological order;
///    tapping one opens its detail where per-line returns are posted;
///  • returns — every recorded return document in one place.
/// Both lists load automatically on entry (no search tap needed); the lists
/// reload after mutations so voided/posted state is always fresh.
class ReturnsListPage extends ConsumerStatefulWidget {
  const ReturnsListPage({super.key});

  @override
  ConsumerState<ReturnsListPage> createState() => _ReturnsListPageState();
}

class _ReturnsListPageState extends ConsumerState<ReturnsListPage>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 30;

  late final TabController _tabs;

  // --- Invoices tab state ---
  int _invPage = 1;
  String _invQuery = '';
  PageResult<PosInvoiceView>? _invResult;
  bool _invLoading = false;
  Object? _invError;

  // --- Returns tab state ---
  int _page = 1;
  String _query = '';
  PageResult<PosReturnView>? _result;
  bool _loading = false;
  Object? _error;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      if (mounted) await _loadInvoices();
      if (mounted) await _load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices({bool isRetry = false}) async {
    setState(() {
      _invLoading = true;
      _invError = null;
    });
    try {
      final result = await ref.read(salesRepositoryProvider).searchSaleInvoices(
            PageRequest(
                page: _invPage, pageSize: _pageSize, search: _invQuery.trim()),
          );
      if (!mounted) return;
      setState(() {
        _invResult = result;
        _invLoading = false;
      });
    } catch (e) {
      // Same startup race as the returns list: retry once automatically.
      if (!isRetry && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) await _loadInvoices(isRetry: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _invError = e;
        _invLoading = false;
      });
    }
  }

  void _resetInvoicesAndReload() {
    _invPage = 1;
    _loadInvoices();
  }

  Future<void> _openInvoice(String invoiceId) async {
    await context.push(saleInvoiceDetailPath(invoiceId));
    // A return may have been posted from the detail — refresh both lists.
    if (mounted) {
      await _loadInvoices();
      await _load();
    }
  }

  Future<void> _load({bool isRetry = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(salesRepositoryProvider).listReturns(
            PageRequest(page: _page, pageSize: _pageSize, search: _query.trim()),
          );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      // The very first load can race app startup (database not open yet).
      // Retry once automatically so the list appears without any tap.
      if (!isRetry && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted) await _load(isRetry: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _resetAndReload() {
    _page = 1;
    _load();
  }

  Future<void> _openDetail(PosReturnView ret) async {
    final detail =
        await ref.read(salesRepositoryProvider).returnDetail(ret.id);
    if (!mounted || detail == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _ReturnDetailDialog(detail: detail),
    );
    if (mounted) await _load();
  }

  String _dateLabel(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.l,
            AppSpacing.xl,
            0,
          ),
          child: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: _l10n.salesHistoryTitle),
              Tab(text: _l10n.salesReturnsTitle),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildInvoicesTab(typography),
              _buildReturnsTab(typography),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab(AppTypography typography) {
    final invoices = _invResult?.items ?? const <PosInvoiceView>[];

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.m,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: SizedBox(
        width: 320,
        child: SearchField(
          hintText: _l10n.salesHistorySearchHint,
          onChanged: (q) {
            _invQuery = q.trim();
            _resetInvoicesAndReload();
          },
        ),
      ),
    );

    Widget body;
    if (_invLoading && _invResult == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_invError != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_invError'),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: _loadInvoices,
              child: Text(_l10n.commonRetry),
            ),
          ],
        ),
      );
    } else if (invoices.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48),
            const SizedBox(height: AppSpacing.s),
            Text(_l10n.salesHistoryEmpty),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.s,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        itemCount: invoices.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
        itemBuilder: (context, index) {
          final v = invoices[index];
          return _InvoiceCard(
            invoice: v,
            dateLabel: _dateLabel(v.createdAt),
            onTap: () => _openInvoice(v.id),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
        if (_invResult != null && _invResult!.pageCount > 1)
          _Pager(
            page: _invPage,
            pageCount: _invResult!.pageCount,
            onPage: (p) {
              setState(() => _invPage = p);
              _loadInvoices();
            },
          ),
      ],
    );
  }

  Widget _buildReturnsTab(AppTypography typography) {
    final items = _result?.items ?? const <PosReturnView>[];

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
          Text(_l10n.salesReturnsTitle, style: typography.pageTitle),
          SizedBox(
            width: 320,
            child: SearchField(
              hintText: _l10n.salesReturnsSearchHint,
              onChanged: (q) {
                _query = q.trim();
                _resetAndReload();
              },
            ),
          ),
        ],
      ),
    );

    Widget body;
    if (_loading && _result == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error'),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: _load,
              child: Text(_l10n.commonRetry),
            ),
          ],
        ),
      );
    } else if (items.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_return_outlined, size: 48),
            const SizedBox(height: AppSpacing.s),
            Text(_l10n.salesReturnsEmpty),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.s,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
        itemBuilder: (context, index) {
          final ret = items[index];
          return _ReturnCard(
            ret: ret,
            dateLabel: _dateLabel(ret.createdAt),
            onTap: () => _openDetail(ret),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
        if (_result != null && _result!.pageCount > 1)
          _Pager(
            page: _page,
            pageCount: _result!.pageCount,
            onPage: (p) {
              setState(() => _page = p);
              _load();
            },
          ),
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.dateLabel,
    required this.onTap,
  });

  final PosInvoiceView invoice;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: typography.sectionTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.customerName.isEmpty ? '—' : invoice.customerName}'
                      ' · $dateLabel',
                      style: typography.bodySecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                Money.fromUnits(invoice.totalMicros).formatArabicDigits(),
                style: typography.sectionTitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    required this.ret,
    required this.dateLabel,
    required this.onTap,
  });

  final PosReturnView ret;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_return_outlined),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ret.returnNumber,
                          style: typography.sectionTitle,
                        ),
                        if (ret.isVoided) ...[
                          const SizedBox(width: AppSpacing.s),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.salesReturnsVoided,
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.salesReturnsOriginalInvoice}: '
                      '${ret.originalInvoiceNumber}'
                      '${(ret.customerName?.isNotEmpty ?? false) ? ' · ${ret.customerName}' : ''}'
                      ' · $dateLabel',
                      style: typography.bodySecondary,
                    ),
                    if (ret.reason?.isNotEmpty ?? false)
                      Text(
                        '${l10n.salesReturnsReason}: ${ret.reason}',
                        style: typography.bodySecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                Money.fromUnits(ret.totalMicros).formatArabicDigits(),
                style: typography.sectionTitle.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: page > 1 ? () => onPage(page - 1) : null,
          ),
          Text('$page / $pageCount'),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: page < pageCount ? () => onPage(page + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _ReturnDetailDialog extends StatelessWidget {
  const _ReturnDetailDialog({required this.detail});

  final ({PosReturnView header, List<PosReturnLineView> lines}) detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final h = detail.header;
    return AlertDialog(
      title: Text('${l10n.salesReturnsTitle} ${h.returnNumber}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.salesReturnsOriginalInvoice}: ${h.originalInvoiceNumber}',
              style: typography.body,
            ),
            if (h.customerName?.isNotEmpty ?? false)
              Text(
                '${l10n.salesReturnsCustomer}: ${h.customerName}',
                style: typography.body,
              ),
            if (h.reason?.isNotEmpty ?? false)
              Text(
                '${l10n.salesReturnsReason}: ${h.reason}',
                style: typography.body,
              ),
            const SizedBox(height: AppSpacing.m),
            Text(l10n.salesReturnsLines, style: typography.label),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: detail.lines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final line = detail.lines[index];
                  return ListTile(
                    dense: true,
                    title: Text(line.itemName),
                    subtitle: Text(
                      '${l10n.salesReturnsQuantity}: ${formatBaseQuantity(line.quantityBase, line.unitsPerLarge)}'
                      '${(line.reason?.isNotEmpty ?? false) ? ' · ${line.reason}' : ''}',
                    ),
                    trailing: Text(
                      Money.fromUnits(line.amountMicros).formatArabicDigits(),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.salesReturnsTotal, style: typography.label),
                Text(
                  Money.fromUnits(h.totalMicros).formatArabicDigits(),
                  style: typography.sectionTitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
