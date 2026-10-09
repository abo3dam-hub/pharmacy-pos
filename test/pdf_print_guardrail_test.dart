/// PDF print guardrail (Ali 2026-10-09).
///
/// Two root-cause regressions from Ali's device testing:
/// 1. Unprotected `Printing.layoutPdf` crashed the app on save (appeared as
///    a "logout"). Every print path must go through the try/catch-protected
///    `PdfDocuments.printBytes` helper.
/// 2. Arabic table headers/cells rendered reversed in invoice/receipt PDFs.
///    Every `TableHelper.fromTextArray` must be wrapped via `rtlTable()`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Printing.layoutPdf calls go through PdfDocuments.printBytes',
      () {
    final file = File('lib/core/pdf/pdf_documents.dart');
    final lines = file.readAsLinesSync();
    final violations = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // The single allowed call site is inside printBytes itself.
      if (line.contains('Printing.layoutPdf')) {
        // Check we're inside the printBytes method: scan backwards for the
        // nearest method declaration.
        var insidePrintBytes = false;
        for (var j = i; j >= 0; j--) {
          final prev = lines[j];
          if (prev.contains('Future<void> printBytes(')) {
            insidePrintBytes = true;
            break;
          }
          // A different method declaration means we're not in printBytes.
          if (RegExp(r'^\s*(Future<|pw\.Widget|String|void)').hasMatch(prev) &&
              prev.contains('(') &&
              !prev.contains('printBytes')) {
            break;
          }
        }
        if (!insidePrintBytes) {
          violations.add('${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'Direct Printing.layoutPdf calls bypass the protected '
            'printBytes helper:\n${violations.join('\n')}');
  });

  test('all PDF tables are wrapped in RTL directionality', () {
    final files = [
      'lib/core/pdf/pdf_documents.dart',
      'lib/features/reports/domain/services/report_export_service.dart',
    ];
    final violations = <String>[];
    for (final path in files) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('TableHelper.fromTextArray(')) {
          // Allow if wrapped via rtlTable( on this or the previous line.
          final current = lines[i];
          var j = i - 1;
          while (j >= 0 && lines[j].trim().isEmpty) {
            j--;
          }
          final prev = j >= 0 ? lines[j] : '';
          if (!current.contains('rtlTable(') &&
              !prev.contains('rtlTable(')) {
            violations.add('$path:${i + 1}: ${current.trim()}');
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'PDF tables without RTL wrapper (Arabic renders reversed):\n'
            '${violations.join('\n')}');
  });
}
