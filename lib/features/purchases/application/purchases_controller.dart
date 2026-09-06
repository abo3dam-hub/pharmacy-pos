import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../data/daos/purchase_dao.dart';
import '../../../shared/models/enums.dart';
import '../domain/repositories/purchases_repository.dart';
import '../domain/usecases/purchases_use_cases.dart';

enum PurchasesStatus { initial, loading, ready, error }

/// Purchases page state: paginated invoice grid + filters.
class PurchasesViewState {
  const PurchasesViewState({
    this.status = PurchasesStatus.initial,
    this.invoices = const [],
    this.total = 0,
    this.request = const PageRequest(),
    this.supplierId,
    this.statusFilter,
    this.fromDate,
    this.toDate,
    this.error,
    this.busy = false,
  });

  final PurchasesStatus status;
  final List<PurchaseInvoiceView> invoices;
  final int total;
  final PageRequest request;
  final String? supplierId;
  final PurchaseStatus? statusFilter;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Failure? error;
  final bool busy;

  PurchasesViewState copyWith({
    PurchasesStatus? status,
    List<PurchaseInvoiceView>? invoices,
    int? total,
    PageRequest? request,
    String? Function()? supplierId,
    PurchaseStatus? Function()? statusFilter,
    DateTime? Function()? fromDate,
    DateTime? Function()? toDate,
    Failure? Function()? error,
    bool? busy,
  }) {
    return PurchasesViewState(
      status: status ?? this.status,
      invoices: invoices ?? this.invoices,
      total: total ?? this.total,
      request: request ?? this.request,
      supplierId: supplierId != null ? supplierId() : this.supplierId,
      statusFilter:
          statusFilter != null ? statusFilter() : this.statusFilter,
      fromDate: fromDate != null ? fromDate() : this.fromDate,
      toDate: toDate != null ? toDate() : this.toDate,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
    );
  }
}

/// Invoices grid controller (list/filter/pagination). Create/receive/cancel/
/// return run through the [PurchasesFeature] on form/detail pages.
class PurchasesController extends StateNotifier<PurchasesViewState> {
  PurchasesController(this._list, this._receive, this._cancel, this._create,
      this._update, this._return)
      : super(const PurchasesViewState());

  final ListPurchasesUseCase _list;
  final ReceivePurchaseUseCase _receive;
  final CancelPurchaseUseCase _cancel;
  final CreatePurchaseUseCase _create;
  final UpdatePendingPurchaseUseCase _update;
  final PurchaseReturnUseCase _return;

  Future<Failure?> load({
    String search = '',
    int page = 1,
    String? supplierId,
    PurchaseStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    String? actingRoleId,
  }) async {
    final request = PageRequest(
        page: page, pageSize: state.request.pageSize, search: search);
    state = state.copyWith(
        status: PurchasesStatus.loading,
        supplierId: () => supplierId,
        statusFilter: () => status,
        fromDate: () => fromDate,
        toDate: () => toDate,
        error: null);
    try {
      final result = await _list(
        request,
        supplierId: supplierId,
        status: status,
        fromDate: fromDate,
        toDate: toDate,
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
        status: PurchasesStatus.ready,
        invoices: result.items,
        total: result.total,
        request: result.request,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
          status: PurchasesStatus.error, error: () => e.failure);
      return state.error;
    }
  }

  Future<Failure?> create(
    PurchaseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    try {
      await _create(draft, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    }
  }

  Future<Failure?> updatePending(
    String invoiceId,
    PurchaseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    try {
      await _update(invoiceId, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    }
  }

  Future<Failure?> receive(
    String invoiceId, {
    required List<ReceiveLineInput> inputs,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _receive(invoiceId,
          inputs: inputs, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> cancel(
    String invoiceId, {
    String? actingUserId,
    String? actingRoleId,
    String? reason,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _cancel(invoiceId,
          actingUserId: actingUserId, actingRoleId: actingRoleId, reason: reason);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<Failure?> recordReturn(
    PurchaseReturnRequest request, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await _return(request, actingUserId: actingUserId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      return e.failure;
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}