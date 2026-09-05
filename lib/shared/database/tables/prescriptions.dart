import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'customers.dart';
import 'users.dart';

@DataClassName('PrescriptionRow')
@TableIndex(name: 'idx_prescriptions_status', columns: {#status})
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get prescriptionNumber => text().unique()();

  /// Patient must be linked to a customer record (§4.12).
  TextColumn get customerId =>
      text().references(Customers, #id)();

  TextColumn get patientName => text()();
  IntColumn get patientAge => integer().nullable()();
  TextColumn get patientGender => text().nullable()();
  TextColumn get doctorName => text().nullable()();
  TextColumn get doctorSpecialty => text().nullable()();
  TextColumn get clinicHospital => text().nullable()();
  IntColumn get issuedAt => integer()();
  IntColumn get expiryAt => integer().nullable()();
  IntColumn get totalMicros => integer().withDefault(const Constant(0))();
  TextColumn get status => textEnum<PrescriptionStatus>()();

  /// Scanned image path (§4.12).
  TextColumn get imagePath => text().nullable()();

  TextColumn get notes => text().nullable()();
  TextColumn get createdBy => text().references(Users, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}