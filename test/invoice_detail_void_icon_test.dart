/// Regression test for Ali's 2026-10-05 report: the void (delete) icon never
/// appeared in the invoice detail AppBar, even for a completed invoice with
/// zero returns viewed by an admin holding `sales.void`.
///
/// Root cause: `_load()` assigned the `_invoice` state field after `await`
/// WITHOUT `setState`, so the AppBar (which reads `_invoice` for the void
/// button's visibility) never rebuilt once the invoice finished loading.
/// The body rebuilt via FutureBuilder, masking the stale AppBar.
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/domain/services/return_service.dart';
import 'package:pharmacy_pos/domain/services/sale_service.dart';
import 'package:pharmacy_pos/domain/services/stock_service.dart';
import 'package:pharmacy_pos/features/sales/data/pos_catalog_dao.dart';
import 'package:pharmacy_pos/features/sales/data/sales_repository_impl.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_cart.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/usecases/payment_calculator.dart';
import 'package:pharmacy_pos/features/sales/presentation/pages/pos_invoice_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

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

Future<String> _seedSellableItem(AppDatabase db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final itemId = await insertItem(db);
  await (db.update(db.items)..where((i) => i.id.equals(itemId))).write(
        const ItemsCompanion(
          sellingPriceMicros: Value(10000),
          vatRateBasisPoints: Value(0),
          isActive: Value(true),
        ),
      );
  await db.into(db.units).insert(
        UnitsCompanion.insert(
          id: 'unit_strip',
          name: 'شريط',
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await db.into(db.itemUnits).insert(
        ItemUnitsCompanion.insert(
          id: 'iu_void_icon_$now',
          itemId: itemId,
          baseUnitId: 'unit_strip',
          largeUnitId: 'unit_strip',
          unitsPerLarge: const Value(1),
        ),
        mode: InsertMode.insertOrIgnore,
      );
  await insertBatch(db, itemId, quantityBase: 300);
  return itemId;
}

void main() {
  testWidgets(
    'void icon appears in AppBar after a completed invoice finishes loading',
    (tester) async {
      final harness = await buildAuthHarness();
      final db = harness.db;
      addTearDown(harness.container.dispose);

      // Admin holds every permission, including sales.void.
      await harness.container
          .read(authControllerProvider.notifier)
          .login('admin', 'Admin@123');

      final repo = SalesRepositoryImpl(
        db,
        PosCatalogDao(db),
        const StockService(),
        SaleService(),
        ReturnService(),
      );

      final itemId = await _seedSellableItem(db);
      final outcome = await repo.checkout(
        PosCheckoutCommand(
          invoiceNumber: 'SI-VOID-ICON-1',
          lines: [
            PosSaleLineInput(
              itemId: itemId,
              quantityBase: 10,
              unitPriceMicros: 10000,
              unitTypeId: 'unit_strip',
              vatRateBasisPoints: 0,
              discountBasisPoints: 0,
            ),
          ],
          paymentMethod: PosPaymentMethod.cash,
          paidMicros: 100000,
          userId: 'user_admin',
        ),
      );
      expect(outcome.invoice.saleStatus, SaleStatus.completed);

      await tester.pumpWidget(
        _harness(
          harness.container,
          [salesRepositoryProvider.overrideWithValue(repo)],
          PosInvoicePage(invoiceId: outcome.invoice.id),
        ),
      );
      // Let the invoice future complete AND the post-load setState rebuild
      // the AppBar. Before the fix, the AppBar never rebuilt and the icon
      // below was absent.
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);
    },
  );
}
