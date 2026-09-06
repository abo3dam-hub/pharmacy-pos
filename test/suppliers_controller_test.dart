import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/data/daos/supplier_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/suppliers/application/suppliers_controller.dart';
import 'package:pharmacy_pos/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:pharmacy_pos/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:pharmacy_pos/features/suppliers/domain/usecases/suppliers_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _adminRole = 'role_admin';
const _viewerRole = 'role_viewer';
const _micros = 10000; // 1.0000

({AppDatabase db, SuppliersController controller}) _harness(AppDatabase db) {
  final repo = SupplierRepositoryImpl(db, SupplierDao(db));
  final perms = const PermissionService();
  final audit = const AuditService();
  final controller = SuppliersController(
    ListSuppliersUseCase(repo, perms),
    CreateSupplierUseCase(repo, perms, audit),
    UpdateSupplierUseCase(repo, perms, audit),
    SetSupplierActiveUseCase(repo, perms, audit),
    SupplierBalancesUseCase(repo, perms),
    SupplierStatementUseCase(repo, perms),
  );
  return (db: db, controller: controller);
}

SupplierDraft _draft({
  String name = 'مورد الأمصال',
  int opening = 2500 * _micros,
  int creditLimit = 100000 * _micros,
  String? code = 'S-1001',
}) {
  return SupplierDraft(
    name: name,
    code: code,
    phone: '01123456789',
    contactPerson: 'أحمد',
    openingBalanceMicros: opening,
    creditLimitMicros: creditLimit,
  );
}

Future<String> _singleSupplierId(AppDatabase db) async {
  final row = await db.select(db.suppliers).get();
  return row.single.id;
}

void main() {
  group('SuppliersController', () {
    test('create → master list → derived balances (opening only)', () async {
      final h = _harness(newDatabase());

      final failure = await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      expect(failure, isNull);

      await h.controller.load(search: 'مورد', actingRoleId: _adminRole);
      expect(h.controller.state.status, SuppliersStatus.ready);
      expect(h.controller.state.total, 1);
      expect(h.controller.state.suppliers.single.name, 'مورد الأمصال');
      expect(h.controller.state.suppliers.single.balanceMicros,
          2500 * _micros);

      await h.controller.loadBalances(actingRoleId: _adminRole);
      final b = h.controller.state.balances.single;
      expect(b.openingMicros, 2500 * _micros);
      expect(b.invoicesNetMicros, 0);
      expect(b.returnsNetMicros, 0);
      expect(b.balanceMicros, 2500 * _micros);
    });

    test('update and toggleActive persist through the repository', () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final id = await _singleSupplierId(h.db);

      expect(
        await h.controller.update(
          id,
          _draft(name: 'مورد متغير', creditLimit: 200000 * _micros),
          actingUserId: 'user_admin',
          actingRoleId: _adminRole,
        ),
        isNull,
      );
      final row = await (h.db.select(h.db.suppliers)
            ..where((s) => s.id.equals(id)))
          .getSingle();
      expect(row.name, 'مورد متغير');
      expect(row.creditLimitMicros, 200000 * _micros);

      expect(
        await h.controller.toggleActive(id, false,
            actingUserId: 'user_admin', actingRoleId: _adminRole),
        isNull,
      );
      final after = await (h.db.select(h.db.suppliers)
            ..where((s) => s.id.equals(id)))
          .getSingle();
      expect(after.isActive, isFalse);
    });

    test('read-only viewer is denied create; list is allowed', () async {
      final h = _harness(newDatabase());

      final denied = await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _viewerRole);
      expect(denied, isNotNull);

      await h.controller.load(actingRoleId: _viewerRole);
      expect(h.controller.state.status, SuppliersStatus.ready);
    });

    test('statement aggregates invoices + returns with running balance',
        () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final supplierId = await _singleSupplierId(h.db);

      final now = DateTime.now().millisecondsSinceEpoch;
      await h.db.into(h.db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion.insert(
              id: 'pinv_a',
              invoiceNumber: 'INV-A',
              purchaseStatus: PurchaseStatus.received,
              supplierId: supplierId,
              userId: 'user_admin',
              invoiceDate: now - 86400000,
              subtotalMicros: const Value(1000 * _micros),
              totalMicros: const Value(1000 * _micros),
              paidMicros: const Value(0),
              remainingMicros: const Value(1000 * _micros),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await h.db.into(h.db.purchaseInvoices).insert(
            PurchaseInvoicesCompanion.insert(
              id: 'pinv_b',
              invoiceNumber: 'INV-B',
              purchaseStatus: PurchaseStatus.received,
              supplierId: supplierId,
              userId: 'user_admin',
              invoiceDate: now,
              subtotalMicros: const Value(500 * _micros),
              totalMicros: const Value(500 * _micros),
              paidMicros: const Value(500 * _micros),
              remainingMicros: const Value(0),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await h.db.into(h.db.returns).insert(
            ReturnsCompanion.insert(
              id: 'ret_a',
              returnNumber: 'RTR-A',
              type: ReturnType.purchase_return,
              originalInvoiceId: 'pinv_a',
              originalInvoiceType: 'purchase',
              supplierId: Value(supplierId),
              userId: 'user_admin',
              totalMicros: const Value(-200 * _micros),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await SupplierDao(h.db).syncBalance(supplierId, at: now);

      final failure = await h.controller.loadStatement(
        supplierId,
        fromDate: now - 10 * 86400000,
        toDate: now + 86400000,
        page: 1,
        pageSize: 50,
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      final page = h.controller.state.statement!;
      expect(page.totals.totalDocs, 3);
      expect(page.totals.openingMicros, 2500 * _micros);
      expect(page.totals.debitTotalMicros, 1500 * _micros);
      expect(page.totals.creditTotalMicros, 700 * _micros);
      expect(page.totals.closingMicros, 3300 * _micros);
      expect(page.entries, hasLength(4));
      expect(page.entries.first.docType, 'opening');
      expect(page.entries[1].docType, 'purchase_invoice');
      expect(page.entries.last.docType, 'purchase_return');
    });

    test('create/update/toggle are written to the audit log', () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      final id = await _singleSupplierId(h.db);
      await h.controller.update(
        id,
        _draft(name: 'مورد معدل'),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      await h.controller.toggleActive(id, true,
          actingUserId: 'user_admin', actingRoleId: _adminRole);

      final rows = await (h.db.select(h.db.auditLogs)
            ..where((a) => a.entityType.equals('supplier')))
          .get();
      expect(rows, hasLength(3));
    });

    test('page search is SQL-side and paginates', () async {
      final h = _harness(newDatabase());
      await h.controller.add(_draft(name: 'مورد الأول'),
          actingUserId: 'user_admin', actingRoleId: _adminRole);
      await h.controller.add(_draft(name: 'صيدلية الثاني', code: 'S-1002'),
          actingUserId: 'user_admin', actingRoleId: _adminRole);

      await h.controller.load(search: 'مورد', actingRoleId: _adminRole);
      expect(h.controller.state.total, 1);

      await h.controller.load(page: 1, actingRoleId: _adminRole);
      expect(h.controller.state.total, 2);
      expect(h.controller.state.request.page, PageRequest().page);
    });
  });
}