import 'package:drift/drift.dart';

/// All permission codes used by the RBAC engine (§4.24). `name` is the
/// canonical permission code (`sales.view`, `inventory.stock_adjust`,
/// ...); `nameAr` holds the Arabic display label.
@DataClassName('PermissionRow')
class Permissions extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get nameAr => text()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}