
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/audit_service.dart';
import 'package:pharmacy_pos/domain/services/financial_posting_service.dart';
import 'package:pharmacy_pos/domain/services/permission_service.dart';
import 'package:pharmacy_pos/features/auth/domain/repositories/auth_repository.dart';
import 'package:pharmacy_pos/features/expenses/application/expense_controller.dart';
import 'package:pharmacy_pos/features/expenses/data/expense_repository_impl.dart';
import 'package:pharmacy_pos/features/expenses/domain/services/receipt_storage.dart';
import 'package:pharmacy_pos/features/expenses/domain/usecases/expenses_use_cases.dart';
import 'package:pharmacy_pos/features/expenses/presentation/pages/expenses_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';

class _FakeReceiptStorage implements ReceiptStorage {
  const _FakeReceiptStorage();
  @override
  Future<String> save(String sourcePath) async => '/fake/$sourcePath';
  @override
  Future<void> delete(String storedPath) async {}
}

void main() {
  Widget harness(
    ({ProviderContainer container, AppDatabase db, AuthRepository repository})
        base,
    ExpenseController controller,
  ) {
    return UncontrolledProviderScope(
      container: base.container,
      child: ProviderScope(
        overrides: [
          expenseControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: ExpensesPage()),
        ),
      ),
    );
  }

  ExpenseController buildController(AppDatabase db) {
    final repo = ExpenseRepositoryImpl(
        db, const _FakeReceiptStorage(), const FinancialPostingService());
    final perms = const PermissionService();
    final audit = const AuditService();
    return ExpenseController(
      ListExpensesUseCase(repo, perms),
      ListExpenseCategoriesUseCase(repo, perms),
      CreateExpenseUseCase(repo, perms),
      UpdateExpenseUseCase(repo, perms, audit),
      CancelExpenseUseCase(repo, perms),
      AttachReceiptUseCase(repo, perms, audit),
      RemoveReceiptUseCase(repo, perms, audit),
      CreateExpenseCategoryUseCase(repo, perms, audit),
      UpdateExpenseCategoryUseCase(repo, perms, audit),
      SetExpenseCategoryActiveUseCase(repo, perms, audit),
    );
  }

  late
      ({ProviderContainer container, AppDatabase db, AuthRepository repository})
      base;

  setUp(() async {
    base = await buildAuthHarness();
    await base
        .container
        .read(authControllerProvider.notifier)
        .login('admin', 'Admin@123');
  });

  tearDown(() async {
    base.container.dispose();
    await base.db.close();
  });

  testWidgets('ExpensesPage renders empty state', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = buildController(base.db);
    await tester.pumpWidget(harness(base, controller));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد مصروفات مسجلة'), findsOneWidget);
    expect(find.text('المصروفات'), findsWidgets);
  });

  testWidgets('ExpensesPage shows record button for admin', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = buildController(base.db);
    await tester.pumpWidget(harness(base, controller));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل مصروف'), findsOneWidget);
  });

  testWidgets('ExpensesPage viewer shows read-only and no record button',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedExtraUser(base.db,
        username: 'viewer',
        password: 'Viewer@123',
        roleId: 'role_viewer',
        fullName: 'مشاهد');
    final controller = buildController(base.db);
    await base
        .container
        .read(authControllerProvider.notifier)
        .login('viewer', 'Viewer@123');

    await tester.pumpWidget(harness(base, controller));
    await tester.pumpAndSettle();

    expect(find.text('عرض فقط — لا تملك صلاحية لإدارة المصروفات'), findsOneWidget);
    expect(find.text('تسجيل مصروف'), findsNothing);
  });
}
