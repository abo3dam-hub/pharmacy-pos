import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/prescriptions_controller.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §4.12 prescriptions list — reusable in the customers section tab and as the
/// standalone `/customers` sub-section. Rows are joined with the customer name;
/// rows show the header summary and open the detail page.
class PrescriptionsList extends ConsumerStatefulWidget {
  const PrescriptionsList({super.key, this.customerId});

  /// When set, only this customer's prescriptions are loaded (وصفات العميل).
  final String? customerId;

  @override
  ConsumerState<PrescriptionsList> createState() => _PrescriptionsListState();
}

class _PrescriptionsListState extends ConsumerState<PrescriptionsList> {
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.prescriptionsView)) {
        ref
            .read(prescriptionsControllerProvider.notifier)
            .load(
              customerId: widget.customerId,
              actingRoleId: auth.actingRoleId,
            );
      }
    });
  }

  bool get _canCreate =>
      ref.read(authControllerProvider).permissions.contains(Perm.prescriptionsCreate);
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  String _message(Failure failure) =>
      failureMessage(AppLocalizations.of(context), failure);

  Future<void> _load({String search = ''}) async {
    final failure = await ref
        .read(prescriptionsControllerProvider.notifier)
        .load(
          search: search,
          customerId: widget.customerId,
          actingRoleId: _actingRoleId,
        );
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_message(failure))));
    }
  }

  void _toPage(int page) {
    final state = ref.read(prescriptionsControllerProvider);
    final pageCount = (state.total / _pageSize).ceil();
    if (page < 1 || page > (pageCount == 0 ? 1 : pageCount)) return;
    ref
        .read(prescriptionsControllerProvider.notifier)
        .load(page: page, actingRoleId: _actingRoleId);
  }

  void _openNew() => context.pushNamed('prescription-new');

  void _openDetail(String id) => context.pushNamed(
        'prescription-detail',
        pathParameters: {'id': id},
      );

  String _statusLabel(AppLocalizations l10n, PrescriptionStatus status) {
    return switch (status) {
      PrescriptionStatus.active => l10n.prescriptionStatusActive,
      PrescriptionStatus.partially_dispensed =>
        l10n.prescriptionStatusPartiallyDispensed,
      PrescriptionStatus.dispensed => l10n.prescriptionStatusDispensed,
      PrescriptionStatus.expired => l10n.prescriptionStatusExpired,
      PrescriptionStatus.cancelled => l10n.prescriptionStatusCancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(prescriptionsControllerProvider);
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
              hintText: l10n.prescriptionsSearchHint,
              onChanged: (q) => _load(search: q),
            ),
          ),
          if (_canCreate)
            FilledButton.icon(
              onPressed: _openNew,
              icon: const Icon(Icons.medical_services_outlined),
              label: Text(l10n.prescriptionAdd),
            ),
        ],
      ),
    );

    return LoadingOverlay(
      visible: state.status == PrescriptionsStatus.loading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: state.status == PrescriptionsStatus.error
                ? Center(
                    child: Text(l10n.commonError, style: typography.labelSmall),
                  )
                : AppResponsiveLayout(
                    desktop: _table(l10n, state),
                    tablet: _table(l10n, state),
                    compact: _cards(l10n, state, typography),
                  ),
          ),
          _pager(l10n, state.request.page, state.total),
        ],
      ),
    );
  }

  Widget _pager(AppLocalizations l10n, int page, int total) {
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
          Text(
            '$page / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: page <= 1 ? null : () => _toPage(page - 1),
            icon: Icon(AppDirectionalIcons.previous(context)),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(page + 1),
            icon: Icon(AppDirectionalIcons.next(context)),
            tooltip: l10n.commonNext,
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

  Widget _table(AppLocalizations l10n, PrescriptionsViewState state) {
    final typography = context.appTypography;
    return AppDataTable(
      emptyMessage: l10n.prescriptionsEmpty,
      columns: [
        DataColumn(label: Text(l10n.prescriptionNumber)),
        DataColumn(label: Text(l10n.prescriptionCustomer)),
        DataColumn(label: Text(l10n.prescriptionPatientName)),
        DataColumn(label: Text(l10n.prescriptionIssuedAt)),
        DataColumn(label: Text(l10n.commonTotal)),
        DataColumn(label: Text(l10n.prescriptionStatus)),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final p in state.rows)
          DataRow(
            onSelectChanged: (_) => _openDetail(p.row.id),
            cells: [
              DataCell(Text(p.row.prescriptionNumber)),
              DataCell(Text(p.customerName)),
              DataCell(Text(p.row.patientName)),
              DataCell(Text(_fmtDate(p.row.issuedAt))),
              DataCell(
                Text(
                  Money.fromUnits(p.row.totalMicros).format(),
                  style: typography.numeric,
                ),
              ),
              DataCell(Text(_statusLabel(l10n, p.row.status))),
              DataCell(
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                      width: 32, height: 32),
                  icon: Icon(AppDirectionalIcons.drillIn(context)),
                  tooltip: l10n.prescriptionDetail,
                  onPressed: () => _openDetail(p.row.id),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _cards(
    AppLocalizations l10n,
    PrescriptionsViewState state,
    AppTypography typography,
  ) {
    if (state.rows.isEmpty) {
      return Center(
        child: Text(l10n.prescriptionsEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final p in state.rows)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: InkWell(
              onTap: () => _openDetail(p.row.id),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.row.prescriptionNumber,
                            style: typography.sectionTitle,
                          ),
                        ),
                        Text(
                          _statusLabel(l10n, p.row.status),
                          style: typography.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      '${p.customerName} · ${p.row.patientName} · '
                      '${_fmtDate(p.row.issuedAt)}',
                      style: typography.bodySecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}