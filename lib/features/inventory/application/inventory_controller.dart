import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../../shared/database/app_database.dart';
import '../domain/entities/inventory_item.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/usecases/batches_use_cases.dart';
import '../domain/usecases/bulk_use_cases.dart';
import '../domain/usecases/create_item.dart';
import '../domain/usecases/excel_use_cases.dart';
import '../domain/usecases/list_items.dart';
import '../domain/usecases/set_item_active.dart';
import '../domain/usecases/stock_use_cases.dart';
import '../domain/usecases/update_item.dart';

enum InventoryStatus { initial, loading, ready, error }

/// Items grid view state (§22).
class InventoryViewState {
  const InventoryViewState({
    this.status = InventoryStatus.initial,
    this.items = const [],
    this.total = 0,
    this.request = const PageRequest(),
    this.onlyActive,
    this.selectedIds = const {},
    this.error,
    this.busy = false,
    this.batches = const [],
    this.movements = const [],
    this.batchOf,
    this.importReport,
  });

  final InventoryStatus status;
  final List<InventoryItemView> items;
  final int total;
  final PageRequest request;
  final bool? onlyActive;
  final Set<String> selectedIds;
  final Failure? error;
  final bool busy;

  /// Batch ledger view for the currently open item.
  final List<BatchRow> batches;
  final List<StockMovementRow> movements;
  final String? batchOf;
  final ImportSummary? importReport;

  String get search => request.search;
  int get page => request.page;
  bool get hasSelection => selectedIds.isNotEmpty;

  InventoryViewState copyWith({
    InventoryStatus? status,
    List<InventoryItemView>? items,
    int? total,
    PageRequest? request,
    bool? onlyActive,
    Set<String>? selectedIds,
    Failure? Function()? error,
    bool? busy,
    List<BatchRow>? batches,
    List<StockMovementRow>? movements,
    String? Function()? batchOf,
    ImportSummary? Function()? importReport,
  }) {
    return InventoryViewState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      request: request ?? this.request,
      onlyActive: onlyActive ?? this.onlyActive,
      selectedIds: selectedIds ?? this.selectedIds,
      error: error != null ? error() : this.error,
      busy: busy ?? this.busy,
      batches: batches ?? this.batches,
      movements: movements ?? this.movements,
      batchOf: batchOf != null ? batchOf() : this.batchOf,
      importReport: importReport != null ? importReport() : this.importReport,
    );
  }
}

/// Items grid controller: paging/filtering, selection, bulk ops, batch entry,
/// stock adjustment, Excel import/export — all delegated to audited use cases.
class InventoryController extends StateNotifier<InventoryViewState> {
  InventoryController(
    this._listItems,
    this._createItem,
    this._updateItem,
    this._setItemActive,
    this._addBatch,
    this._voidBatch,
    this._listBatches,
    this._adjustStock,
    this._bulk,
    this._exportItems,
    this._importItems,
  ) : super(const InventoryViewState());

  final ListItemsUseCase _listItems;
  final CreateItemUseCase _createItem;
  final UpdateItemUseCase _updateItem;
  final SetItemActiveUseCase _setItemActive;
  final AddBatchUseCase _addBatch;
  final VoidBatchUseCase _voidBatch;
  final ListBatchesUseCase _listBatches;
  final AdjustStockUseCase _adjustStock;
  final BulkUpdateItemsUseCase _bulk;

  /// Number of rows touched by the most recent bulk operation (used by the
  /// items grid success toast, which may exceed the original selection when a
  /// catalog-wide price scope was requested).
  int lastBulkUpdatedCount = 0;
  final ExportItemsUseCase _exportItems;
  final ImportItemsUseCase _importItems;

  Future<Failure?> load({
    String search = '',
    int page = 1,
    bool? onlyActive,
    String? actingRoleId,
  }) async {
    state = state.copyWith(
        status: InventoryStatus.loading,
        error: () => null,
        onlyActive: onlyActive ?? state.onlyActive);
    try {
      final result = await _listItems.call(
        PageRequest(page: page, search: search, pageSize: 30),
        actingRoleId: actingRoleId,
      );
      state = state.copyWith(
        status: InventoryStatus.ready,
        items: result.items,
        total: result.total,
        request: result.request,
        selectedIds: const {},
        // Any in-flight mutation (create/update/setActive/bulk) clears here
        // after its mandatory reload lands; without this the LoadingOverlay
        // never disappears because `busy` stays true forever on success.
        busy: false,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(status: InventoryStatus.error, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> reload({String? actingRoleId}) => load(
        search: state.search,
        page: state.page,
        onlyActive: state.onlyActive,
        actingRoleId: actingRoleId,
      );

  void clearError() => state = state.copyWith(error: () => null);

  void toggleSelection(String id) {
    final next = {...state.selectedIds};
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(selectedIds: next);
  }

  void clearSelection() => state = state.copyWith(selectedIds: const {});

  Future<Failure?> createItem(
    ItemDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _createItem.call(draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reload(actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> setActive(
    String id,
    bool active, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _setItemActive.call(id, active,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reload(actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> updateItem(
    String id,
    ItemDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _updateItem.call(id, draft,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reload(actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> addBatch(
    AddBatchInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _addBatch.call(input,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reloadBatches(input.itemId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> voidBatch(
    String id, {
    String? itemId,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _voidBatch.call(id,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      if (itemId != null) await reloadBatches(itemId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> adjustStock(
    StockAdjustInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      await _adjustStock.call(input,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reloadBatches(input.itemId, actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> bulk(
    BulkUpdateInput input, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      final updated = await _bulk.call(
          input, actingUserId: actingUserId, actingRoleId: actingRoleId);
      await reload(actingRoleId: actingRoleId);
      lastBulkUpdatedCount = updated;
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> loadBatches(
    String itemId, {
    String? actingRoleId,
  }) async {
    state = state.copyWith(
        busy: true, error: () => null, batchOf: () => itemId);
    try {
      final result =
          await _listBatches.call(itemId, actingRoleId: actingRoleId);
      state = state.copyWith(
        busy: false,
        batches: result.batches,
        movements: result.movements,
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }

  Future<Failure?> reloadBatches(String itemId, {String? actingRoleId}) =>
      loadBatches(itemId, actingRoleId: actingRoleId);

  Future<List<int>?> exportExcel({String? actingRoleId}) async {
    state = state.copyWith(busy: true, error: () => null);
    try {
      final bytes = await _exportItems.call(actingRoleId: actingRoleId);
      state = state.copyWith(busy: false);
      return bytes;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return null;
    }
  }

  Future<Failure?> importExcel(
    List<int> bytes, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    state = state.copyWith(
        busy: true, error: () => null, importReport: () => null);
    try {
      final report = await _importItems.call(bytes,
          actingUserId: actingUserId, actingRoleId: actingRoleId);
      state = state.copyWith(busy: false, importReport: () => report);
      await reload(actingRoleId: actingRoleId);
      return null;
    } on AppException catch (e) {
      state = state.copyWith(busy: false, error: () => e.failure);
      return e.failure;
    }
  }
}