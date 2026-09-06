import 'package:drift/drift.dart';

import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../data/daos/customer_dao.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/customer_repository.dart';

/// Drift-backed [CustomerRepository]. Balances are always derived from the
/// sales/return ledger and cached on `customers.balance_micros` (§25).
class CustomerRepositoryImpl implements CustomerRepository {
  const CustomerRepositoryImpl(this._db, this._dao);

  final AppDatabase _db;
  final CustomerDao _dao;

  @override
  AppDatabase get database => _db;

  @override
  Future<PageResult<CustomerRow>> search(PageRequest page) =>
      _dao.search(page);

  @override
  Future<CustomerRow?> findById(String id) => _dao.byId(id);

  @override
  Future<List<CustomerRow>> allActive() => _dao.all(activeOnly: true);

  @override
  Future<CustomerRow> create(CustomerDraft draft, {required String userId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = CustomerDao.newCustomerId();
    final row = CustomerRow(
      id: id,
      name: draft.name.trim(),
      phone: _nullable(draft.phone),
      secondaryPhone: _nullable(draft.secondaryPhone),
      email: _nullable(draft.email),
      address: _nullable(draft.address),
      hasAccount: draft.hasAccount,
      openingBalanceMicros: draft.openingBalanceMicros,
      balanceMicros: draft.openingBalanceMicros,
      creditLimitMicros: draft.creditLimitMicros,
      dateOfBirth: draft.dateOfBirth,
      gender: _nullable(draft.gender),
      medicalHistory: _nullable(draft.medicalHistory),
      taxVatNumber: _nullable(draft.taxVatNumber),
      notes: _nullable(draft.notes),
      isActive: draft.isActive,
      createdAt: now,
      updatedAt: now,
    );
    await _dao.insert(row);
    return row;
  }

  @override
  Future<CustomerRow> update(
    String id,
    CustomerDraft draft, {
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _dao.byId(id);
    if (existing == null) {
      throw NotFoundException('العميل غير موجود: $id');
    }
    final updated = existing.copyWith(
      name: draft.name.trim(),
      phone: Value<String?>(_nullable(draft.phone)),
      secondaryPhone: Value<String?>(_nullable(draft.secondaryPhone)),
      email: Value<String?>(_nullable(draft.email)),
      address: Value<String?>(_nullable(draft.address)),
      hasAccount: draft.hasAccount,
      openingBalanceMicros: draft.openingBalanceMicros,
      creditLimitMicros: draft.creditLimitMicros,
      dateOfBirth: Value<int?>(draft.dateOfBirth),
      gender: Value<String?>(_nullable(draft.gender)),
      medicalHistory: Value<String?>(_nullable(draft.medicalHistory)),
      taxVatNumber: Value<String?>(_nullable(draft.taxVatNumber)),
      notes: Value<String?>(_nullable(draft.notes)),
      isActive: draft.isActive,
      updatedAt: now,
    );
    await _dao.update(updated);
    // An opening-balance change shifts the derived balance immediately.
    await _dao.syncBalance(id, at: now);
    return (await _dao.byId(id))!;
  }

  @override
  Future<void> setActive(String id, bool active, {required String userId}) =>
      _dao.setActive(id, active,
          at: DateTime.now().millisecondsSinceEpoch);

  @override
  Future<void> setAccount(String id, bool enabled, {required String userId}) =>
      _dao.setAccount(id, enabled,
          at: DateTime.now().millisecondsSinceEpoch);

  @override
  Future<CustomerStatementPage> statement(
    String customerId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
  }) async {
    final customer = await _dao.byId(customerId);
    if (customer == null) {
      throw NotFoundException('العميل غير موجود: $customerId');
    }
    final offset = (page - 1) * pageSize;
    final raw = await _dao.statementPage(
      customerId,
      fromDate: fromDate,
      toDate: toDate,
      limit: pageSize,
      offset: offset,
    );
    final totals = await _dao.statementTotals(
      customerId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final entries = <CustomerStatementEntry>[];
    var run = totals.openingMicros;
    if (raw.isNotEmpty) {
      // Running balance before the page's first row (keyset, same ordering).
      run = await _dao.startBalanceMicros(
        customerId,
        date: raw.first.date,
        docType: raw.first.docType,
      );
    }
    if (offset == 0) {
      entries.add(CustomerStatementEntry(
        docType: 'opening',
        refNo: '',
        refId: customerId,
        date: 0,
        note: null,
        debitMicros: 0,
        creditMicros: 0,
        balanceMicros: totals.openingMicros,
      ));
    }
    for (final e in raw) {
      run += e.netMicros;
      entries.add(CustomerStatementEntry(
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
    return CustomerStatementPage(
      entries: entries,
      totals: totals,
      page: page,
      pageSize: pageSize,
      customerName: customer.name,
    );
  }

  String? _nullable(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}