import 'package:drift/drift.dart';

/// Reusable active-ingredient master list (الاسم الفعال / المادة الفعالة).
/// Products link to one or more of these rows via `item_active_ingredients`
/// instead of the legacy comma-delimited `items.active_ingredient` text, so the
/// same ingredient row is typed once, spell-checked by the dropdown, reused in
/// Smart Alternatives and searchable consistently.
@DataClassName('ActiveIngredientRow')
class ActiveIngredients extends Table {
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