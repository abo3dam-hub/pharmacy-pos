import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../data/daos/prescription_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/enums.dart';
import '../../application/prescriptions_controller.dart';
import '../../../../core/widgets/app_rtl_icons.dart';

/// §4.12 prescription detail: header, items and the Phase-6 "prepare for sale"
/// lookup. Routed at `/customers/prescriptions/detail/:id`.
class PrescriptionDetailPage extends ConsumerStatefulWidget {
  const PrescriptionDetailPage({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  ConsumerState<PrescriptionDetailPage> createState() =>
      _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState
    extends ConsumerState<PrescriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authControllerProvider);
      if (auth.permissions.contains(Perm.prescriptionsView)) {
        await ref
            .read(prescriptionsControllerProvider.notifier)
            .loadDetail(widget.prescriptionId, actingRoleId: auth.actingRoleId);
      }
    });
  }

  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _prepareForSale() async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(prescriptionsControllerProvider.notifier)
        .prepareForSale(widget.prescriptionId, actingRoleId: _actingRoleId);
    if (!mounted) return;
    if (failure == null) {
      final prepared = ref.read(prescriptionsControllerProvider).prepared;
      if (prepared != null && prepared.isReady) {
        _showSnack(l10n.prescriptionPreparedMessage);
      } else {
        _showSnack(l10n.prescriptionCannotPrepare);
      }
    } else {
      _showSnack(switch (failure) {
        UnauthorizedFailure() => l10n.authPermissionDenied,
        _ => l10n.authSaveError,
      });
    }
  }

  String _fmtDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

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
    final detail = state.detail;

    return LoadingOverlay(
      visible: state.detailLoading || state.busy,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.l,
              AppSpacing.xl,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(AppDirectionalIcons.back(context)),
                  tooltip: l10n.commonBack,
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    detail?.prescription.prescriptionNumber ?? '',
                    style: typography.pageTitle,
                  ),
                ),
                if (detail != null)
                  FilledButton.icon(
                    onPressed: _prepareForSale,
                    icon: const Icon(Icons.link),
                    label: Text(l10n.prescriptionPrepareForSale),
                  ),
              ],
            ),
          ),
          Expanded(
            child: detail == null
                ? Center(
                    child: Text(l10n.prescriptionsEmpty,
                        style: typography.labelSmall),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.s,
                      AppSpacing.xl,
                      AppSpacing.l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _headerCard(l10n, typography, detail),
                        const SizedBox(height: AppSpacing.m),
                        _itemsTable(l10n, typography, detail),
                        if (state.prepared != null)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.m),
                            child: _preparedCard(l10n, typography, state),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(
    AppLocalizations l10n,
    AppTypography typography,
    PrescriptionDetail detail,
  ) {
    final r = detail.prescription;

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 180,
              child: Text(label, style: typography.bodySecondary),
            ),
            Expanded(child: Text(value, style: typography.body)),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.l,
              runSpacing: AppSpacing.s,
              children: [
                Text(
                  '${l10n.prescriptionStatus}: ',
                  style: typography.bodySecondary,
                ),
                Text(_statusLabel(l10n, r.status), style: typography.body),
                Text(
                  '${l10n.commonTotal}: ${Money.fromUnits(r.totalMicros).format()}',
                  style: typography.numericStrong,
                ),
              ],
            ),
            const Divider(height: AppSpacing.l),
            row(l10n.prescriptionCustomer, detail.customerName),
            row(l10n.prescriptionPatientName, r.patientName),
            if (r.patientAge != null)
              row(l10n.prescriptionPatientAge, '${r.patientAge}'),
            if (r.patientGender != null)
              row(
                l10n.prescriptionPatientGender,
                r.patientGender == 'male'
                    ? l10n.customerGenderMale
                    : l10n.customerGenderFemale,
              ),
            if (r.doctorName != null)
              row(l10n.prescriptionDoctorName, r.doctorName!),
            if (r.doctorSpecialty != null)
              row(l10n.prescriptionDoctorSpecialty, r.doctorSpecialty!),
            if (r.clinicHospital != null)
              row(l10n.prescriptionClinicHospital, r.clinicHospital!),
            row(l10n.prescriptionIssuedAt, _fmtDate(r.issuedAt)),
            if (r.expiryAt != null)
              row(l10n.prescriptionExpiryAt, _fmtDate(r.expiryAt!)),
            if (r.imagePath != null && r.imagePath!.isNotEmpty)
              row(l10n.prescriptionImagePath, r.imagePath!),
            if (r.notes != null && r.notes!.isNotEmpty)
              row(l10n.prescriptionNotes, r.notes!),
          ],
        ),
      ),
    );
  }

  Widget _itemsTable(
    AppLocalizations l10n,
    AppTypography typography,
    PrescriptionDetail detail,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.prescriptionItems, style: typography.sectionTitle),
            const SizedBox(height: AppSpacing.m),
            Column(
              children: [
                for (final it in detail.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(it.itemTradeName,
                              style: typography.body),
                        ),
                        Expanded(
                          child: Text(
                            '${it.quantityBase} × '
                            '${Money.fromUnits(it.unitPriceMicros).format()}',
                            style: typography.bodySecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.prescriptionDosage}: '
                            '${it.dosage ?? '-'}',
                            style: typography.bodySecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Money.fromUnits(
                                    it.quantityBase * it.unitPriceMicros)
                                .format(),
                            style: typography.numeric,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preparedCard(
    AppLocalizations l10n,
    AppTypography typography,
    PrescriptionsViewState state,
  ) {
    final prepared = state.prepared!;
    return Card(
      margin: EdgeInsets.zero,
      color: prepared.isReady
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Text(
          prepared.isReady
              ? l10n.prescriptionPreparedMessage
              : l10n.prescriptionCannotPrepare,
          style: typography.body,
        ),
      ),
    );
  }
}