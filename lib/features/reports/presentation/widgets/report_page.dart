import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import 'report_actions.dart';

/// Local `yyyy-MM-dd` used by report date columns and range labels.
String formatReportDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Start-of-day millis for the given local date (same helper as the statement
/// pages, so range filters stay day-aligned).
int reportDayMillis(DateTime d) =>
    DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

/// Convenience `Range<DateTime>` filters used by report pages internally.
({DateTime from, DateTime to}) reportTodayRange() {
  final now = DateTime.now();
  return (
    from: DateTime(now.year, now.month, now.day),
    to: now,
  );
}

/// Date-filter strip + refresh + export buttons reused by every report tab.
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.fromLabel,
    required this.toLabel,
    required this.onPickFrom,
    required this.onPickTo,
    this.extra = const [],
    this.onRefresh,
    this.onPrint,
    this.onExportExcel,
    this.exportEnabled = false,
  });

  final String fromLabel;
  final String? toLabel;
  final VoidCallback onPickFrom;
  final VoidCallback? onPickTo;
  final List<Widget> extra;
  final VoidCallback? onRefresh;
  final VoidCallback? onPrint;
  final VoidCallback? onExportExcel;
  final bool exportEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.m,
      runSpacing: AppSpacing.m,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onPickFrom,
          icon: const Icon(Icons.event_outlined),
          label: Text(fromLabel),
        ),
        if (toLabel != null)
          OutlinedButton.icon(
            onPressed: onPickTo,
            icon: const Icon(Icons.event_outlined),
            label: Text(toLabel!),
          ),
        ...extra,
        const SizedBox(width: AppSpacing.s),
        IconButton(
          tooltip: l10n.reportRefresh,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_outlined),
        ),
        ReportExportBar(
          enabled: exportEnabled,
          onPrint: onPrint,
          onSaveExcel: onExportExcel,
        ),
      ],
    );
  }
}

/// Body container that resolves the report state machine (loading / ready /
/// error) around the table content.
class ReportBody extends StatelessWidget {
  const ReportBody({
    super.key,
    this.loading = false,
    this.error,
    this.errorMessage,
    this.emptyMessage,
    this.child,
  });

  final bool loading;
  final Failure? error;
  final String? errorMessage;
  final String? emptyMessage;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(errorMessage!, style: context.appTypography.label),
        ),
      );
    }
    if (child == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(emptyMessage ?? '', style: context.appTypography.labelSmall),
        ),
      );
    }
    return child!;
  }
}

/// Full-page wrapper for a report tab: header strip + scrollable body,
/// matching the layout used by the account/customer statement pages.
class ReportPage extends StatelessWidget {
  const ReportPage({
    super.key,
    required this.title,
    required this.filters,
    required this.body,
    this.loading = false,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.l, AppSpacing.xl, AppSpacing.s),
  });

  final String title;
  final Widget filters;
  final Widget body;
  final bool loading;
  final Widget? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    return LoadingOverlay(
      visible: loading,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: typography.pageTitle),
                const SizedBox(height: AppSpacing.m),
                filters,
              ],
            ),
          ),
          Expanded(child: body),
          ?footer,
        ],
      ),
    );
  }
}

/// Convenience when a tab checks a permission gate before rendering.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.hasPermission,
    required this.child,
  });

  final bool hasPermission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (hasPermission) return child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(l10n.reportNoPermission, style: context.appTypography.label),
      ),
    );
  }
}