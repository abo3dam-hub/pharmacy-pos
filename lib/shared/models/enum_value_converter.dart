import 'package:drift/drift.dart';

import 'enums.dart';

/// [TypeConverter] that persists an enum's *canonical value string* rather
/// than the Dart member [Enum.name]. Used where the architecture plan's stored
/// TEXT value is not a legal Dart identifier (e.g. the reserved word `return`),
/// so the member name stays a readable identifier while the database column
/// records the exact plan value.
class EnumValueConverter<T extends Enum> extends TypeConverter<T, String> {
  const EnumValueConverter(this.values);

  /// Member → stored TEXT value mapping.
  final Map<T, String> values;

  @override
  T fromSql(String fromDb) {
    return values.entries.firstWhere((e) => e.value == fromDb).key;
  }

  @override
  String toSql(T value) {
    final stored = values[value];
    return stored ?? value.name;
  }
}

const invoiceTypeValues = EnumValueConverter<InvoiceType>({
  InvoiceType.sale: 'sale',
  InvoiceType.hybrid: 'hybrid',
  InvoiceType.return_invoice: 'return',
});

const journalReferenceTypeValues = EnumValueConverter<JournalReferenceType>({
  JournalReferenceType.sale: 'sale',
  JournalReferenceType.purchase: 'purchase',
  JournalReferenceType.return_invoice: 'return',
  JournalReferenceType.expense: 'expense',
  JournalReferenceType.cashbox: 'cashbox',
  JournalReferenceType.opening_balance: 'opening_balance',
  JournalReferenceType.adjustment: 'adjustment',
  JournalReferenceType.manual: 'manual',
});