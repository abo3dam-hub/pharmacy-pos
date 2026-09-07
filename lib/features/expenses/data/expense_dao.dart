import 'package:drift/drift.dart';

import '../../../core/data_grid/page_request.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/models/enums.dart';
import '../domain/entities/expense_list_item.dart';

/// Read side of the expenses journal (§4.20 Phase 9): a paged, DB-side-filtered
/// listing joined with category / operator / supplier display names. Loading
/// the whole table into memory is forbidden — always LIMIT/OFFSET.
class ExpenseDao {
  const ExpenseDao(this._db);

  final AppDatabase _db;

  Future<PageResult<ExpenseListItem>> listExpenses({
    required PageRequest page,
    String? categoryCode,
    ExpensePaymentMethod? paymentMethod,
    bool? isVoided,
    int? fromMillis,
    int? toMillis,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (categoryCode != null && categoryCode.isNotEmpty) {
      where.add('e.category = ?');
      args.add(categoryCode);
    }
    if (paymentMethod != null) {
      where.add('e.payment_method = ?');
      args.add(paymentMethod.name);
    }
    if (isVoided != null) {
      where.add('e.is_voided = ?');
      args.add(isVoided ? 1 : 0);
    }
    if (fromMillis != null) {
      where.add('e.expense_date >= ?');
      args.add(fromMillis);
    }
    if (toMillis != null) {
      where.add('e.expense_date < ?');
      args.add(toMillis);
    }
    if (page.search.trim().isNotEmpty) {
      where.add('(e.description LIKE ? OR e.expense_number LIKE ? OR '
          'COALESCE(s.name, \'\') LIKE ? OR e.notes LIKE ?)');
      final like = '%${page.search.trim()}%';
      args.add(like);
      args.add(like);
      args.add(like);
      args.add(like);
    }
    final condition = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final countRow = await _db.customSelect(
      'SELECT COUNT(*) AS c FROM expenses e $condition',
      variables: [for (final a in args) _variable(a)],
    ).getSingle();
    final total = countRow.read<int>('c');

    final rows = await _db.customSelect(
      'SELECT e.*, '
      'COALESCE(c.name, e.category) AS category_name, '
      'COALESCE(c.account_code, \'\') AS category_account_code, '
      'u.full_name AS user_name, s.name AS supplier_name '
      'FROM expenses e '
      'LEFT JOIN expense_categories c ON c.code = e.category '
      'LEFT JOIN users u ON u.id = e.user_id '
      'LEFT JOIN suppliers s ON s.id = e.supplier_id '
      '$condition '
      'ORDER BY e.expense_date DESC, e.id DESC '
      'LIMIT ? OFFSET ?',
      variables: [
        for (final a in args) _variable(a),
        Variable.withInt(page.pageSize),
        Variable.withInt(page.offset),
      ],
    ).get();

    return PageResult(
      items: [
        for (final r in rows)
          ExpenseListItem(
            id: r.read<String>('id'),
            expenseNumber: r.read<String>('expense_number'),
            amountMicros: r.read<int>('amount_micros'),
            categoryCode: r.read<String>('category'),
            categoryName: r.read<String>('category_name'),
            categoryAccountCode: r.read<String>('category_account_code'),
            description: r.read<String>('description'),
            expenseDate: r.read<int>('expense_date'),
            supplierId: r.read<String?>('supplier_id'),
            supplierName: r.read<String?>('supplier_name'),
            userId: r.read<String?>('user_id'),
            userName: r.read<String?>('user_name'),
            receiptPath: r.read<String?>('receipt_path'),
            hasReceipt: r.read<String?>('receipt_path') != null,
            notes: r.read<String?>('notes'),
            paymentMethod: r.read<String>('payment_method'),
            isVoided: r.read<int>('is_voided') != 0,
            createdAt: r.read<int>('created_at'),
            updatedAt: r.read<int>('updated_at'),
          ),
      ],
      total: total,
      request: page,
    );
  }

  static Variable<Object> _variable(Object value) {
    if (value is int) return Variable.withInt(value);
    return Variable.withString('$value');
  }
}