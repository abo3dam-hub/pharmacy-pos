import 'package:drift/drift.dart';

/// Registry of allowable base units of measure.
///
/// The base unit is the singular quantity unit all stock is tracked in;
/// `1` base unit is always a whole strip/tablet/etc. Item-specific
/// conversion relations live in [item_units](ItemUnits).
@DataClassName('UnitRow')
class Units extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get abbreviation => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isBase => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}