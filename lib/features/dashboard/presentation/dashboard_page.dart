import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        Entrance(
          child: Text(
            l10n.dashboardKpis,
            style: context.appTypography.sectionTitle,
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        LayoutBuilder(
          builder: (context, constraints) {
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
            return Wrap(
              spacing: AppSpacing.m,
              runSpacing: AppSpacing.m,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Entrance(delay: AppMotion.stagger * i, child: cards[i]),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        if (financialsVisible) ...[
          Entrance(
            delay: AppMotion.stagger * 2,
            child: Text(
              l10n.reportIncomeStatement,
              style: context.appTypography.sectionTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Entrance(
            delay: AppMotion.stagger * 3,
            child: _FinancialSummaryCard(financials: snapshot.financials),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Entrance(
          delay: AppMotion.stagger * 3,
          child: _TwoColumnGrid(
            left: _AlertCard(
              title: l10n.dashboardLowStock,
              icon: Icons.warning_amber,
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
                          iconColor: Theme.of(context).colorScheme.error,
                        ),
                    ],
            ),
            right: _AlertCard(
              title: l10n.dashboardNearExpiry,
              icon: Icons.update,
              children: snapshot.nearExpiryBatches.isEmpty
                  ? [_EmptyRow(label: l10n.dashboardNearExpiryEmpty)]
                  : [
                      for (final b in snapshot.nearExpiryBatches)
                        _AlertRow(
                          primary: b.itemName,
                          secondary:
                              '${_date(b.expiryDate)} · ${_qty(b.quantityBase)}',
                          icon: Icons.event,
                          iconColor: Theme.of(context).colorScheme.tertiary,
                        ),
                    ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Entrance(
          delay: AppMotion.stagger * 4,
          child: _TwoColumnGrid(
            left: _AlertCard(
              title: l10n.dashboardRecentSales,
              icon: Icons.history,
              children: snapshot.recentSales.isEmpty
                  ? [_EmptyRow(label: l10n.dashboardRecentEmpty)]
                  : [
                      for (final r in snapshot.recentSales)
                        _ActivityRow(
                          primary: r.number,
                          secondary: _time(r.atMillis),
                          value: Money.fromUnits(r.totalMicros).format(),
                        ),
                    ],
            ),
            right: _AlertCard(
              title: l10n.dashboardRecentPurchases,
              icon: Icons.local_shipping,
              children: snapshot.recentPurchases.isEmpty
                  ? [_EmptyRow(label: l10n.dashboardRecentEmpty)]
                  : [
                      for (final r in snapshot.recentPurchases)
                        _ActivityRow(
                          primary: r.number,
                          secondary: _time(r.atMillis),
                          value: Money.fromUnits(r.totalMicros).format(),
                        ),
                    ],
            ),
          ),
        ),
      ],
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
        width: 260,
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primary, primary.withValues(alpha: 0.72)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: typography.bodySecondary),
                  const SizedBox(height: AppSpacing.xs),
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

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({required this.financials});

  final DashboardFinancials financials;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final typography = context.appTypography;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dashboardFinancialSummary,
              style: typography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.s),
            _FinancialRow(
              label: l10n.reportIncomeSalesRevenue,
              value: Money.fromUnits(financials.revenueMicros).format(),
            ),
            _FinancialRow(
              label: l10n.reportIncomeSalesReturns,
              value: Money.fromUnits(
                financials.revenueMicros - financials.netRevenueMicros,
              ).format(),
            ),
            _FinancialRow(
              label: l10n.reportIncomeNetRevenue,
              value: Money.fromUnits(financials.netRevenueMicros).format(),
            ),
            _FinancialRow(
              label: l10n.reportIncomeCogs,
              value: '-${Money.fromUnits(financials.cogsMicros).format()}',
            ),
            const Divider(height: AppSpacing.l),
            _FinancialRow(
              label: l10n.reportIncomeGrossProfit,
              value: Money.fromUnits(financials.grossProfitMicros).format(),
              emphasized: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            _FinancialRow(
              label: l10n.reportIncomeNetIncome,
              value: Money.fromUnits(financials.netIncomeMicros).format(),
              emphasized: true,
              accent: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final color = accent ?? Theme.of(context).colorScheme.onSurface;
    final style = emphasized ? typography.sectionTitle : typography.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: typography.bodySecondary)),
          Text(value, style: style.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: AppSpacing.l),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.l),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typography = context.appTypography;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: AppSpacing.s),
                Expanded(child: Text(title, style: typography.sectionTitle)),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            ...children,
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: typography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(secondary, style: typography.bodySecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: typography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(secondary, style: typography.bodySecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Text(label, style: context.appTypography.bodySecondary),
    );
  }
}
