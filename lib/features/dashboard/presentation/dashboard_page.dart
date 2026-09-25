import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sections.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/di/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/dashboard_controller.dart';
import '../domain/entities/dashboard_snapshot.dart';

/// Real-data dashboard (§16): today's sales summary, inventory pulse and
/// activity feeds straight from the database.
///
/// Fit-to-screen contract: the dashboard never scrolls. It is a fixed
/// viewport layout — a compact KPI strip, an optional financial strip, and
/// a 2×2 grid of alert/activity cards. Each card shows only as many rows as
/// fit (adaptive, capped at 4) plus a "view all" link into the full list, so
/// every action stays reachable on any window size.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dashboardControllerProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final l10n = AppLocalizations.of(context);
    final snapshot = state.snapshot;
    final financialsVisible = ref
        .watch(authControllerProvider)
        .permissions
        .contains(Perm.reportsViewProfit);

    if (state.status == DashboardStatus.initial ||
        state.status == DashboardStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == DashboardStatus.error || snapshot == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.error?.message ?? l10n.dashboardError,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton(
              onPressed: () =>
                  ref.read(dashboardControllerProvider.notifier).load(),
              child: Text(l10n.dashboardRetry),
            ),
          ],
        ),
      );
    }

    final cards = <_KpiCard>[
      _KpiCard(
        label: l10n.dashboardDailySales,
        target: snapshot.todayTotalMicros.toDouble(),
        format: (v) => Money.fromUnits(v.round()).format(),
        icon: Icons.attach_money,
      ),
      _KpiCard(
        label: l10n.dashboardTodayOrders,
        target: snapshot.todayInvoiceCount.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.receipt_long,
      ),
      _KpiCard(
        label: l10n.dashboardProfitToday,
        target: snapshot.todayProfitMicros.toDouble(),
        format: (v) => Money.fromUnits(v.round()).format(),
        icon: Icons.trending_up,
      ),
      _KpiCard(
        label: l10n.dashboardUnitsSold,
        target: snapshot.todayUnitsSold.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.inventory_2,
      ),
      _KpiCard(
        label: l10n.dashboardActiveItems,
        target: snapshot.activeItems.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.inventory,
      ),
      _KpiCard(
        label: l10n.dashboardStockValue,
        target: snapshot.stockValueMicros.toDouble(),
        format: (v) => Money.fromUnits(v.round()).format(),
        icon: Icons.payments,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: Text(
              l10n.dashboardKpis,
              style: context.appTypography.sectionTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.m,
            children: [
              for (var i = 0; i < cards.length; i++)
                Entrance(delay: AppMotion.stagger * i, child: cards[i]),
            ],
          ),
          if (financialsVisible) ...[
            const SizedBox(height: AppSpacing.m),
            Entrance(
              delay: AppMotion.stagger * 2,
              child: _FinancialStrip(financials: snapshot.financials),
            ),
          ],
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Entrance(
                          delay: AppMotion.stagger * 3,
                          child: _AlertCard(
                            title: l10n.dashboardLowStock,
                            icon: Icons.warning_amber,
                            viewAllRoute: AppSection.inventory.path,
                            totalCount: snapshot.lowStockItems.length,
                            children: snapshot.lowStockItems.isEmpty
                                ? [_EmptyRow(label: l10n.dashboardLowStockEmpty)]
                                : [
                                    for (final row in snapshot.lowStockItems)
                                      _AlertRow(
                                        primary: row.name,
                                        secondary:
                                            '${Money.fromUnits(row.currentStockBase).format()} / '
                                            '${Money.fromUnits(row.minimumStockBase).format()}',
                                        icon: Icons.arrow_downward,
                                        iconColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                  ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Entrance(
                          delay: AppMotion.stagger * 3,
                          child: _AlertCard(
                            title: l10n.dashboardNearExpiry,
                            icon: Icons.update,
                            viewAllRoute: AppSection.inventory.path,
                            totalCount: snapshot.nearExpiryBatches.length,
                            children: snapshot.nearExpiryBatches.isEmpty
                                ? [
                                    _EmptyRow(
                                      label: l10n.dashboardNearExpiryEmpty,
                                    ),
                                  ]
                                : [
                                    for (final b in snapshot.nearExpiryBatches)
                                      _AlertRow(
                                        primary: b.itemName,
                                        secondary:
                                            '${_date(b.expiryDate)} · ${_qty(b.quantityBase)}',
                                        icon: Icons.event,
                                        iconColor: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                      ),
                                  ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Entrance(
                          delay: AppMotion.stagger * 4,
                          child: _AlertCard(
                            title: l10n.dashboardRecentSales,
                            icon: Icons.history,
                            viewAllRoute: salesHistoryPath(),
                            totalCount: snapshot.recentSales.length,
                            children: snapshot.recentSales.isEmpty
                                ? [
                                    _EmptyRow(
                                      label: l10n.dashboardRecentEmpty,
                                    ),
                                  ]
                                : [
                                    for (final r in snapshot.recentSales)
                                      _ActivityRow(
                                        primary: r.number,
                                        secondary: _time(r.atMillis),
                                        value: Money.fromUnits(
                                          r.totalMicros,
                                        ).format(),
                                      ),
                                  ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Entrance(
                          delay: AppMotion.stagger * 4,
                          child: _AlertCard(
                            title: l10n.dashboardRecentPurchases,
                            icon: Icons.local_shipping,
                            viewAllRoute: AppSection.purchases.path,
                            totalCount: snapshot.recentPurchases.length,
                            children: snapshot.recentPurchases.isEmpty
                                ? [
                                    _EmptyRow(
                                      label: l10n.dashboardRecentEmpty,
                                    ),
                                  ]
                                : [
                                    for (final r in snapshot.recentPurchases)
                                      _ActivityRow(
                                        primary: r.number,
                                        secondary: _time(r.atMillis),
                                        value: Money.fromUnits(
                                          r.totalMicros,
                                        ).format(),
                                      ),
                                  ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static String _time(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  static String _qty(int base) => Money.fromUnits(base).format();
}

/// Compact KPI card — fixed compact height so the strip never pushes the
/// grid off-screen.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.target,
    required this.format,
    required this.icon,
  });

  final String label;
  final double target;
  final String Function(double value) format;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final primary = theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        width: 190,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primary, primary.withValues(alpha: 0.72)],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: typography.bodySecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  CountUp(
                    target: target,
                    format: format,
                    style: typography.sectionTitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact one-row financial summary strip (replaces the tall card so the
/// dashboard fits without scrolling).
class _FinancialStrip extends StatelessWidget {
  const _FinancialStrip({required this.financials});

  final DashboardFinancials financials;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final metrics = <(String, String, bool)>[
      (
        l10n.reportIncomeSalesRevenue,
        Money.fromUnits(financials.revenueMicros).format(),
        false,
      ),
      (
        l10n.reportIncomeNetRevenue,
        Money.fromUnits(financials.netRevenueMicros).format(),
        false,
      ),
      (
        l10n.reportIncomeCogs,
        '-${Money.fromUnits(financials.cogsMicros).format()}',
        false,
      ),
      (
        l10n.reportIncomeGrossProfit,
        Money.fromUnits(financials.grossProfitMicros).format(),
        true,
      ),
      (
        l10n.reportIncomeNetIncome,
        Money.fromUnits(financials.netIncomeMicros).format(),
        true,
      ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        child: Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.dashboardFinancialSummary,
              style: typography.sectionTitle,
            ),
            for (final (label, value, emphasized) in metrics)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: typography.bodySecondary),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    value,
                    style: (emphasized
                            ? typography.sectionTitle
                            : typography.body)
                        .copyWith(
                          color: emphasized
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Alert/activity card that fits its viewport cell: shows only as many rows
/// as fit (adaptive, hard-capped at 4) and always keeps a "view all" footer
/// linking into the full list — nothing is reachable only by scrolling.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.viewAllRoute,
    required this.totalCount,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String viewAllRoute;
  final int totalCount;

  static const _maxRows = 4;
  static const _rowHeight = 48.0;
  // Fixed chrome heights (header row + spacing + view-all button).
  static const _headerHeight = 28.0;
  static const _buttonHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        // Measure first, then render only what fits: header + as many rows
        // as fit (hard-capped at 4) + the view-all button. On very short
        // viewports the button hides rather than overflowing.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            final chrome = _headerHeight + AppSpacing.s + _buttonHeight;
            final fits = ((maxH - chrome) / _rowHeight).floor().clamp(0, _maxRows);
            // Show the button only if header + button fit; rows are bonus.
            final showButton =
                maxH >= _headerHeight + AppSpacing.s + _buttonHeight;
            final showRows = maxH >= chrome;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        title,
                        style: typography.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s),
                if (showRows) ...children.take(fits),
                const Spacer(),
                if (showButton)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => context.go(viewAllRoute),
                      child: Text(
                        '${l10n.commonViewAll} ($totalCount)',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.iconColor,
  });

  final String primary;
  final String secondary;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  style: typography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  secondary,
                  style: typography.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.primary,
    required this.secondary,
    required this.value,
  });

  final String primary;
  final String secondary;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  style: typography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  secondary,
                  style: typography.bodySecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(value, style: typography.body),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // Fixed height matching _AlertCard._rowHeight so the adaptive row
    // count math holds for empty cards too.
    return SizedBox(
      height: 48,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: context.appTypography.bodySecondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
