import '../../../../core/constants/permission_codes.dart';
import '../../../../core/data_grid/page_request.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';
import '../services/inventory_excel_service.dart';
import '../services/inventory_view_builder.dart';
import 'create_item.dart' show itemAuditJson;

/// Full inventory export to xlsx bytes (§27). Requires `inventory.view`.
class ExportItemsUseCase {
  const ExportItemsUseCase(
    this._repo,
    this._permissions,
    this._excel, {
    required this.viewBuilder,
  });

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final InventoryExcelService _excel;
  final InventoryViewBuilder viewBuilder;

  Future<List<int>> call({String? actingRoleId}) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    final result = await _repo.searchItems(const PageRequest(pageSize: 10000));
    final views = await viewBuilder.buildMany(result.items);
    return _excel.exportItems(views);
  }
}

/// Import result summary for the UI/toast.
class ImportSummary {
  const ImportSummary({
    required this.created,
    required this.updated,
    required this.issues,
  });

  final int created;
  final int updated;
  final List<String> issues;

  int get skipped => issues.length;
}

/// Excel import (§27). Requires `inventory.create`; rows matching an existing
/// primary barcode update the item, otherwise a new item is created. Every
/// action is audited; a summary record is also written.
class ImportItemsUseCase {
  const ImportItemsUseCase(this._repo, this._permissions, this._audit);

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<ImportSummary> call(
    List<int> bytes, {
    String? actingUserId,
    String? actingRoleId,
  }) async {
    final db = _repo.database;
    await _permissions.requireRolePermission(
        db, actingRoleId, Perm.inventoryCreate);
    if (actingUserId == null || actingUserId.isEmpty) {
      throw UnauthorizedException('بيانات المستخدم ناقصة للتسجيل');
    }

    final service = InventoryExcelService(_repo);
    final parsed = await service.parseImport(bytes);
    final issues = [...parsed.issues];
    var created = 0;
    var updated = 0;

    for (final row in parsed.rows) {
      final existingId = row.barcode == null ? null : await _findByScanned(row.barcode!);
      try {
        if (existingId != null) {
          final supplierIds = await _repo.supplierIdsForItem(existingId);
          await _repo.updateItem(
              existingId, row.draft.copyWith(supplierIds: supplierIds));
          await _audit.write(
            db,
            userId: actingUserId,
            action: AuditAction.update,
            entityType: 'item',
            entityId: existingId,
            after: itemAuditJsonDraft(row.draft),
            note: 'استيراد (تحديث) منتج: ${row.draft.tradeName}',
          );
          updated++;
        } else {
          final createdRow = await _repo.createItem(row.draft);
          await _audit.write(
            db,
            userId: actingUserId,
            action: AuditAction.create,
            entityType: 'item',
            entityId: createdRow.id,
            after: itemAuditJson(createdRow),
            note: 'استيراد (إنشاء) منتج: ${row.draft.tradeName}',
          );
          created++;
        }
      } on DomainException catch (e) {
        issues.add('الصف ${row.rowNumber}: ${e.failure.message}');
      }
    }

    await _audit.write(
      db,
      userId: actingUserId,
      action: AuditAction.bulkOp,
      entityType: 'item',
      entityId: 'import:${DateTime.now().microsecondsSinceEpoch}',
      after: {'created': created, 'updated': updated, 'issues': issues.length},
      note: 'استيراد Excel: أنشئ $created، حُدّث $updated، رُفض ${issues.length}',
    );
    return ImportSummary(created: created, updated: updated, issues: issues);
  }

  Future<String?> _findByScanned(String barcode) async {
    final result = await _repo.searchItems(const PageRequest(pageSize: 10000));
    for (final item in result.items) {
      if (item.primaryBarcode == barcode || item.secondaryBarcode == barcode) {
        return item.id;
      }
    }
    return null;
  }
}

/// Small projection helper so import audit uses the same field set.
Map<String, Object?> itemAuditJsonDraft(ItemDraft d) => {
      'trade_name': d.tradeName,
      'primary_barcode': d.primaryBarcode,
      'secondary_barcode': d.secondaryBarcode,
      'category_id': d.categoryId,
      'cost_micros': d.costMicros,
      'selling_price_micros': d.sellingPriceMicros,
      'minimum_stock_base': d.minimumStockBase,
      'maximum_stock_base': d.maximumStockBase,
    };