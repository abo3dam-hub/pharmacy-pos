import 'package:drift/drift.dart';

@DataClassName('ManufacturerRow')
class Manufacturers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get country => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}