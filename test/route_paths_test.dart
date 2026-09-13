/// §18.4 — route-path helper contract.
///
/// The canonical `/sale` sub-routes (z-report, history, invoice detail) MUST be
/// produced by the app_sections helpers. Hand-concatenating `'/' + section.path`
/// previously produced malformed `//sale/...` URLs GoRouter could not resolve.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/constants/app_sections.dart';

void main() {
  test('sale section path never starts with a double slash', () {
    expect(AppSection.sale.path, isNot(anyOf(startsWith('//'), endsWith('/'))));
  });

  test('saleZReportPath is a single-slash absolute route under /sale', () {
    final p = saleZReportPath();
    expect(p, '/sale/z-report');
    expect(p, startsWith(AppSection.sale.path));
    expect(p.contains('//'), isFalse);
  });

  test('salesHistoryPath is a single-slash absolute route under /sale', () {
    final p = salesHistoryPath();
    expect(p, '/sale/history');
    expect(p, startsWith(AppSection.sale.path));
    expect(p.contains('//'), isFalse);
  });

  test(
    'saleInvoiceDetailPath embeds the invoice id without double slashes',
    () {
      final p = saleInvoiceDetailPath('inv_123');
      expect(p, '/sale/invoice/inv_123');
      expect(p, startsWith(AppSection.sale.path));
      expect(p.contains('//'), isFalse);
      expect(
        saleInvoiceDetailPath('inv_123'),
        isNot(contains('inv_123inv_123')),
      );
    },
  );

  test('invoice ids are interpolated exactly once', () {
    const id = 'sli_abc';
    final calls = {for (var i = 0; i < 3; i++) saleInvoiceDetailPath(id)};
    expect(calls, hasLength(1));
    expect(calls.single.split('/').last, id);
  });
}
