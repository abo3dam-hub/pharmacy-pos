import 'package:drift/drift.dart';

/// Registry of allowable units (§4.5). `name` holds the unique Arabic name
/// (name_ar); `nameEn` is the secondary English label. The base unit is the
/// singular quantity unit all stock is tracked in; item-specific base/large
/// relations live in [item_units](ItemUnits).
@DataClassName('UnitRow')
class Units extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get nameEn => text().nullable()();
  TextColumn get abbreviation => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}