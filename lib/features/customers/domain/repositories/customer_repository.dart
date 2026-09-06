import '../../../../core/data_grid/page_request.dart';
import '../../../../data/daos/customer_dao.dart';
import '../../../../shared/database/app_database.dart';

/// Input draft for creating/updating a customer/patient (§4.11). Money is
/// integer micro-units (scale 4) — never REAL (§23).
class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone,
    this.secondaryPhone,
    this.email,
    this.address,
    this.notes,
    this.hasAccount = false,
    this.openingBalanceMicros = 0,
    this.creditLimitMicros = 0,
    this.dateOfBirth,
    this.gender,
    this.medicalHistory,
    this.taxVatNumber,
    this.isActive = true,
  });

  final String name;
  final String? phone;
  final String? secondaryPhone;
  final String? email;
  final String? address;
  final String? notes;

  /// 1 = credit/account allowed (§4.11).
  final bool hasAccount;
  final int openingBalanceMicros;
  final int creditLimitMicros;
  final int? dateOfBirth;
  final String? gender;
  final String? medicalHistory;
  final String? taxVatNumber;
  final bool isActive;
}

/// Supplies customer domain data; implementation maps to the Drift
/// [CustomerRow]. Balances are always derived from the sales ledger (§25).
abstract interface class CustomerRepository {
  /// Database handle for RBAC checks in use cases.
  AppDatabase get database;

  /// Paginated master search (`customers.view`).
  Future<PageResult<CustomerRow>> search(PageRequest page);

  Future<CustomerRow?> findById(String id);

  /// Active customers for dropdowns (prescription form).
  Future<List<CustomerRow>> allActive();

  /// Creates the customer; the balance cache starts at the opening amount.
  Future<CustomerRow> create(CustomerDraft draft, {required String userId});

  /// Updates editable master fields; the balance stays ledger-derived and is
  /// re-synced so an opening-balance change is reflected immediately.
  Future<CustomerRow> update(String id, CustomerDraft draft,
      {required String userId});

  Future<void> setActive(String id, bool active, {required String userId});

  /// Enables/disables the credit account flag (`customers.has_account`).
  Future<void> setAccount(String id, bool enabled, {required String userId});

  /// One page of a customer's statement with running balances (كشف الحساب).
  Future<CustomerStatementPage> statement(
    String customerId, {
    required int fromDate,
    required int toDate,
    required int page,
    required int pageSize,
  });
}

/// A page of a customer's statement plus the summary footer.
class CustomerStatementPage {
  const CustomerStatementPage({
    required this.entries,
    required this.totals,
    required this.page,
    required this.pageSize,
    required this.customerName,
  });

  final List<CustomerStatementEntry> entries;
  final CustomerLedgerTotals totals;
  final int page;
  final int pageSize;
  final String customerName;
}