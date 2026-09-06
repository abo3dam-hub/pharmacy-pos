import '../../../../data/daos/supplier_dao.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../shared/database/app_database.dart';

/// Input draft for creating/updating a supplier (§4.10). Money is integer
/// micro-units (scale 4) — never REAL (§23).
class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.code,
    this.phone,
    this.secondaryPhone,
    this.email,
    this.address,
    this.contactPerson,
    this.taxVatNumber,
    this.licenseRegistration,
    this.openingBalanceMicros = 0,
    this.creditLimitMicros = 0,
    this.notes,
    this.isActive = true,
  });

  final String name;
  final String? code;
  final String? phone;
  final String? secondaryPhone;
  final String? email;
  final String? address;
  final String? contactPerson;
  final String? taxVatNumber;
  final String? licenseRegistration;
  final int openingBalanceMicros;
  final int creditLimitMicros;
  final String? notes;
  final bool isActive;
}

/// Supplies supplier domain data; implementation maps to the Drift [SupplierRow].
abstract interface class SupplierRepository {
  /// Database handle for RBAC checks in use cases.
  AppDatabase get database;

  /// Paginated master search (`suppliers.view`).
  Future<PageResult<SupplierRow>> search(PageRequest page);

  Future<SupplierRow?> findById(String id);

  /// Active suppliers for dropdowns / purchase form.
  Future<List<SupplierRow>> allActive();

  /// Creates the supplier and clears its balance cache to the opening amount.
  Future<SupplierRow> create(SupplierDraft draft, {required String userId});

  /// Updates editable master fields; balance stays ledger-derived.
  Future<SupplierRow> update(String id, SupplierDraft draft,
      {required String userId});

  Future<void> setActive(String id, bool active, {required String userId});

  /// Paginated derived balances (ledger summary, §25).
  Future<PageResult<SupplierBalanceRow>> balances(PageRequest page);

  /// One page of a supplier's statement with running balances (كشف حساب).
  Future<SupplierStatementPage> statement(
    String supplierId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
  });
}

/// A page of a supplier's statement plus the summary footer.
class SupplierStatementPage {
  const SupplierStatementPage({
    required this.entries,
    required this.totals,
    required this.page,
    required this.pageSize,
    required this.supplierName,
  });

  final List<SupplierStatementEntry> entries;
  final SupplierLedgerTotals totals;
  final int page;
  final int pageSize;
  final String supplierName;
}