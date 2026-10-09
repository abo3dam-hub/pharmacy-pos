import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/pdf/pdf_documents.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/services/report_export_service.dart';

/// Save/print plumbing for report exports. Both helpers are side-effect free
/// on the DB — they only materialise already-computed bytes to a file or the
/// platform print dialog.

Future<void> saveReportExcel(
  BuildContext context,
  ReportExportService service,
  ReportExportRequest request,
) async {
  final l10n = AppLocalizations.of(context);
  final bytes = service.buildExcel(request);
  final file = await FilePicker.saveFile(
    dialogTitle: l10n.reportExportExcel,
    fileName:
        '${request.sheetName}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    bytes: Uint8List.fromList(bytes),
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );
  if (file != null && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.reportExportExcelDone)));
  }
}

Future<void> printReportPdf(
  BuildContext context,
  ReportExportService service,
  ReportExportRequest request,
) async {
  try {
    final bytes = await service.buildPdf(request);
    // Unified protected print (Ali, 2026-10-09): try/catch inside printBytes
    // plus the outer catch here for buildPdf failures.
    await PdfDocuments().printBytes(bytes);
  } catch (e) {
    // Never crash/logout on PDF failure (Ali, 2026-10-09) — show an error.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).posPrintFailed}: $e',
          ),
        ),
      );
  }
}

/// Compact print + download buttons reused across report pages.
class ReportExportBar extends StatelessWidget {
  const ReportExportBar({
    super.key,
    this.onPrint,
    this.onSaveExcel,
    this.enabled = true,
  });

  final VoidCallback? onPrint;
  final VoidCallback? onSaveExcel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.commonPrint,
          onPressed: enabled ? onPrint : null,
          icon: const Icon(Icons.print_outlined),
        ),
        IconButton(
          tooltip: l10n.reportExportExcel,
          onPressed: enabled ? onSaveExcel : null,
          icon: const Icon(Icons.download_outlined),
        ),
      ],
    );
  }
}