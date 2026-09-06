import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/data/daos/customer_dao.dart';
import 'package:pharmacy_pos/data/daos/prescription_dao.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/customers/application/customers_controller.dart';
import 'package:pharmacy_pos/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:pharmacy_pos/features/customers/domain/repositories/customer_repository.dart';
import 'package:pharmacy_pos/features/customers/domain/usecases/customers_use_cases.dart';
import 'package:pharmacy_pos/features/customers/presentation/pages/customers_page.dart';
import 'package:pharmacy_pos/features/prescriptions/application/prescriptions_controller.dart';
import 'package:pharmacy_pos/features/prescriptions/data/repositories/prescription_repository_impl.dart';
import 'package:pharmacy_pos/features/prescriptions/domain/repositories/prescription_repository.dart';
import 'package:pharmacy_pos/features/prescriptions/domain/usecases/prescriptions_use_cases.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';
import 'helpers.dart';

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

({CustomersController customers, PrescriptionsController prescriptions, AppDatabase db})
    _controllers(AppDatabase db) {
  final perms = const PermissionService();
  final audit = const AuditService();

  final customerRepo = CustomerRepositoryImpl(db, CustomerDao(db));
  final customers = CustomersController(
    ListCustomersUseCase(customerRepo, perms),
    CreateCustomerUseCase(customerRepo, perms, audit),
    UpdateCustomerUseCase(customerRepo, perms, audit),
    SetCustomerActiveUseCase(customerRepo, perms, audit),
    SetCustomerAccountUseCase(customerRepo, perms, audit),
    CustomerStatementUseCase(customerRepo, perms),
  );

  final rxRepo = PrescriptionRepositoryImpl(db, PrescriptionDao(db));
  final prescriptions = PrescriptionsController(
    ListPrescriptionsUseCase(rxRepo, perms),
    CreatePrescriptionUseCase(rxRepo, perms, audit),
    GetPrescriptionDetailUseCase(rxRepo, perms),
    PreparePrescriptionForSaleUseCase(rxRepo, perms),
  );

  return (
    customers: customers,
    prescriptions: prescriptions,
    db: db,
  );
}

Future<String> _seedPricedItem(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final itemId = await insertItem(db);
  await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
        ItemsCompanion(sellingPriceMicros: const Value(250000)),
      );
  final customerId = 'cus_page_test';
  await db.into(db.customers).insert(
        CustomersCompanion.insert(
          id: customerId,
          name: 'عميل الوصفات',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return itemId;
}

void main() {
  group('Phase 5 pages', () {
    testWidgets('CustomersPage lists customers and shows the add action',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      final c = _controllers(db);

      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      expect(
        await c.customers.add(
          const CustomerDraft(name: 'عميل العيادة', phone: '01234567890'),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        isNull,
      );

      await tester.pumpWidget(
        _harness(
          base.container,
          [
            customersControllerProvider.overrideWith((_) => c.customers),
            prescriptionsControllerProvider.overrideWith((_) => c.prescriptions),
          ],
          const CustomersPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عميل العيادة'), findsOneWidget);
      expect(find.text('إضافة عميل'), findsOneWidget);
      expect(find.text('الوصفات الطبية'), findsOneWidget);
    });

    testWidgets('CustomersPage prescriptions tab lists a prescription',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      final c = _controllers(db);
      final itemId = await _seedPricedItem(db);

      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');
      expect(
        await c.prescriptions.create(
          PrescriptionDraft(
            customerId: 'cus_page_test',
            patientName: 'مريض النوبة',
            items: [
              PrescriptionItemDraft(
                itemId: itemId,
                quantityBase: 2,
                dosage: 'مرة يومياً',
              ),
            ],
          ),
          actingUserId: 'user_admin',
          actingRoleId: 'role_admin',
        ),
        isNull,
      );
      final row = (await db.select(db.prescriptions).get()).single;

      await tester.pumpWidget(
        _harness(
          base.container,
          [
            customersControllerProvider.overrideWith((_) => c.customers),
            prescriptionsControllerProvider.overrideWith((_) => c.prescriptions),
          ],
          const CustomersPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الوصفات الطبية'));
      await tester.pumpAndSettle();

      expect(find.text(row.prescriptionNumber), findsOneWidget);
      expect(find.text('وصفة جديدة'), findsOneWidget);
    });

    testWidgets('customer dialog validates the required name', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      final c = _controllers(db);
      final customerRepo = CustomerRepositoryImpl(db, CustomerDao(db));
      final perms = const PermissionService();

      await base
          .container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');

      await tester.pumpWidget(
        _harness(
          base.container,
          [
            customersControllerProvider.overrideWith((_) => c.customers),
            prescriptionsControllerProvider.overrideWith((_) => c.prescriptions),
            allCustomersUseCaseProvider.overrideWithValue(
                AllCustomersUseCase(customerRepo, perms)),
          ],
          const CustomersPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('إضافة عميل'));
      await tester.pumpAndSettle();
      expect(find.text('عميل جديد'), findsOneWidget);

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('اسم العميل مطلوب'), findsWidgets);
    });

    testWidgets('viewer role sees customers but no create action',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final base = await buildAuthHarness();
      addTearDown(base.db.close);
      addTearDown(base.container.dispose);
      final db = base.db;
      final c = _controllers(db);

      await seedExtraUser(db,
          username: 'viewer', roleId: 'role_viewer', fullName: 'مشاهد');
      await base
          .container
          .read(authControllerProvider.notifier)
          .login('viewer', 'Cashier@123');

      await tester.pumpWidget(
        _harness(
          base.container,
          [
            customersControllerProvider.overrideWith((_) => c.customers),
            prescriptionsControllerProvider.overrideWith((_) => c.prescriptions),
          ],
          const CustomersPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إضافة عميل'), findsNothing);
    });
  });
}