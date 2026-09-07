/// Phase 8 Cash Box page: drawer dashboard renders the session and ledger,
/// the open workflow drives the drawer from "not opened" to "open", and a
/// view-only cashier sees no operational actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/core/widgets/amount_field.dart';
import 'package:pharmacy_pos/domain/services/cashbox_service.dart';
import 'package:pharmacy_pos/features/accounts/application/cashbox_controller.dart';
import 'package:pharmacy_pos/features/accounts/data/cashbox_repository_impl.dart';
import 'package:pharmacy_pos/features/accounts/presentation/pages/cashbox_page.dart';
import 'package:pharmacy_pos/features/auth/domain/repositories/auth_repository.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';

import 'auth_harness.dart';

void main() {
  Widget harness(
    ({ProviderContainer container, AppDatabase db, AuthRepository repository})
        base,
    CashboxController controller,
  ) {
    return UncontrolledProviderScope(
      container: base.container,
      child: ProviderScope(
        overrides: [
          cashboxControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: CashboxPage()),
        ),
      ),
    );
  }

  late
      ({ProviderContainer container, AppDatabase db, AuthRepository repository})
      base;
  late CashboxController controller;

  setUp(() async {
    base = await buildAuthHarness();
    controller = CashboxController(CashboxRepositoryImpl(
        base.db, const CashboxService()));
    await base
        .container
        .read(authControllerProvider.notifier)
        .login('admin', 'Admin@123');
  });

  tearDown(() async {
    base.container.dispose();
    await base.db.close();
  });

  testWidgets('CashBoxPage (admin, Arabic) opens a fresh drawer',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(base, controller));
    await tester.pumpAndSettle();

    // Fresh store: the drawer is not opened yet and only the open action shows.
    expect(find.text('الصندوق غير مفتوح'), findsOneWidget);
    expect(find.text('افتح الصندوق لبدء نوبة العمل وتسجيل الحركات'),
        findsOneWidget);
    expect(find.text('فتح الصندوق'), findsOneWidget);
    expect(find.text('إغلاق الصندوق'), findsNothing);

    // Open the drawer with a 500.00 float.
    await tester.tap(find.text('فتح الصندوق'));
    await tester.pumpAndSettle();
    expect(find.byType(AmountField), findsOneWidget);
    await tester.enterText(find.byType(AmountField), '500');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();

    // The session card now shows the open session + live reconciliation.
    expect(find.text('الجلسة مفتوحة'), findsOneWidget);
    expect(find.text('الرصيد المتوقع'), findsOneWidget);
    expect(find.text('500.00'), findsWidgets,
        reason: 'running, expected, net-moves and ledger amounts render in '
            'Latin digits');
    // Opening row entered the ledger history.
    expect(find.text('افتتاح'), findsOneWidget);
    expect(find.text('إغلاق الصندوق'), findsOneWidget);
    expect(find.text('إيداع نقدي'), findsOneWidget);
    expect(find.text('سحب نقدي'), findsOneWidget);
    expect(find.text('تسوية الصندوق'), findsOneWidget);
  });

  testWidgets('CashBoxPage (cashier) is read-only', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedExtraUser(base.db);
    controller = CashboxController(CashboxRepositoryImpl(
        base.db, const CashboxService()));

    await base
        .container
        .read(authControllerProvider.notifier)
        .login('cashier', 'Cashier@123');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: base.container,
      child: ProviderScope(
        overrides: [
          cashboxControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: CashboxPage()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No operational buttons for a view-only cashier.
    expect(find.text('فتح الصندوق'), findsNothing);
    expect(find.text('إغلاق الصندوق'), findsNothing);
    expect(find.textContaining('وضع العرض فقط'), findsOneWidget);
    expect(find.text('الصندوق غير مفتوح'), findsOneWidget);
  });
}