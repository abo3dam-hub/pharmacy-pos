import '../../../../core/errors/exceptions.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/entities/inventory_item.dart';
import '../repositories/inventory_repository.dart';

/// Enriches raw [ItemRow]s with their FK names and unit relation so the grid
/// never performs per-column joins in widgets (§4.7).
class InventoryViewBuilder {
  const InventoryViewBuilder(this._repo);

  final InventoryRepository _repo;

  Future<InventoryItemView> build(ItemRow item) async {
    final category = item.categoryId == null
        ? null
        : (await _repo.categoryById(item.categoryId!))?.name;
    final manufacturer = item.manufacturerId == null
        ? null
        : (await _repo.manufacturerById(item.manufacturerId!))?.name;
    final unitsRow = await _repo.itemUnitsFor(item.id);
    final baseUnitName = unitsRow == null
        ? null
        : (await _repo.unitById(unitsRow.baseUnitId))?.name;
    final largeUnitName = unitsRow == null
        ? null
        : (await _repo.unitById(unitsRow.largeUnitId))?.name;
    final ingredients = (await _repo.activeIngredientRefsForItems({item.id}))[item.id] ?? const [];
    final indications = (await _repo.indicationNamesForItems({item.id}))[item.id] ?? const [];
    return InventoryItemView(
      item: item,
      units: unitsRow,
      baseUnitName: baseUnitName,
      largeUnitName: largeUnitName,
      categoryName: category,
      manufacturerName: manufacturer,
      activeIngredients: ingredients,
      indicationNames: indications,
    );
  }

  Future<InventoryItemView> buildById(String id) async {
    final row = await _repo.findItem(id);
    if (row == null) throw NotFoundException('المنتج رقم $id غير موجود');
    return build(row);
  }

  Future<List<InventoryItemView>> buildMany(List<ItemRow> items) async {
    if (items.isEmpty) return const [];
    final ids = {for (final item in items) item.id};
    final ingredientsByItem = await _repo.activeIngredientRefsForItems(ids);
    final indicationsByItem = await _repo.indicationNamesForItems(ids);
    final views = <InventoryItemView>[];
    for (final item in items) {
      final category = item.categoryId == null
          ? null
          : (await _repo.categoryById(item.categoryId!))?.name;
      final manufacturer = item.manufacturerId == null
          ? null
          : (await _repo.manufacturerById(item.manufacturerId!))?.name;
      final unitsRow = await _repo.itemUnitsFor(item.id);
      final baseUnitName = unitsRow == null
          ? null
          : (await _repo.unitById(unitsRow.baseUnitId))?.name;
      final largeUnitName = unitsRow == null
          ? null
          : (await _repo.unitById(unitsRow.largeUnitId))?.name;
      views.add(InventoryItemView(
        item: item,
        units: unitsRow,
        baseUnitName: baseUnitName,
        largeUnitName: largeUnitName,
        categoryName: category,
        manufacturerName: manufacturer,
        activeIngredients: ingredientsByItem[item.id] ?? const [],
        indicationNames: indicationsByItem[item.id] ?? const [],
      ));
    }
    return views;
  }
}