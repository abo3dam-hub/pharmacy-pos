import 'package:drift/drift.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/supplier_repository.dart';

/// Drift-backed [SupplierRepository]. Balances are always derived from the
/// purchase/return ledger and cached on `suppliers.balance_micros` (§25).
class SupplierRepositoryImpl implements SupplierRepository {
  const SupplierRepositoryImpl(this._db, this._dao);

  final AppDatabase _db;
  final SupplierDao _dao;

  @override
  AppDatabase get database => _db;

  @override
  Future<PageResult<SupplierRow>> search(PageRequest page) =>
      _dao.search(page);

  @override
  Future<SupplierRow?> findById(String id) => _dao.byId(id);

  @override
  Future<List<SupplierRow>> allActive() => _dao.all(activeOnly: true);

  @override
  Future<SupplierRow> create(SupplierDraft draft, {required String userId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = SupplierDao.newSupplierId();
    final row = SupplierRow(
      id: id,
      name: draft.name.trim(),
      code: draft.code?.trim().isEmpty ?? true ? null : draft.code!.trim(),
      phone: _nullable(draft.phone),
      secondaryPhone: _nullable(draft.secondaryPhone),
      email: _nullable(draft.email),
      address: _nullable(draft.address),
      contactPerson: _nullable(draft.contactPerson),
      taxVatNumber: _nullable(draft.taxVatNumber),
      licenseRegistration: _nullable(draft.licenseRegistration),
      openingBalanceMicros: draft.openingBalanceMicros,
      balanceMicros: draft.openingBalanceMicros,
      creditLimitMicros: draft.creditLimitMicros,
      notes: _nullable(draft.notes),
      isActive: draft.isActive,
      createdAt: now,
      updatedAt: now,
    );
    await _dao.insert(row);
    return row;
  }

  @override
  Future<SupplierRow> update(
    String id,
    SupplierDraft draft, {
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _dao.byId(id);
    if (existing == null) {
      throw NotFoundException('المورد غير موجود: $id');
    }
    final updated = existing.copyWith(
      name: draft.name.trim(),
      code: Value<String?>(draft.code?.trim().isEmpty ?? true ? null : draft.code!.trim()),
      phone: Value<String?>(_nullable(draft.phone)),
      secondaryPhone: Value<String?>(_nullable(draft.secondaryPhone)),
      email: Value<String?>(_nullable(draft.email)),
      address: Value<String?>(_nullable(draft.address)),
      contactPerson: Value<String?>(_nullable(draft.contactPerson)),
      taxVatNumber: Value<String?>(_nullable(draft.taxVatNumber)),
      licenseRegistration: Value<String?>(_nullable(draft.licenseRegistration)),
      openingBalanceMicros: draft.openingBalanceMicros,
      creditLimitMicros: draft.creditLimitMicros,
      notes: Value<String?>(_nullable(draft.notes)),
      isActive: draft.isActive,
      updatedAt: now,
    );
    await _dao.update(updated);
    return updated;
  }

  @override
  Future<void> setActive(String id, bool active, {required String userId}) =>
      _dao.setActive(id, active,
          at: DateTime.now().millisecondsSinceEpoch);

  @override
  Future<PageResult<SupplierBalanceRow>> balances(PageRequest page) =>
      _dao.balances(page);

  @override
  Future<SupplierStatementPage> statement(
    String supplierId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
  }) async {
    final supplier = await _dao.byId(supplierId);
    if (supplier == null) {
      throw NotFoundException('المورد غير موجود: $supplierId');
    }
    final offset = (page - 1) * pageSize;
    final raw = await _dao.statementPage(
      supplierId,
      fromDate: fromDate,
      toDate: toDate,
      limit: pageSize,
      offset: offset,
    );
    final totals = await _dao.statementTotals(
      supplierId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final entries = <SupplierStatementEntry>[];
    var run = totals.openingMicros;
    if (raw.isNotEmpty) {
      // Running balance before the page's first row (keyset, same ordering).
      run = await _dao.startBalanceMicros(
        supplierId,
        date: raw.first.date,
        docType: raw.first.docType,
      );
    }
    if (offset == 0) {
      entries.add(SupplierStatementEntry(
        docType: 'opening',
        refNo: '',
        refId: supplierId,
        date: 0,
        note: null,
        debitMicros: 0,
        creditMicros: 0,
        balanceMicros: totals.openingMicros,
      ));
    }
    for (final e in raw) {
      run += e.netMicros;
      entries.add(SupplierStatementEntry(
        docType: e.docType,
        refNo: e.refNo,
        refId: e.refId,
        date: e.date,
        note: e.note,
        debitMicros: e.debitMicros,
        creditMicros: e.creditMicros,
        balanceMicros: run,
      ));
    }
    return SupplierStatementPage(
      entries: entries,
      totals: totals,
      page: page,
      pageSize: pageSize,
      supplierName: supplier.name,
    );
  }

  String? _nullable(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}