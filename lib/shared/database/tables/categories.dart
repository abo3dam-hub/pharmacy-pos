import 'package:drift/drift.dart';

/// Main categories / التصنيف الرئيسي (§4.3). Sub-categories live in the
/// dedicated `sub_categories` table (1–2 levels: main + sub).
@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}