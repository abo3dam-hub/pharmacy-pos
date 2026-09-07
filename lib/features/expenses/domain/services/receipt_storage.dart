import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Abstract receipt file store: the app moves picked photos/PDFs into a managed
/// directory so `expenses.receipt_path` is under our control and survives app
/// data relocation (§4.20 receipt scans). Tests inject an in-memory fake.
abstract interface class ReceiptStorage {
  /// Copies [sourcePath] into managed storage under `expense_receipts/` and
  /// returns the stored absolute path. Validates an allowed extension and a
  /// size ceiling before copying.
  Future<String> save(String sourcePath);

  /// Deletes a previously stored receipt (no-op when it no longer exists).
  Future<void> delete(String storedPath);
}

/// File-system implementation over the app documents directory.
class LocalReceiptStorage implements ReceiptStorage {
  LocalReceiptStorage({Future<String> Function()? documentsDir})
      : _documentsDir = documentsDir ?? _defaultDocumentsDir;

  final Future<String> Function() _documentsDir;

  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.pdf', '.gif', '.bmp',
  };

  static Future<String> _defaultDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  String _dir(String root) => '$root/expense_receipts';

  @override
  Future<String> save(String sourcePath) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('ملف المقبوض غير موجود: $sourcePath');
    }
    final lower = sourcePath.toLowerCase();
    final matched = allowedExtensions.firstWhere(lower.endsWith,
        orElse: () => throw StateError('صيغة ملف غير مدعومة: $sourcePath'));
    final size = await src.length();
    if (size > maxBytes) {
      throw StateError('حجم الملف يتجاوز الحد المسموح (5MB)');
    }
    final root = await _documentsDir();
    final dir = Directory(_dir(root));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}$matched';
    await src.copy(target);
    return target;
  }

  @override
  Future<void> delete(String storedPath) async {
    final f = File(storedPath);
    if (await f.exists()) {
      await f.delete();
    }
  }
}