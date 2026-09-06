import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/data/daos/purchase_dao.dart';
import 'package:pharmacy_pos/data/daos/supplier_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/bonus_calculator.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/purchases/application/purchases_controller.dart';
import 'package:pharmacy_pos/features/purchases/data/repositories/purchases_repository_impl.dart';
import 'package:pharmacy_pos/features/purchases/domain/repositories/purchases_repository.dart';
import 'package:pharmacy_pos/features/purchases/domain/usecases/purchases_use_cases.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'helpers.dart';

const _adminRole = 'role_admin';
const _viewerRole = 'role_viewer';
const _cashierRole = 'role_cashier';

({AppDatabase db, PurchasesRepository repo, PurchasesController controller})
    _harness(AppDatabase db) {
  final repo = PurchasesRepositoryImpl(
    db,
    PurchaseDao(db),
    SupplierDao(db),
    const BonusCalculator(),
    const StockService(),
    const AuditService(),
  );
  final perms = const PermissionService();
  final controller = PurchasesController(
    ListPurchasesUseCase(repo, perms),
    ReceivePurchaseUseCase(repo, perms),
    CancelPurchaseUseCase(repo, perms),
    CreatePurchaseUseCase(repo, perms),
    UpdatePendingPurchaseUseCase(repo, perms),
    PurchaseReturnUseCase(repo, perms),
  );
  return (db: db, repo: repo, controller: controller);
}

Future<String> _seedUnit(AppDatabase db, String id, String name) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.units).insert(
        UnitsCompanion.insert(
          id: id,
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  return id;
}

Future<(String itemId, String supplierId, String unitTypeId)>
    _seedPurchaseContext(AppDatabase db) async {
  final itemId = await insertItem(db);
  final supplierId = await insertSupplier(db);
  final box = await _seedUnit(db, 'unit_box', 'علبة');
  await _seedUnit(db, 'unit_strip', 'شريط');
  await db.into(db.itemUnits).insert(
        ItemUnitsCompanion.insert(
          id: 'iu_$itemId',
          itemId: itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: box,
          unitsPerLarge: const Value(10),
        ),
      );
  return (itemId, supplierId, box);
}

PurchaseDraft _draft(
  String invoiceNumber,
  String supplierId,
  String itemId,
  String unitTypeId, {
  int quantityBase = 10,
  int unitCostMicros = 1000000,
}) {
  return PurchaseDraft(
    invoiceNumber: invoiceNumber,
    supplierId: supplierId,
    invoiceDate: DateTime.now().millisecondsSinceEpoch,
    userId: 'user_admin',
    lines: [
      PurchaseLineDraft(
        itemId: itemId,
        unitTypeId: unitTypeId,
        quantityBase: quantityBase,
        unitCostMicros: unitCostMicros,
        bonuses: const [
          PurchaseBonusDraft(
            bonusType: PurchaseBonusType.bonus_1,
            quantityBase: 2,
          ),
        ],
      ),
    ],
  );
}

Future<PurchaseInvoiceRow> _findInvoice(AppDatabase db, String number) async {
  final row = await (db.select(db.purchaseInvoices)
        ..where((i) => i.invoiceNumber.equals(number)))
      .getSingle();
  return row;
}

void main() {
  group('Purchases flow', () {
    test('create pending invoice with bonus → totals + editable lines',
        () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);

      final failure = await h.controller.create(
        _draft('INV-001', supplierId, itemId, unitBox),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      final inv = await _findInvoice(h.db, 'INV-001');
      expect(inv.purchaseStatus, PurchaseStatus.pending);
      expect(inv.subtotalMicros, 10 * 1000000);
      expect(inv.remainingMicros, 10 * 1000000);

      final detail = await h.repo.detail(inv.id);
      expect(detail.lines, hasLength(1));
      final line = detail.lines.single.line;
      expect(line.effectiveQuantityBase, 10);
      expect(line.bonusQuantityBase, 0, reason: 'placeholder before receive');
      expect(detail.bonuses, hasLength(1));

      final updatedFailure = await h.controller.updatePending(
        inv.id,
        _draft('INV-001', supplierId, itemId, unitBox, quantityBase: 7),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(updatedFailure, isNull);
      final after = await h.repo.detail(inv.id);
      expect(after.lines.single.line.quantityBase, 7);
    });

    test('receive resolves bonus → batch, stock, movement, balance', () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);
      await h.controller.create(
        _draft('INV-002', supplierId, itemId, unitBox),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final inv = await _findInvoice(h.db, 'INV-002');
      final detail = await h.repo.detail(inv.id);
      final lineId = detail.lines.single.line.id;

      final failure = await h.controller.receive(
        inv.id,
        inputs: [ReceiveLineInput(lineId: lineId, batchNumber: 'B-002')],
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      final received = await h.repo.detail(inv.id);
      expect(received.invoice.purchaseStatus, PurchaseStatus.received);
      expect(received.lines.single.line.effectiveQuantityBase, 12);
      expect(received.lines.single.line.bonusQuantityBase, 2);
      expect(received.lines.single.line.batchId, isNotNull);

      final batch = await (h.db.select(h.db.batches)
            ..where((b) => b.batchNumber.equals('B-002')))
          .getSingle();
      expect(batch.originalQuantityBase, 12);
      expect(batch.bonusQtyBase, 2);
      expect(batch.quantityBase, 12);

      final item = await (h.db.select(h.db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 12);

      final movements = await (h.db.select(h.db.stockMovements)
            ..where((m) => m.refType.equals('purchase_line')))
          .get();
      expect(movements.single.quantityBaseSigned, 12);

      final bonus = await (h.db.select(h.db.purchaseBonuses)
            ..where((b) => b.purchaseInvoiceItemId.equals(lineId)))
          .getSingle();
      expect(bonus.batchId, isNotNull);

      final supplier = await (h.db.select(h.db.suppliers)
            ..where((s) => s.id.equals(supplierId)))
          .getSingle();
      expect(supplier.balanceMicros, 10 * 1000000);

      final audits = await (h.db.select(h.db.auditLogs)
            ..where((a) => a.entityType.equals('purchase_invoice')))
          .get();
      expect(audits, hasLength(2));
    });

    test('cancel pending invoice soft-deletes without touching stock',
        () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);
      await h.controller.create(
        _draft('INV-003', supplierId, itemId, unitBox, quantityBase: 4,
            unitCostMicros: 500000),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final inv = await _findInvoice(h.db, 'INV-003');

      final failure = await h.controller.cancel(inv.id,
          actingUserId: 'user_admin', actingRoleId: _adminRole, reason: 'خطأ');
      expect(failure, isNull);

      final row = await (h.db.select(h.db.purchaseInvoices)
            ..where((i) => i.id.equals(inv.id)))
          .getSingle();
      expect(row.purchaseStatus, PurchaseStatus.cancelled);
      expect(row.isVoided, isTrue);
      expect(row.notes, 'خطأ');

      final item = await (h.db.select(h.db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 0);
    });

    test('RBAC: viewer cannot create/edit/void; cashier cannot void',
        () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);

      expect(
        await h.controller.create(
          _draft('INV-004', supplierId, itemId, unitBox),
          actingUserId: 'user_admin',
          actingRoleId: _viewerRole,
        ),
        isNotNull,
      );

      await h.controller.create(
        _draft('INV-005', supplierId, itemId, unitBox, quantityBase: 2),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final inv = await _findInvoice(h.db, 'INV-005');

      expect(
        await h.controller.cancel(inv.id,
            actingUserId: 'user_admin', actingRoleId: _cashierRole),
        isNotNull,
      );
      final stillPending = await _findInvoice(h.db, 'INV-005');
      expect(stillPending.purchaseStatus, PurchaseStatus.pending);
    });

    test('duplicate invoice number is rejected', () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);
      await h.controller.create(
        _draft('INV-006', supplierId, itemId, unitBox, quantityBase: 2),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final failure = await h.controller.create(
        _draft('INV-006', supplierId, itemId, unitBox, quantityBase: 3),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(failure, isNotNull);
    });

    test('purchase return reduces stock and posts a purchase_return movement',
        () async {
      final h = _harness(newDatabase());
      final (itemId, supplierId, unitBox) = await _seedPurchaseContext(h.db);
      await h.controller.create(
        _draft('INV-007', supplierId, itemId, unitBox, quantityBase: 10),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      final inv = await _findInvoice(h.db, 'INV-007');
      final detail = await h.repo.detail(inv.id);
      final lineId = detail.lines.single.line.id;
      await h.controller.receive(
        inv.id,
        inputs: [ReceiveLineInput(lineId: lineId, batchNumber: 'B-007')],
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );

      final available = await GetAvailableReturnQtyUseCase(
              h.repo, const PermissionService())(
        lineId,
        actingRoleId: _adminRole,
      );
      expect(available, 12);

      final failure = await h.controller.recordReturn(
        PurchaseReturnRequest(
          returnNumber: 'RET-007',
          invoiceId: inv.id,
          userId: 'user_admin',
          lines: [PurchaseReturnLineRequest(lineId: lineId, quantityBase: 3)],
          reason: 'تالف',
        ),
        actingUserId: 'user_admin',
        actingRoleId: _adminRole,
      );
      expect(failure, isNull);

      final item = await (h.db.select(h.db.items)
            ..where((i) => i.id.equals(itemId)))
          .getSingle();
      expect(item.currentStockBase, 9);

      final batch = await (h.db.select(h.db.batches)
            ..where((b) => b.batchNumber.equals('B-007')))
          .getSingle();
      expect(batch.quantityBase, 9);

      final returns = await (h.db.select(h.db.returns)
            ..where((r) => r.type.equals('purchase_return')))
          .get();
      expect(returns.single.status, 'completed');

      final movements = await (h.db.select(h.db.stockMovements)
            ..where((m) => m.movementType
                .equals('purchase_return')))
          .get();
      expect(movements.single.quantityBaseSigned, -3);
    });
  });
}