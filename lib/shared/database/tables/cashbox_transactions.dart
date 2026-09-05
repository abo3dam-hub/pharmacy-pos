import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'users.dart';

/// Cash drawer ledger / حركة الصندوق (§4.21, §21). Every 0 ≠ ±micros move is
/// recorded with the running balance; `userId` is always set.
@DataClassName('CashboxTransactionRow')
@TableIndex(name: 'idx_cashbox_type', columns: {#type})
@TableIndex(name: 'idx_cashbox_created', columns: {#createdAt})
class CashboxTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<CashboxTransactionType>()();

  /// Signed amount added (positive) or removed (negative) from the drawer.
  IntColumn get amountMicros => integer()();

  /// Running drawer balance after this transaction.
  IntColumn get remainingMicros => integer()();

  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount_micros != 0)',
      ];
}