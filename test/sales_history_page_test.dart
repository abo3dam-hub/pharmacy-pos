/// §18.4 — Sales History page widget acceptance.
///
/// Verifies the Arabic-UI wiring: search/filter controls render, the paginated
/// grid lists persisted invoices with the canonical columns, and the
/// status/payment/cashier labels use the l10n texts. The page talks to the
/// repository through [salesRepositoryProvider]; mutations elsewhere are out
/// of scope (covered by repository/domain tests).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/config/app_config.dart';
import 'package:pharmacy_pos/core/data_grid/page_request.dart';
import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/theme/app_theme.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_customer.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/pages/sales_history_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository(this.invoices);

  final List<PosInvoiceView> invoices;

  @override
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
    PageRequest request, {
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    String? userId,
    int? fromMillis,
    int? toMillis,
  }) async {
    return PageResult(
      items: invoices,
      total: invoices.length,
      request: request,
    );
  }

  @override
  Future<PageResult<PosCatalogItem>> searchCatalog(
    PageRequest request, {
    bool? inStockOnly,
  }) async => PageResult(items: const [], total: 0, request: request);

  @override
  Future<PosCatalogItem?> itemByBarcode(String barcode) async => null;

  @override
  Future<PosCatalogItem?> itemById(String id) async => null;

  @override
  Future<List<PosCustomer>> findCustomers(
    String query, {
    int limit = 20,
  }) async => const [];

  @override
  Future<List<PosRxSummary>> activePrescriptionsForCustomer(
    String customerId,
  ) async => const [];

  @override
  Future<String> nextInvoiceNumber() async => 'SI-0001';

  @override
  Future<String> nextReturnNumber() async => 'RT-0001';

  @override
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command) async =>
      throw UnimplementedError();

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String userId,
    required String reason,
  }) async {}

  @override
  Future<PosReturnOutcome> returnSaleLine(PosReturnCommand command) async =>
      throw UnimplementedError();

  @override
  Future<PosInvoiceView?> invoiceViewById(String invoiceId) async => null;

  @override
  Future<List<SmartAlternative>> smartAlternatives(PosCatalogItem item) async =>
      const [];

  @override
  Future<void> recordLostSale(PosLostSaleDraft draft) async {}

  @override
  Future<int> availableStock(String itemId) async => 0;
}

PosInvoiceView _invoice({
  required String id,
  required String number,
  required SaleStatus status,
  required PaymentMethod payment,
  String customer = '',
  String cashier = 'أحمد',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return PosInvoiceView(
    id: id,
    invoiceNumber: number,
    invoiceType: InvoiceType.sale,
    saleStatus: status,
    paymentMethod: payment,
    customerId: 'c_1',
    customerName: customer,
    userId: 'u_1',
    userName: cashier,
    subtotalMicros: 196000000,
    discountTotalMicros: 0,
    vatTotalMicros: 0,
    totalMicros: 196000000,
    totalCostMicros: 146666668,
    profitMicros: 49333332,
    paidMicros: 196000000,
    changeMicros: 0,
    cashMicros: 196000000,
    cardMicros: 0,
    creditMicros: 0,
    createdAt: now,
    lines: const [],
  );
}

void main() {
  Widget harness(ProviderContainer container, SalesRepository repo) {
    return UncontrolledProviderScope(
      container: container,
      child: ProviderScope(
        overrides: [salesRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale(AppConfig.defaultLocale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: SalesHistoryPage()),
        ),
      ),
    );
  }

  testWidgets('renders filter header, columns, status and payment labels', (
    tester,
  ) async {
    final base = await buildAuthHarness();
    addTearDown(() async {
      base.container.dispose();
      await base.db.close();
    });
    await base.container
        .read(authControllerProvider.notifier)
        .login('admin', 'Admin@123');
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeSalesRepository([
      _invoice(
        id: 'inv_1',
        number: 'SI-1001',
        status: SaleStatus.completed,
        payment: PaymentMethod.cash,
        customer: 'مريم',
        cashier: 'أحمد',
      ),
      _invoice(
        id: 'inv_2',
        number: 'SI-1002',
        status: SaleStatus.partially_returned,
        payment: PaymentMethod.card,
      ),
    ]);
    await tester.pumpWidget(harness(base.container, repo));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SalesHistoryPage)),
    );
    expect(find.text(l10n.salesHistorySearchHint), findsOneWidget);
    expect(find.text(l10n.salesHistoryFilterStatus), findsWidgets);
    expect(find.text(l10n.salesHistoryFilterCashier), findsWidgets);

    expect(find.text('SI-1001'), findsOneWidget);
    expect(find.text('SI-1002'), findsOneWidget);
    expect(find.text('مريم'), findsOneWidget);
    // Status + cashier + payment labels are l10n text, not raw persistence.
    expect(find.text(l10n.saleStatusCompleted), findsOneWidget);
    expect(find.text(l10n.saleStatusPartiallyReturned), findsOneWidget);
    expect(find.text(l10n.posCashLabel), findsOneWidget);
    expect(find.text(l10n.posCardLabel), findsOneWidget);
    expect(find.text('أحمد'), findsWidgets);
    // Total rendered as money (19,600 units @ scale 4 → 196,000,000 micros).
    expect(find.textContaining('19,600'), findsNWidgets(2));
  });

  testWidgets('shows the empty-state message when there are no invoices', (
    tester,
  ) async {
    final base = await buildAuthHarness();
    addTearDown(() async {
      base.container.dispose();
      await base.db.close();
    });
    await base.container
        .read(authControllerProvider.notifier)
        .login('admin', 'Admin@123');
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(base.container, _FakeSalesRepository([])));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SalesHistoryPage)),
    );
    expect(find.text(l10n.salesHistoryEmpty), findsOneWidget);
  });
}
