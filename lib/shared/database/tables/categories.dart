import 'package:drift/drift.dart';

/// Main categories / التصنيف الرئيسي (§4.3). Products carry at most one
/// optional category; the `sub_categories` table was removed in Phase 18
/// (v12) along with therapeutic groups in favour of relational indications.
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