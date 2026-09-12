import '../../../../core/constants/permission_codes.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/models/enums.dart';
import '../repositories/inventory_repository.dart';
import '../services/inventory_excel_service.dart';
import '../services/inventory_view_builder.dart';

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
    final result = await _repo.allItems();
    final views = await viewBuilder.buildMany(result);
    return _excel.exportItems(views);
  }
}

/// Import result summary for the UI/toast.
class ImportSummary {
  const ImportSummary({
    required this.created,
    required this.updated,
    this.createdMaster = 0,
    required this.issues,
  });

  final int created;
  final int updated;
  final int createdMaster;
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

    final auditEntries = <AuditEntry>[
      for (final m in parsed.createdMaster)
        AuditEntry(
          userId: actingUserId,
          action: AuditAction.create,
          entityType: m.entityType,
          entityId: m.entityId,
          after: {'name': m.name},
          note: 'إنشاء تلقائي أثناء استيراد: ${m.name}',
        ),
    ];

    // All rows persist in one repository transaction; per-row audit records
    // are collected and flushed together so a large sheet does not pay a
    // transaction per item (§27, §28 performance).
    final applied = await _repo.applyImport([
      for (final row in parsed.rows)
        ImportApplyEntry(
          rowNumber: row.rowNumber,
          draft: row.draft,
          existingItemId: row.existingItemId,
        ),
    ]);
    issues.addAll(applied.failures);
    var created = 0;
    var updated = 0;
    for (final outcome in applied.outcomes) {
      if (outcome.action == ImportApplyAction.created) {
        created++;
        auditEntries.add(AuditEntry(
          userId: actingUserId,
          action: AuditAction.create,
          entityType: 'item',
          entityId: outcome.entityId,
          after: itemAuditJsonDraft(outcome.draft),
          note: 'استيراد (إنشاء) منتج: ${outcome.draft.tradeName}',
        ));
      } else {
        updated++;
        auditEntries.add(AuditEntry(
          userId: actingUserId,
          action: AuditAction.update,
          entityType: 'item',
          entityId: outcome.entityId,
          after: itemAuditJsonDraft(outcome.draft),
          note: 'استيراد (تحديث) منتج: ${outcome.draft.tradeName}',
        ));
      }
    }

    auditEntries.add(AuditEntry(
      userId: actingUserId,
      action: AuditAction.bulkOp,
      entityType: 'item',
      entityId: 'import:${DateTime.now().microsecondsSinceEpoch}',
      after: {
        'created': created,
        'updated': updated,
        'createdMaster': parsed.createdMaster.length,
        'issues': issues.length,
      },
      note: 'استيراد Excel: أنشئ $created، حُدّث $updated، '
          'أُنشئت ${parsed.createdMaster.length} بيانات أساسية، '
          'رُفض ${issues.length}',
    ));
    await _audit.writeMany(db, auditEntries);

    return ImportSummary(
      created: created,
      updated: updated,
      createdMaster: parsed.createdMaster.length,
      issues: issues,
    );
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