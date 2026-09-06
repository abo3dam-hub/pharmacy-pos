import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/util/ids.dart';
import '../../../../data/daos/prescription_dao.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../../domain/repositories/prescription_repository.dart';

/// Drift-backed [PrescriptionRepository].
class PrescriptionRepositoryImpl implements PrescriptionRepository {
  const PrescriptionRepositoryImpl(this._db, this._dao);

  final AppDatabase _db;
  final PrescriptionDao _dao;

  @override
  AppDatabase get database => _db;

  @override
  Future<PageResult<PrescriptionListRow>> search(
    PageRequest page, {
    String? customerId,
  }) =>
      _dao.search(page, customerId: customerId);

  @override
  Future<PrescriptionRow?> findById(String id) => _dao.byId(id);

  @override
  Future<PrescriptionDetail?> detail(String id) => _dao.detail(id);

  @override
  Future<List<PrescriptionRow>> activeForCustomer(String customerId) =>
      _dao.activeForCustomer(customerId);

  @override
  Future<PrescriptionRow> create(
    PrescriptionDraft draft, {
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final customer = await _customerExists(draft.customerId);
    if (customer == null) {
      throw ValidationException('اختر عميلاً للوصفة الطبية — لا تُنشأ وصفات بدون مريض');
    }

    var totalMicros = 0;
    final itemRows = <PrescriptionItemRow>[];
    for (final line in draft.items) {
      if (line.quantityBase <= 0) {
        throw ValidationException('الكمية الأساسية للصنف يجب أن تكون أكبر من صفر');
      }
      final itemRow = await (_db.select(_db.items)
            ..where((i) => i.id.equals(line.itemId)))
          .getSingleOrNull();
      if (itemRow == null) {
        throw ValidationException('الصنف غير موجود في المخزون: ${line.itemId}');
      }
      totalMicros += line.quantityBase * itemRow.sellingPriceMicros;
      itemRows.add(
        PrescriptionItemRow(
          id: PrescriptionDao.newPrescriptionItemId(),
          prescriptionId: '',
          itemId: line.itemId,
          quantityBase: line.quantityBase,
          dosage: _nullable(line.dosage),
          frequency: _nullable(line.frequency),
          durationDays: line.durationDays,
          notes: _nullable(line.notes),
          isDispensed: false,
          dispensedQuantityBase: 0,
          createdAt: now,
        ),
      );
    }

    final id = newId('rx');
    final header = PrescriptionRow(
      id: id,
      prescriptionNumber: PrescriptionDao.newPrescriptionNumber(),
      customerId: draft.customerId,
      patientName: draft.patientName.trim(),
      patientAge: draft.patientAge,
      patientGender: _nullable(draft.patientGender),
      doctorName: _nullable(draft.doctorName),
      doctorSpecialty: _nullable(draft.doctorSpecialty),
      clinicHospital: _nullable(draft.clinicHospital),
      issuedAt: draft.issuedAt ?? now,
      expiryAt: draft.expiryAt,
      totalMicros: totalMicros,
      status: PrescriptionStatus.active,
      imagePath: _nullable(draft.imagePath),
      notes: _nullable(draft.notes),
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );
    final items = [
      for (final r in itemRows) _withPrescription(r, id, now),
    ];
    await _dao.insertWithItems(header, items);
    return header;
  }

  @override
  Future<PreparedSalePrescription> prepareForSale(String id) async {
    final detail = await _dao.detail(id);
    if (detail == null) {
      throw NotFoundException('الوصفة غير موجودة: $id');
    }
    if (detail.prescription.status != PrescriptionStatus.active) {
      throw ValidationException('الوصفة ليست نشطة ولا يمكن ربطها بالبيع');
    }
    if (detail.items.isEmpty) {
      throw ValidationException('الوصفة لا تحتوي على أصناف');
    }
    return PreparedSalePrescription(
      prescription: detail.prescription,
      customerName: detail.customerName,
      items: detail.items,
    );
  }

  Future<CustomerRow?> _customerExists(String id) => (_db.select(_db.customers)
        ..where((c) => c.id.equals(id)))
      .getSingleOrNull();

  static PrescriptionItemRow _withPrescription(
    PrescriptionItemRow row,
    String prescriptionId,
    int now,
  ) {
    return PrescriptionItemRow(
      id: row.id,
      prescriptionId: prescriptionId,
      itemId: row.itemId,
      quantityBase: row.quantityBase,
      dosage: row.dosage,
      frequency: row.frequency,
      durationDays: row.durationDays,
      notes: row.notes,
      isDispensed: false,
      dispensedQuantityBase: 0,
      createdAt: now,
    );
  }

  static String? _nullable(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}