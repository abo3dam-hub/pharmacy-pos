import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'suppliers.dart';
import 'users.dart';

/// Expenses / المصروفات (§4.20, §19). `description` is NOT NULL per §4.20;
/// `userId` records the user who booked the expense; an optional scanned
/// receipt photo may be referenced by `receiptPath`.
@DataClassName('ExpenseRow')
@TableIndex(name: 'idx_expenses_date', columns: {#expenseDate})
@TableIndex(name: 'idx_expenses_category', columns: {#category})
class Expenses extends Table {
  TextColumn get id => text()();
  IntColumn get amountMicros => integer()();
  TextColumn get category => textEnum<ExpenseCategory>()();
  TextColumn get description => text()();
  IntColumn get expenseDate => integer()();
  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get receiptPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount_micros > 0)',
      ];
}