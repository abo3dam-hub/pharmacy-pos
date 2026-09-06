import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/daos/purchase_dao.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/purchases_repository.dart';

/// Paginated invoice listing (`purchases.view`).
class ListPurchasesUseCase {
  const ListPurchasesUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<PurchaseInvoiceView>> call(
    PageRequest page, {
    String? supplierId,
    PurchaseStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.purchasesView);
    return _repo.search(page,
        supplierId: supplierId, status: status, fromDate: fromDate, toDate: toDate);
  }
}

/// Full invoice detail (`purchases.view`).
class GetPurchaseDetailUseCase {
  const GetPurchaseDetailUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseDetailView> call(
    String invoiceId, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.purchasesView);
    return _repo.detail(invoiceId);
  }
}

/// Creates a pending purchase invoice (`purchases.create`).
class CreatePurchaseUseCase {
  const CreatePurchaseUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseInvoiceRow> call(
    PurchaseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.purchasesCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.createPending(
      draft,
      actingUserId: actingUserId,
      actingRoleId: actingRoleId!,
    );
  }
}

/// Replaces lines/bonuses of a pending invoice (`purchases.edit`).
class UpdatePendingPurchaseUseCase {
  const UpdatePendingPurchaseUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseInvoiceRow> call(
    String invoiceId,
    PurchaseDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.purchasesEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.updatePending(
      invoiceId,
      draft,
      actingUserId: actingUserId,
      actingRoleId: actingRoleId!,
    );
  }
}

/// Receives an invoice and creates batches/stock (`purchases.edit`, §12).
class ReceivePurchaseUseCase {
  const ReceivePurchaseUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseInvoiceRow> call(
    String invoiceId, {
    required List<ReceiveLineInput> inputs,
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.purchasesEdit);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.receive(
      invoiceId,
      inputs: inputs,
      actingUserId: actingUserId,
      actingRoleId: actingRoleId!,
    );
  }
}

/// Cancels a pending invoice (`purchases.void`) — audited void operation.
class CancelPurchaseUseCase {
  const CancelPurchaseUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseInvoiceRow> call(
    String invoiceId, {
    String? actingUserId,
    String? actingRoleId,
    String? reason,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.purchasesVoid);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.cancel(
      invoiceId,
      actingUserId: actingUserId,
      actingRoleId: actingRoleId!,
      reason: reason,
    );
  }
}

/// Records a purchase return (`return`, §14). Requires the canonical returns
/// permission so staff able to issue customer returns can also send goods back.
class PurchaseReturnUseCase {
  const PurchaseReturnUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<PurchaseReturnOutcome> call(
    PurchaseReturnRequest request, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(db, actingRoleId, Perm.returnProducts);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    return _repo.recordReturn(request);
  }
}

/// Still-returnable quantity of a received purchase line (`purchases.view`).
class GetAvailableReturnQtyUseCase {
  const GetAvailableReturnQtyUseCase(this._repo, this._permissions);

  final PurchasesRepository _repo;
  final PermissionService _permissions;

  Future<int> call(
    String lineId, {
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.purchasesView);
    return _repo.availableToReturn(lineId);
  }
}