/// Double-checkout guard (Ali 2026-10-05).
///
/// Tapping "pay" twice on the totals sheet recorded TWO invoices for one
/// sale: the sheet had no submitting flag and `PosWorkspaceController.checkout`
/// had no re-entrancy guard. This test fires two concurrent checkouts and
/// asserts the repository sees exactly one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/permission_codes.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_catalog_item.dart';
import 'package:pharmacy_pos/features/sales/domain/entities/pos_invoice.dart';
import 'package:pharmacy_pos/features/sales/domain/repositories/sales_repository.dart';
import 'package:pharmacy_pos/features/sales/presentation/controllers/pos_workspace_controller.dart';
import 'package:pharmacy_pos/shared/models/enums.dart';

class _SlowFakeSalesRepository implements SalesRepository {
  int checkoutCalls = 0;

  @override
  Future<String> nextInvoiceNumber() async => 'S-TEST-1';

  @override
  Future<PosSaleOutcome> checkout(PosCheckoutCommand command) async {
    checkoutCalls++;
    // Simulate the slow device I/O window during which the second tap lands.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return PosSaleOutcome(
      invoice: PosInvoiceView(
        id: 'inv_test',
        invoiceNumber: command.invoiceNumber,
        invoiceType: InvoiceType.sale,
        saleStatus: SaleStatus.completed,
        paymentMethod: PaymentMethod.cash,
        customerId: null,
        customerName: '',
        userId: 'u1',
        subtotalMicros: 100000,
        discountTotalMicros: 0,
        vatTotalMicros: 0,
        totalMicros: 100000,
        totalCostMicros: 80000,
        profitMicros: 20000,
        paidMicros: 100000,
        changeMicros: 0,
        cashMicros: 100000,
        cardMicros: 0,
        creditMicros: 0,
        createdAt: 0,
        lines: const [],
      ),
      lines: const [],
      movements: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

PosCatalogItem _item() => const PosCatalogItem(
      id: 'item_1',
      tradeName: 'دواء اختبار',
      tradeNameEn: 'Test',
      scientificName: 'Test',
      primaryBarcode: '1111111111111',
      isControlledDrug: false,
      requiresPrescription: false,
      isActive: true,
      sellingPriceMicros: 100000,
      vatRateBasisPoints: 0,
      currentStockBase: 50,
      availableStockBase: 50,
      baseUnitId: 'u_base',
      baseUnitName: 'قطعة',
      largeUnitId: 'u_box',
      largeUnitName: 'علبة',
      unitsPerLarge: 1,
      partialSaleEnabled: false,
    );

void main() {
  test('two concurrent checkouts record a single invoice', () async {
    final repo = _SlowFakeSalesRepository();
    final controller =
        PosWorkspaceController(tabIndex: 0, repository: repo);
    await controller.addToCart(_item(), quantity: 1);
    // Cash fully paid, like the payment sheet submits it.
    controller.updatePaymentInputs(cashReceivedMicros: 100000);

    final results = await Future.wait([
      controller.checkout(
        actingUserId: 'u1',
        permissions: {Perm.sell},
      ),
      controller.checkout(
        actingUserId: 'u1',
        permissions: {Perm.sell},
      ),
    ]);

    expect(repo.checkoutCalls, 1,
        reason: 'the second concurrent checkout must be dropped');
    expect(results.whereType<PosSaleOutcome>().length, 1);
  });
}
