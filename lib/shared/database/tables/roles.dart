import 'package:drift/drift.dart';

/// Roles (§4.25). `name` is the canonical stable role code
/// (`role_admin`/`role_pharmacist`/`role_cashier`); `nameAr` holds the Arabic
/// display label.
@DataClassName('RoleRow')
class Roles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get nameAr => text()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}