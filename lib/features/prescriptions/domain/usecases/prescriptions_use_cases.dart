import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/daos/prescription_dao.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/prescription_repository.dart';

/// Paginated prescription listing (`prescriptions.view`), optionally scoped to
/// a single customer (وصفات العميل).
class ListPrescriptionsUseCase {
  const ListPrescriptionsUseCase(this._repo, this._permissions);

  final PrescriptionRepository _repo;
  final PermissionService _permissions;

  Future<PageResult<PrescriptionListRow>> call(
    PageRequest page, {
    String? customerId,
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.prescriptionsView);
    return _repo.search(page, customerId: customerId);
  }
}

/// Creates a prescription with its item lines (`prescriptions.create`) and
/// audits the creation (§17). The customer is mandatory — no orphan
/// prescriptions; quantity is authoritative in base units (§7).
class CreatePrescriptionUseCase {
  const CreatePrescriptionUseCase(this._repo, this._permissions, this._audit);

  final PrescriptionRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<PrescriptionRow> call(
    PrescriptionDraft draft, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.prescriptionsCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }
    _validate(draft);
    final created = await _repo.create(draft, userId: actingUserId);
    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.create,
      entityType: 'prescription',
      entityId: created.id,
      after: prescriptionAuditJson(created, draft.items.length),
      note: 'إضافة وصفة ${created.prescriptionNumber} للمريض: ${created.patientName}',
    );
    return created;
  }
}

/// Full prescription detail (`prescriptions.view`) — header, customer name and
/// item lines.
class GetPrescriptionDetailUseCase {
  const GetPrescriptionDetailUseCase(this._repo, this._permissions);

  final PrescriptionRepository _repo;
  final PermissionService _permissions;

  Future<PrescriptionDetail?> call(String id, {String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.prescriptionsView);
    return _repo.detail(id);
  }
}

/// Active prescriptions lookup for a customer (`prescriptions.view`) — what the
/// POS (Phase 6) lists when attaching a prescription to a sale.
class CustomerActivePrescriptionsUseCase {
  const CustomerActivePrescriptionsUseCase(this._repo, this._permissions);

  final PrescriptionRepository _repo;
  final PermissionService _permissions;

  Future<List<PrescriptionRow>> call(String customerId,
      {String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.prescriptionsView);
    return _repo.activeForCustomer(customerId);
  }
}

/// Builds the Phase-6-ready prescription→sale snapshot without building the
/// POS: validates the prescription is active and carries lines, then hands the
/// POS a customer + item list it can attach. Gated by view permissions.
class PreparePrescriptionForSaleUseCase {
  const PreparePrescriptionForSaleUseCase(this._repo, this._permissions);

  final PrescriptionRepository _repo;
  final PermissionService _permissions;

  Future<PreparedSalePrescription> call(String id, {String? actingRoleId}) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.prescriptionsView);
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.customersView);
    return _repo.prepareForSale(id);
  }
}

void _validate(PrescriptionDraft draft) {
  if (draft.customerId.trim().isEmpty) {
    throw ValidationException('يجب اختيار عميل للوصفة الطبية');
  }
  if (draft.patientName.trim().isEmpty) {
    throw ValidationException('اسم المريض مطلوب');
  }
  if (draft.items.isEmpty) {
    throw ValidationException('يجب إضافة صنف واحد على الأقل للوصفة');
  }
}

/// Compact stable JSON projection for the audit trail (§17).
Map<String, Object?> prescriptionAuditJson(PrescriptionRow row, int itemCount) =>
    {
      'prescription_number': row.prescriptionNumber,
      'customer_id': row.customerId,
      'patient_name': row.patientName,
      'doctor_name': row.doctorName,
      'status': row.status.name,
      'item_count': itemCount,
      'total_micros': row.totalMicros,
    };