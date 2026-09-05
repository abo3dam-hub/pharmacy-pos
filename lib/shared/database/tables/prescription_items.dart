import 'package:drift/drift.dart';
import 'items.dart';
import 'prescriptions.dart';

@DataClassName('PrescriptionItemRow')
@TableIndex(name: 'idx_prescription_items_prescription', columns: {#prescriptionId})
@TableIndex(name: 'idx_prescription_items_item', columns: {#itemId})
class PrescriptionItems extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionId =>
      text().references(Prescriptions, #id)();
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get quantityBase => integer()();
  TextColumn get dosage => text().nullable()();
  IntColumn get durationDays => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDispensed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (quantity_base > 0)',
      ];
}