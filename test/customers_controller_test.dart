import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/data/daos/customer_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/customers/application/customers_controller.dart';
import 'package:pharmacy_pos/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:pharmacy_pos/features/customers/domain/repositories/customer_repository.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/customers_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _adminRole = 'role_admin';
const _viewerRole = 'role_viewer';
const _micros = 10000; // 1.0000

({AppDatabase db, CustomersController controller}) _harness(AppDatabase db) {
  final repo = CustomerRepositoryImpl(db, CustomerDao(db));
  final perms = const PermissionService();
  final audit = const AuditService();
  final controller = CustomersController(
    ListCustomersUseCase(repo, perms),
    CreateCustomerUseCase(repo, perms, audit),
    UpdateCustomerUseCase(repo, perms, audit),
    SetCustomerActiveUseCase(repo, perms, audit),
    SetCustomerAccountUseCase(repo, perms, audit),
    CustomerStatementUseCase(repo, perms),
  );
  return (db: db, controller: controller);
}

CustomerDraft _draft({
  String name = 'عميل العيادة',
  int opening = 1000 * _micros,
  int creditLimit = 50000 * _micros,
  bool hasAccount = true,
}) {
  return CustomerDraft(
    name: name,
    phone: '01234567890',
    email: 'clinic@example.com',
    hasAccount: hasAccount,
    openingBalanceMicros: opening,
    creditLimitMicros: creditLimit,
  );
}

Future<String> _singleCustomerId(AppDatabase db) async {
  final row = await db.select(db.customers).get();
  return row.single.id;
}

/// Seeds a completed sale invoice and a completed sale return directly (Phase
/// 6 writes them) so the customers ledger (كشف الحساب) has real documents.
Future<void> _seedSalesDocs(AppDatabase db, String customerId, int now) async {
  await db.into(db.salesInvoices).insert(
        SalesInvoicesCompanion.insert(
          id: 'sinv_a',
          invoiceNumber: 'INV-S-A',
          invoiceType: InvoiceType.sale,
          saleStatus: SaleStatus.completed,
          customerId: Value(customerId),
          userId: 'user_admin',
          paymentMethod: PaymentMethod.credit,
          totalMicros: const Value(2000 * _micros),
          paidMicros: const Value(0),
          remainingMicros: const Value(2000 * _micros),
          createdAt: now - 86400000,
          updatedAt: now - 86400000,
        ),
      );
  await db.into(db.returns).insert(
        ReturnsCompanion.insert(
          id: 'ret_a',
          returnNumber: 'RTR-S-A',
          type: ReturnType.sale_return,
          originalInvoiceId: 'sinv_a',
          originalInvoiceType: 'sale',
          customerId: Value(customerId),
          userId: 'user_admin',
          totalMicros: const Value(-300 * _micros),
          createdAt: now,
          updatedAt: now,
        ),
      );
  await CustomerDao(db).syncBalance(customerId, at: now);
}

void main() {
  group('CustomersController', () {
    test('create → master list shows the opening balance', () async {
      final h = _harness(newDatabase());

      final failure = await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      expect(failure, isNull);

      await h.controller.load(search: 'عميل', actingRoleId: _adminRole);
      expect(h.controller.state.status, CustomersStatus.ready);
      expect(h.controller.state.total, 1);
      expect(h.controller.state.customers.single.name, 'عميل العيادة');
      expect(h.controller.state.customers.single.balanceMicros, 1000 * _micros);
      expect(h.controller.state.customers.single.hasAccount, isTrue);
    });

    test('update / toggleActive / setAccount persist through the repository',
        () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final id = await _singleCustomerId(h.db);

      expect(
        await h.controller.update(
          id,
          _draft(name: 'عميل معدل', opening: 1500 * _micros),
          actingUserId: 'user_admin',
          actingRoleId: _adminRole,
        ),
        isNull,
      );
      var row = await (h.db.select(h.db.customers)
            ..where((c) => c.id.equals(id)))
          .getSingle();
      expect(row.name, 'عميل معدل');
      expect(row.openingBalanceMicros, 1500 * _micros);
      expect(row.balanceMicros, 1500 * _micros);

      expect(
        await h.controller.toggleActive(id, false,
            actingUserId: 'user_admin', actingRoleId: _adminRole),
        isNull,
      );
      row = await (h.db.select(h.db.customers)..where((c) => c.id.equals(id)))
          .getSingle();
      expect(row.isActive, isFalse);

      expect(
        await h.controller.setAccount(id, false,
            actingUserId: 'user_admin', actingRoleId: _adminRole),
        isNull,
      );
      row = await (h.db.select(h.db.customers)..where((c) => c.id.equals(id)))
          .getSingle();
      expect(row.hasAccount, isFalse);
    });

    test('read-only viewer is denied create; list is allowed', () async {
      final h = _harness(newDatabase());

      final denied = await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _viewerRole);
      expect(denied, isNotNull);

      await h.controller.load(actingRoleId: _viewerRole);
      expect(h.controller.state.status, CustomersStatus.ready);
    });

    test('account ledger: sales docs derive balance + statement running balance',
        () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final customerId = await _singleCustomerId(h.db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await _seedSalesDocs(h.db, customerId, now);

      final cached = await (h.db.select(h.db.customers)
            ..where((c) => c.id.equals(customerId)))
          .getSingle();
      // opening 1000 + (invoice remaining 2000) - 300 return = 2700
      expect(cached.balanceMicros, 2700 * _micros);

      final failure = await h.controller.loadStatement(
        customerId,
        fromDate: now - 10 * 86400000,
        toDate: now + 86400000,
        page: 1,
        pageSize: 50,
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      final page = h.controller.state.statement!;
      expect(page.customerName, 'عميل العيادة');
      expect(page.totals.totalDocs, 2);
      expect(page.totals.openingMicros, 1000 * _micros);
      expect(page.totals.debitTotalMicros, 2000 * _micros);
      expect(page.totals.creditTotalMicros, 300 * _micros);
      expect(page.totals.closingMicros, 2700 * _micros);
      expect(page.entries, hasLength(3)); // opening + 2 docs
      expect(page.entries.first.docType, 'opening');
      expect(page.entries[1].docType, 'sale_invoice');
      expect(page.entries[1].balanceMicros,
          3000 * _micros); // 1000 + 2000
      expect(page.entries.last.docType, 'sale_return');
      expect(page.entries.last.balanceMicros,
          2700 * _micros); // 3000 - 300
    });

    test('create/update/toggle/setAccount are written to the audit log',
        () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final id = await _singleCustomerId(h.db);
      await h.controller.update(id, _draft(name: 'عميل معدل'),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      await h.controller.toggleActive(id, true,
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      await h.controller.setAccount(id, true,
          actingUserId: 'user_admin', actingRoleId: _adminRole);

      final rows = await (h.db.select(h.db.auditLogs)
            ..where((a) => a.entityType.equals('customer')))
          .get();
      expect(rows, hasLength(4));
    });

    test('page search is SQL-side and paginates', () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(name: 'عميل الأول'),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      await h.controller.add(_draft(name: 'مريض العناية'),
          actingUserId: 'user_admin', actingRoleId: _adminRole);

      await h.controller.load(search: 'عميل', actingRoleId: _adminRole);
      expect(h.controller.state.total, 1);

      await h.controller.load(actingRoleId: _adminRole);
      expect(h.controller.state.total, 2);
    });
  });
}