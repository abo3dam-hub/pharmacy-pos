import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_return.dart';

/// Clear, easy returns list inside sales — every recorded return document
/// (number, date, original invoice, customer, total, reason, status) in one
/// place. Tapping a row opens the return detail; the list reloads on return
/// so voided/posted state is always fresh (mutation-then-refresh, no timers).
class ReturnsListPage extends ConsumerStatefulWidget {
  const ReturnsListPage({super.key});

  @override
  ConsumerState<ReturnsListPage> createState() => _ReturnsListPageState();
}

class _ReturnsListPageState extends ConsumerState<ReturnsListPage> {
  static const int _pageSize = 30;

  int _page = 1;
  String _query = '';
  PageResult<PosReturnView>? _result;
  bool _loading = false;
  Object? _error;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted) await _load();
    });
  }

  Future<void> _load() async {
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
                      '${l10n.salesReturnsQuantity}: ${line.quantityBase}'
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
