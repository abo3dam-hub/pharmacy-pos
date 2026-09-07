import '../../../../data/daos/customer_dao.dart';
import '../../../../data/daos/supplier_dao.dart';
import '../../../accounts/data/accounting_dao.dart';
import 'report_export_service.dart';

/// Statement-to-report adapters (Phase 11): turn the account / customer /
/// supplier statements into exportable [ReportExportRequest]s without touching
/// any document — pure mapping of already loaded read models.
class StatementExport {
  const StatementExport._();

  static ReportExportRequest account({
    required String title,
    required String? subtitle,
    required int generatedAtMillis,
    required List<StatementLine> lines,
    required int openingBalanceMicros,
    required int totalDebitMicros,
    required int totalCreditMicros,
  }) {
    return ReportExportRequest(
      title: title,
      subtitle: subtitle,
      sheetName: 'account_statement',
      generatedAtMillis: generatedAtMillis,
      columns: const ['الرقم', 'التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'],
      rows: [
        [
          const ReportCell.text('الرصيد الافتتاحي'),
          const ReportCell.text(''),
          const ReportCell.text(''),
          const ReportCell.text(''),
          const ReportCell.text(''),
          ReportCell.money(openingBalanceMicros),
        ],
        for (final line in lines)
          [
            ReportCell.text(line.entryNumber),
            ReportCell.text(reportDateOnly(line.entryDate)),
            ReportCell.text(line.description),
            ReportCell.money(line.debitMicros),
            ReportCell.money(line.creditMicros),
            ReportCell.money(line.runningBalanceMicros ?? 0),
          ],
      ],
      totals: [
        ReportTotalRow('إجمالي مدين', ReportCell.money(totalDebitMicros)),
        ReportTotalRow('إجمالي دائن', ReportCell.money(totalCreditMicros)),
        ReportTotalRow(
          'الرصيد الختامي',
          ReportCell.money(openingBalanceMicros +
              totalDebitMicros -
              totalCreditMicros),
        ),
      ],
    );
  }

  static ReportExportRequest customer({
    required String title,
    required String? subtitle,
    required int generatedAtMillis,
    required List<CustomerStatementEntry> rows,
    required int openingMicros,
    required int debitTotalMicros,
    required int creditTotalMicros,
    required int closingMicros,
  }) {
    return ReportExportRequest(
      title: title,
      subtitle: subtitle,
      sheetName: 'customer_statement',
      generatedAtMillis: generatedAtMillis,
      columns: const ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'],
      rows: [
        for (final e in rows)
          [
            ReportCell.text(
                e.docType == 'opening' ? '' : reportDateOnly(e.date)),
            ReportCell.text('${e.docType} ${e.refNo}'),
            ReportCell.money(e.debitMicros),
            ReportCell.money(e.creditMicros),
            ReportCell.money(e.balanceMicros),
          ],
      ],
      totals: [
        ReportTotalRow('الرصيد الافتتاحي', ReportCell.money(openingMicros)),
        ReportTotalRow('إجمالي مدين', ReportCell.money(debitTotalMicros)),
        ReportTotalRow('إجمالي دائن', ReportCell.money(creditTotalMicros)),
        ReportTotalRow('الرصيد الختامي', ReportCell.money(closingMicros)),
      ],
    );
  }

  static ReportExportRequest supplier({
    required String title,
    required String? subtitle,
    required int generatedAtMillis,
    required List<SupplierStatementEntry> rows,
    required int openingMicros,
    required int debitTotalMicros,
    required int creditTotalMicros,
    required int closingMicros,
  }) {
    return ReportExportRequest(
      title: title,
      subtitle: subtitle,
      sheetName: 'supplier_statement',
      generatedAtMillis: generatedAtMillis,
      columns: const ['التاريخ', 'البيان', 'مدين', 'دائن', 'الرصيد'],
      rows: [
        for (final e in rows)
          [
            ReportCell.text(
                e.docType == 'opening' ? '' : reportDateOnly(e.date)),
            ReportCell.text('${e.docType} ${e.refNo}'),
            ReportCell.money(e.debitMicros),
            ReportCell.money(e.creditMicros),
            ReportCell.money(e.balanceMicros),
          ],
      ],
      totals: [
        ReportTotalRow('الرصيد الافتتاحي', ReportCell.money(openingMicros)),
        ReportTotalRow('إجمالي مدين', ReportCell.money(debitTotalMicros)),
        ReportTotalRow('إجمالي دائن', ReportCell.money(creditTotalMicros)),
        ReportTotalRow('الرصيد الختامي', ReportCell.money(closingMicros)),
      ],
    );
  }
}

/// Local `yyyy-MM-dd` timestamp used by statement exports (Latin digits).
String reportDateOnly(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}