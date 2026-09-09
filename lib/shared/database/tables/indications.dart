import 'package:drift/drift.dart';

/// Reusable indication master list (الاستطباب / دلالة الاستخدام). Products link
/// to one or more of these rows via `item_indications` so the product
/// classification section can tag therapeutic uses from a typed, spell-checked
/// list (e.g. خافض حرارة، مسكن، مضاد التهاب، موسع قصبي).
@DataClassName('IndicationRow')
class Indications extends Table {
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