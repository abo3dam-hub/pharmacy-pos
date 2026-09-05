import 'package:drift/drift.dart';
import 'categories.dart';

/// Sub-categories / التصنيف الفرعي belonging to one main category (§4.4).
@DataClassName('SubCategoryRow')
@TableIndex(name: 'idx_sub_categories_category', columns: {#categoryId})
class SubCategories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, name},
      ];
}