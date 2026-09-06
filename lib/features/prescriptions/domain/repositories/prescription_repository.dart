import '../../../../core/data_grid/page_request.dart';
import '../../../../data/daos/prescription_dao.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';

/// One prescription line in the create/edit draft (§4.13). Quantity is
/// authoritative in base units (§7) — never conflicting display totals.
class PrescriptionItemDraft {
  const PrescriptionItemDraft({
    required this.itemId,
    required this.quantityBase,
    this.dosage,
    this.frequency,
    this.durationDays,
    this.notes,
  });

  final String itemId;
  final int quantityBase;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final String? notes;
}

/// Input draft for creating a prescription (§4.12). [customerId] is required —
/// no orphan prescriptions; walk-in cash sales are not prescriptions.
class PrescriptionDraft {
  const PrescriptionDraft({
    required this.customerId,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    this.doctorName,
    this.doctorSpecialty,
    this.clinicHospital,
    this.issuedAt,
    this.expiryAt,
    this.notes,
    this.imagePath,
    this.items = const [],
  });

  final String customerId;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final String? doctorName;
  final String? doctorSpecialty;
  final String? clinicHospital;
  final int? issuedAt;
  final int? expiryAt;
  final String? notes;

  /// Scanned image path (simplest local path form; no binary in SQLite).
  final String? imagePath;
  final List<PrescriptionItemDraft> items;
}

/// A prescription snapshot ready for the POS (Phase 6) to attach to a sale —
/// the "prepare prescription reference" mechanism. No redesign needed later:
/// the sale writes a link to the prescription header and consumes these lines.
class PreparedSalePrescription {
  const PreparedSalePrescription({
    required this.prescription,
    required this.customerName,
    required this.items,
  });

  final PrescriptionRow prescription;
  final String customerName;
  final List<PrescriptionItemView> items;

  bool get isReady =>
      prescription.status == PrescriptionStatus.active && items.isNotEmpty;
}

/// Supplies prescription domain data; implementation maps to the Drift
/// [PrescriptionRow]/[PrescriptionItemRow]. Header + items are written in one
/// atomic transaction — no orphans (§26).
abstract interface class PrescriptionRepository {
  /// Database handle for RBAC checks in use cases.
  AppDatabase get database;

  /// Paginated search (optionally scoped to one customer), SQL-side (§30).
  Future<PageResult<PrescriptionListRow>> search(
    PageRequest page, {
    String? customerId,
  });

  Future<PrescriptionRow?> findById(String id);

  /// Full header + item lines with customer and item names.
  Future<PrescriptionDetail?> detail(String id);

  /// Creates an active prescription with its item lines (transactional).
  Future<PrescriptionRow> create(PrescriptionDraft draft,
      {required String userId});

  /// Active prescriptions for a customer, newest first (POS lookup).
  Future<List<PrescriptionRow>> activeForCustomer(String customerId);

  /// Builds the Phase-6-ready snapshot for [id]; validates active status and
  /// that the prescription carries at least one line.
  Future<PreparedSalePrescription> prepareForSale(String id);
}