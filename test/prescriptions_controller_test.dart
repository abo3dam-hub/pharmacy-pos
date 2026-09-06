import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/data/daos/prescription_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/prescriptions/application/prescriptions_controller.dart';
import 'package:pharmacy_pos/features/prescriptions/data/repositories/prescription_repository_impl.dart';
import 'package:pharmacy_pos/features/prescriptions/domain/repositories/prescription_repository.dart';
import 'package:pharmacy_pos/features/prescriptions/domain/usecases/prescriptions_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _adminRole = 'role_admin';
const _cashierRole = 'role_cashier';
const _viewerRole = 'role_viewer';
const _micros = 10000; // 1.0000

({AppDatabase db, PrescriptionsController controller})
    _harness(AppDatabase db) {
  final repo = PrescriptionRepositoryImpl(db, PrescriptionDao(db));
  final perms = const PermissionService();
  final audit = const AuditService();
  final controller = PrescriptionsController(
    ListPrescriptionsUseCase(repo, perms),
    CreatePrescriptionUseCase(repo, perms, audit),
    GetPrescriptionDetailUseCase(repo, perms),
    PreparePrescriptionForSaleUseCase(repo, perms),
  );
  return (db: db, controller: controller);
}

Future<String> _insertPricedItem(AppDatabase db, {int priceMicros = _micros}) async {
  final id = await insertItem(db, barcode: '6291041500220');
  await (db.update(db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(sellingPriceMicros: Value(priceMicros)),
      );
  return id;
}

int _customerSeq = 0;

Future<String> _insertCustomer(AppDatabase db, {String name = 'عميل الوصفات'}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = 'cus_${_customerSeq++}_$now';
  await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: id,
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
  return id;
}

PrescriptionDraft _draft(
  String customerId,
  String itemId, {
  int qty = 4,
  String patientName = 'مريض النوبة',
}) {
  return PrescriptionDraft(
    customerId: customerId,
    patientName: patientName,
    doctorName: 'د. سامي',
    doctorSpecialty: 'قلب',
    items: [
      PrescriptionItemDraft(
        itemId: itemId,
        quantityBase: qty,
        dosage: 'مرة يومياً',
        frequency: 'صباحاً',
        durationDays: 7,
      ),
    ],
  );
}

void main() {
  group('PrescriptionsController', () {
    test('create → list joins the customer and computes the total', () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db);

      final failure = await h.controller.create(
        _draft(customerId, itemId),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      await h.controller.load(actingRoleId: _adminRole);
      expect(h.controller.state.status, PrescriptionsStatus.ready);
      expect(h.controller.state.total, 1);
      final row = h.controller.state.rows.single;
      expect(row.customerName, 'عميل الوصفات');
      expect(row.row.patientName, 'مريض النوبة');
      // 4 × 2500 micros = 10000 micros
      expect(row.row.totalMicros, 4 * _micros);
      expect(row.row.status, PrescriptionStatus.active);
    });

    test('create is rejected when the customer or an item is missing', () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db);

      final noCustomer = await h.controller.create(
        _draft('cus_missing', itemId),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(noCustomer, isNotNull);

      final noItem = await h.controller.create(
        _draft(customerId, 'item_missing'),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(noItem, isNotNull);

      final rows = await h.db.select(h.db.prescriptions).get();
      expect(rows, isEmpty);
    });

    test('detail resolves items with the item trade name and line totals',
        () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db, priceMicros: _micros);

      await h.controller.create(
        _draft(customerId, itemId, qty: 3),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final row = (await h.db.select(h.db.prescriptions).get()).single;

      expect(await h.controller.loadDetail(row.id,
          actingRoleId: _adminRole), isNull);
      final detail = h.controller.state.detail!;
      expect(detail.customerName, 'عميل الوصفات');
      expect(detail.items, hasLength(1));
      expect(detail.items.single.itemTradeName, 'بانادول');
      expect(detail.items.single.quantityBase, 3);
      expect(detail.items.single.lineTotalMicros, 3 * _micros);
    });

    test('prepareForSale produces the Phase-6 snapshot; dispensed is rejected',
        () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db);

      await h.controller.create(
        _draft(customerId, itemId),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final row = (await h.db.select(h.db.prescriptions).get()).single;

      expect(await h.controller.prepareForSale(row.id,
          actingRoleId: _adminRole), isNull);
      final prepared = h.controller.state.prepared!;
      expect(prepared.isReady, isTrue);
      expect(prepared.customerName, 'عميل الوصفات');
      expect(prepared.items, hasLength(1));

      await (h.db.update(h.db.prescriptions)..where((p) => p.id.equals(row.id)))
          .write(PrescriptionsCompanion(status: Value(PrescriptionStatus.dispensed)));
      expect(await h.controller.prepareForSale(row.id,
          actingRoleId: _adminRole), isNotNull);
      expect(h.controller.state.prepareError, isNotNull);
    });

    test('permission gating: viewer cannot list, cashier cannot create',
        () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db);

      await h.controller.load(actingRoleId: _viewerRole);
      expect(h.controller.state.status, PrescriptionsStatus.error);

      final denied = await h.controller.create(
        _draft(customerId, itemId),
        actingUserId: 'user_cashier',
        actingRoleId: _cashierRole,
      );
      expect(denied, isNotNull);
      expect(await h.controller.load(actingRoleId: _cashierRole), isNull);
      expect(h.controller.state.status, PrescriptionsStatus.ready);
    });

    test('creation is written to the audit log', () async {
      final h = _harness(newDatabase());
      final customerId = await _insertCustomer(h.db);
      final itemId = await _insertPricedItem(h.db);

      await h.controller.create(
        _draft(customerId, itemId),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );

      final rows = await (h.db.select(h.db.auditLogs)
            ..where((a) => a.entityType.equals('prescription')))
          .get();
      expect(rows, hasLength(1));
      expect(rows.single.action, 'create');
    });
  });
}