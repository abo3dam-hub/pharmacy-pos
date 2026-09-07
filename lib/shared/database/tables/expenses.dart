import 'package:drift/drift.dart';
import 'suppliers.dart';
import 'users.dart';

/// Expenses / المصروفات (§4.20, §19, Phase 9). `description` is NOT NULL per
/// §4.20; `category` stores the stable category *code* (see
/// `expense_categories`); `paymentMethod` is `'cash'` (drawer outflow) or
/// `'card'` (bank payment, no drawer move); `expenseNumber` is the printable
/// expense reference (`EXP-YYYY-NNNN`-style); `userId` records the operator;
/// an optional scanned receipt photo may be referenced by `receiptPath`.
@DataClassName('ExpenseRow')
@TableIndex(name: 'idx_expenses_date', columns: {#expenseDate})
@TableIndex(name: 'idx_expenses_category', columns: {#category})
class Expenses extends Table {
  TextColumn get id => text()();
  IntColumn get amountMicros => integer()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  IntColumn get expenseDate => integer()();
  TextColumn get supplierId =>
      text().nullable().references(Suppliers, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get receiptPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();
  TextColumn get expenseNumber => text().withDefault(const Constant(''))();
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