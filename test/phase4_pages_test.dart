import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
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
import 'package:pharmacy_pos/features/purchases/presentation/pages/purchases_page.dart';
import 'package:pharmacy_pos/features/suppliers/application/suppliers_controller.dart';
import 'package:pharmacy_pos/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:pharmacy_pos/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:pharmacy_pos/features/suppliers/domain/usecases/suppliers_use_cases.dart';
import 'package:pharmacy_pos/features/suppliers/presentation/pages/suppliers_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';
import 'helpers.dart';

Future<void> insertUnit(AppDatabase db, String id, String name) async {
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
}

Future<void> insertItemUnits(
  AppDatabase db,
  String itemId,
  String largeUnitId,
) async {
  await db.into(db.itemUnits).insert(
        ItemUnitsCompanion.insert(
          id: 'iu_$itemId',
          itemId: itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: largeUnitId,
          unitsPerLarge: const Value(10),
        ),
      );
}

Widget _harness(
  ProviderContainer base,
  List<Override> overrides,
  Widget home,
) {
  return UncontrolledProviderScope(
    container: base,
    child: ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale(AppConfig.defaultLocale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: home),
      ),
    ),
  );
}

void main() {
  group('Phase 4 pages', () {
    testWidgets('SuppliersPage lists suppliers and shows the add action',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;

      final supRepo = SupplierRepositoryImpl(db, SupplierDao(db));
      final perms = const PermissionService();
      final sup = SuppliersController(
        ListSuppliersUseCase(supRepo, perms),
        CreateSupplierUseCase(supRepo, perms, const AuditService()),
        UpdateSupplierUseCase(supRepo, perms, const AuditService()),
        SetSupplierActiveUseCase(supRepo, perms, const AuditService()),
        SupplierBalancesUseCase(supRepo, perms),
        SupplierStatementUseCase(supRepo, perms),
      );

      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      expect(
        await sup.add(
          const SupplierDraft(
            name: 'مورد الأمصال',
            code: 'S-1001',
            openingBalanceMicros: 5000000,
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        isNull,
      );

      await tester.pumpWidget(
        _harness(
          base.container,
          [suppliersControllerProvider.overrideWith((_) => sup)],
          const SuppliersPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مورد الأمصال'), findsOneWidget);
      expect(find.text('إضافة مورد'), findsOneWidget);
    });

    testWidgets('PurchasesPage lists a pending invoice from the controller',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;

      final now = DateTime.now().millisecondsSinceEpoch;
      final supplierId = await insertSupplier(db);
      final itemId = await insertItem(db);
      await insertUnit(db, 'unit_box', 'علبة');
      await insertItemUnits(db, itemId, 'unit_box');

      final supRepo = SupplierRepositoryImpl(db, SupplierDao(db));
      final purRepo = PurchasesRepositoryImpl(
        db,
        PurchaseDao(db),
        SupplierDao(db),
        const BonusCalculator(),
        const StockService(),
        const AuditService(),
      );
      final perms = const PermissionService();
      final pur = PurchasesController(
        ListPurchasesUseCase(purRepo, perms),
        ReceivePurchaseUseCase(purRepo, perms),
        CancelPurchaseUseCase(purRepo, perms),
        CreatePurchaseUseCase(purRepo, perms),
        UpdatePendingPurchaseUseCase(purRepo, perms),
        PurchaseReturnUseCase(purRepo, perms),
      );

      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      expect(
        await pur.create(
          PurchaseDraft(
            invoiceNumber: 'INV-100',
            supplierId: supplierId,
            invoiceDate: now,
            userId: 'user_admin',
            lines: [
              PurchaseLineDraft(
                itemId: itemId,
                unitTypeId: 'unit_box',
                quantityBase: 5,
                unitCostMicros: 2000000,
              ),
            ],
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        isNull,
      );

      await tester.pumpWidget(
        _harness(
          base.container,
          [
            purchasesControllerProvider.overrideWith((_) => pur),
            allSuppliersUseCaseProvider.overrideWithValue(
                AllSuppliersUseCase(supRepo, perms)),
          ],
          const PurchasesPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('INV-100'), findsWidgets);
      expect(find.text('فاتورة شراء جديدة'), findsOneWidget);
      expect(find.text('رقم الفاتورة'), findsOneWidget);
    });
  });
}