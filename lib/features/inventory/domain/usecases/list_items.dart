import '../../../../core/data_grid/page_request.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../domain/services/permission_service.dart';
import '../entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';
import '../services/inventory_view_builder.dart';

/// Paginated, filterable item listing for the inventory grid (§22). All
/// filtering/sorting happen in SQL via the repository.
class ListItemsUseCase {
  const ListItemsUseCase(
    this._repo,
    this._permissions, {
    required this.viewBuilder,
  });

  final InventoryRepository _repo;
  final PermissionService _permissions;
  final InventoryViewBuilder viewBuilder;

  Future<({List<InventoryItemView> items, int total, PageRequest request})>
      call(
    PageRequest page, {
    String? categoryId,
    String? manufacturerId,
    bool? onlyActive,
    bool? inStockOnly,
    String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(
        _repo.database, actingRoleId, Perm.inventoryView);
    final result = await _repo.searchItems(page,
        categoryId: categoryId,
        manufacturerId: manufacturerId,
        onlyActive: onlyActive,
        inStockOnly: inStockOnly);
    final views = await viewBuilder.buildMany(result.items);
    return (items: views, total: result.total, request: result.request);
  }
}