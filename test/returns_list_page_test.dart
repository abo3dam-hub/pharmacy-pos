/// Returns list page widget acceptance.
///
/// Regression: invoices must appear automatically when the page opens —
/// the user must never have to touch the search field first. The page talks
/// to the repository through [salesRepositoryProvider].
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
import 'package:pharmacy_pos/features/sales/domain/entities/pos_return.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/smart_alternative.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/pages/returns_list_page.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

import 'auth_harness.dart';

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository(this.returns);

  final List<PosReturnView> returns;

  @override
  Future<PageResult<PosReturnView>> listReturns(PageRequest request) async =>
      PageResult<PosReturnView>(
        request: request,
        items: returns,
        total: returns.length,
      );

  @override
  Future<({PosReturnView header, List<PosReturnLineView> lines})?>
      returnDetail(String returnId) async => null;

  @override
  Future<PageResult<PosInvoiceView>> searchSaleInvoices(
    PageRequest request, {
    SaleStatus? status,
    PaymentMethod? paymentMethod,
    String? userId,
    int? fromMillis,
    int? toMillis,
  }) async => PageResult(items: const [], total: 0, request: request);

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

PosReturnView _ret({
  required String id,
  required String number,
  required String invoice,
}) {
  return PosReturnView(
    id: id,
    returnNumber: number,
    type: ReturnType.sale_return,
    originalInvoiceId: 'inv_$id',
    originalInvoiceNumber: invoice,
    customerName: 'زبون',
    totalMicros: -50000000,
    reason: 'سبب',
    isVoided: false,
    createdAt: DateTime.now().millisecondsSinceEpoch,
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
          home: const Scaffold(body: ReturnsListPage()),
        ),
      ),
    );
  }

  testWidgets('returns appear automatically on open, no search needed', (
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
      _ret(id: 'r1', number: 'RT-0001', invoice: 'SI-1001'),
      _ret(id: 'r2', number: 'RT-0002', invoice: 'SI-1002'),
    ]);
    await tester.pumpWidget(harness(base.container, repo));
    // No interaction at all: no taps, no text entry.
    await tester.pumpAndSettle();

    expect(find.text('RT-0001'), findsOneWidget);
    expect(find.text('RT-0002'), findsOneWidget);
    expect(find.textContaining('SI-1001'), findsOneWidget);
    expect(find.textContaining('SI-1002'), findsOneWidget);
  });

  testWidgets('search still filters after auto-load', (tester) async {
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

    var lastSearch = '<unset>';
    final repo = _ListReturnsSpy(
      [_ret(id: 'r1', number: 'RT-0001', invoice: 'SI-1001')],
      onRequest: (r) => lastSearch = r.search,
    );
    await tester.pumpWidget(harness(base.container, repo));
    await tester.pumpAndSettle();

    // Auto-load fires with an empty search.
    expect(lastSearch, '');
    expect(find.text('RT-0001'), findsOneWidget);

    // Typing filters on top of the loaded list.
    await tester.enterText(find.byType(TextField), 'RT-0001');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(lastSearch, 'RT-0001');
  });
}

class _ListReturnsSpy extends _FakeSalesRepository {
  _ListReturnsSpy(super.returns, {required this.onRequest});

  final void Function(PageRequest) onRequest;

  @override
  Future<PageResult<PosReturnView>> listReturns(PageRequest request) async {
    onRequest(request);
    return super.listReturns(request);
  }
}
