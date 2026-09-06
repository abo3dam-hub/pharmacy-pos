import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../data/daos/prescription_dao.dart';
import '../domain/repositories/prescription_repository.dart';
import '../domain/usecases/prescriptions_use_cases.dart';

enum PrescriptionsStatus { initial, loading, ready, error }

/// Prescriptions page state: searchable/paginated grid, detail view and the
/// Phase-6-ready sale snapshot.
class PrescriptionsViewState {
  const PrescriptionsViewState({
    this.status = PrescriptionsStatus.initial,
    this.rows = const [],
    this.total = 0,
    this.request = const PageRequest(),
    this.customerId,
    this.detail,
    this.detailLoading = false,
    this.prepared,
    this.prepareError,
    this.error,
    this.busy = false,
  });

  final PrescriptionsStatus status;

  /// Prescription rows joined with their customer name.
  final List<PrescriptionListRow> rows;
  final int total;
  final PageRequest request;

  /// Optional customer scope for the وصفات العميل view.
  final String? customerId;

  final PrescriptionDetail? detail;
  final bool detailLoading;

  /// Phase-6 sale snapshot produced by "prepare for sale".
  final PreparedSalePrescription? prepared;
  final Failure? prepareError;

  final Failure? error;
  final bool busy;

  PrescriptionsViewState copyWith({
    PrescriptionsStatus? status,
    List<PrescriptionListRow>? rows,
    int? total,
    PageRequest? request,
    String? Function()? customerId,
    PrescriptionDetail? Function()? detail,
    bool? detailLoading,
    PreparedSalePrescription? Function()? prepared,
    Failure? Function()? prepareError,
    Failure? Function()? error,
    bool? busy,
  }) {
    return PrescriptionsViewState(
      status: status ?? this.status,
      rows: rows ?? this.rows,
      total: total ?? this.total,
      request: request ?? this.request,
      customerId: customerId != null ? customerId() : this.customerId,
      detail: detail != null ? detail() : this.detail,
      detailLoading: detailLoading ?? this.detailLoading,
      prepared: prepared != null ? prepared() : this.prepared,
      prepareError: prepareError != null ? prepareError() : this.prepareError,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Prescriptions controller: listing, create, detail and the sale-preparation
/// lookup. Permissions run in the use cases; failures surface as [Failure].
class PrescriptionsController extends StateNotifier<PrescriptionsViewState> {
  PrescriptionsController(
    this._list,
    this._create,
    this._detail,
    this._prepare,
  ) : super(const PrescriptionsViewState());

  final ListPrescriptionsUseCase _list;
  final CreatePrescriptionUseCase _create;
  final GetPrescriptionDetailUseCase _detail;
  final PreparePrescriptionForSaleUseCase _prepare;

  Future<Failure?> load({
    String search = '',
    String? customerId,
    int page = 1,
    String? actingRoleId,
  }) async {
    final request = PageRequest(
        page: page, pageSize: state.request.pageSize, search: search);
    state = state.copyWith(
      status: PrescriptionsStatus.loading,
      error: null,
      customerId: () => customerId,
    );
    try {
      final result = await _list(request,
          customerId: customerId, actingRoleId: actingRoleId);
      state = state.copyWith(
        status: PrescriptionsStatus.ready,
        rows: result.items,
        total: result.total,
        request: result.request,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: PrescriptionsStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> create(
    PrescriptionDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _create(draft, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> loadDetail(String id, {String? actingRoleId}) async {
    state = state.copyWith(detailLoading: true, error: null, prepared: null);
    try {
      final detail = await _detail(id, actingRoleId: actingRoleId);
      state = state.copyWith(detail: () => detail, detailLoading: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(detailLoading: false, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> prepareForSale(String id, {String? actingRoleId}) async {
    state = state.copyWith(busy: true, prepareError: null, prepared: null);
    try {
      final prepared = await _prepare(id, actingRoleId: actingRoleId);
      state = state.copyWith(prepared: () => prepared, busy: false);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, prepareError: () => e.failure);
      return e.failure;
    }
  }
}