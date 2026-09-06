import 'package:drift/drift.dart';

/// Key-value application settings (§6 Design Lock).
///
/// Stores global defaults such as `partial_sale_markup_basis_points`.
/// Keys are stable strings; values are TEXT to allow flexible storage.
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();
  TextColumn get updatedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
