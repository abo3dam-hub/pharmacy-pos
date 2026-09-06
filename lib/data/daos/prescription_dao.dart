import 'package:drift/drift.dart';

import '../../core/data_grid/page_request.dart';
import '../../core/util/ids.dart';
import '../../shared/database/app_database.dart';
import '../../shared/models/enums.dart';

/// One prescription row for the prescriptions grid paired with the customer
/// name it belongs to (search is SQL-side, §22/§30).
class PrescriptionListRow {
  const PrescriptionListRow({required this.row, required this.customerName});

  final PrescriptionRow row;
  final String customerName;
}

/// A prescription item line composed with the item's trade name and current
/// master selling price (for display; quantities are authoritative base units).
class PrescriptionItemView {
  const PrescriptionItemView({
    required this.id,
    required this.prescriptionId,
    required this.itemId,
    required this.itemTradeName,
    required this.quantityBase,
    required this.dosage,
    required this.frequency,
    required this.durationDays,
    required this.notes,
    required this.isDispensed,
    required this.unitPriceMicros,
  });

  final String id;
  final String prescriptionId;
  final String itemId;
  final String itemTradeName;
  final int quantityBase;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final String? notes;
  final bool isDispensed;

  /// Item master selling price per base unit (money micro-units, §8).
  final int unitPriceMicros;

  int get lineTotalMicros => quantityBase * unitPriceMicros;
}

/// A prescription with its item lines — used by the detail page and by the
/// prescription→sale preparation mechanism (Phase 6 POS consumes [items]).
class PrescriptionDetail {
  const PrescriptionDetail({
    required this.prescription,
    required this.customerName,
    required this.items,
  });

  final PrescriptionRow prescription;
  final String customerName;
  final List<PrescriptionItemView> items;
}

/// DAO for the prescriptions master (§4.12/§4.13) — header plus line items.
///
/// A prescription always belongs to a customer ([Prescriptions.customerId] is
/// NOT NULL — no orphan prescriptions) and every item references a real item.
/// Historical rows stay valid even if the customer/item is later deactivated.
class PrescriptionDao {
  const PrescriptionDao(this._db);

  final AppDatabase _db;

  Future<PrescriptionRow?> byId(String id) => (_db.select(_db.prescriptions)
        ..where((p) => p.id.equals(id)))
      .getSingleOrNull();

  /// Paginated prescription search across number / patient / doctor, optionally
  /// scoped to one customer. Filtering happens in SQL (never load-all).
  Future<PageResult<PrescriptionListRow>> search(
    PageRequest page, {
    String? customerId,
  }) async {
    final q = page.search.trim();
    final preds = _db.prescriptions;
    final countExpr = preds.id.count();
    final count = _db.selectOnly(_db.prescriptions)..addColumns([countExpr]);
    final query = _db.select(preds).join([
      innerJoin(_db.customers, _db.customers.id.equalsExp(preds.customerId)),
    ]);
    if (q.isNotEmpty) {
      final like = '%${_escapeLike(q)}%';
      final cond = preds.prescriptionNumber.like(like) |
          preds.patientName.like(like) |
          preds.doctorName.like(like);
      count.where(cond);
      query.where(cond);
    }
    if (customerId != null && customerId.isNotEmpty) {
      count.where(preds.customerId.equals(customerId));
      query.where(preds.customerId.equals(customerId));
    }
    final total = (await count.getSingle()).read(countExpr) ?? 0;
    query
      ..orderBy([
        OrderingTerm.desc(preds.createdAt),
        OrderingTerm.desc(preds.prescriptionNumber),
      ])
      ..limit(page.pageSize, offset: page.offset);
    final rows = await query.get();
    return PageResult(
      items: [
        for (final r in rows)
          PrescriptionListRow(
            row: r.readTable(_db.prescriptions),
            customerName: r.readTable(_db.customers).name,
          ),
      ],
      total: total,
      request: page,
    );
  }

  /// Active (not yet dispensed/expired/cancelled) prescriptions for a customer,
  /// newest first — the lookup the POS will use to attach a prescription.
  Future<List<PrescriptionRow>> activeForCustomer(String customerId) async {
    final query = _db.select(_db.prescriptions)
      ..where((p) =>
          p.customerId.equals(customerId) &
          p.status.equalsValue(PrescriptionStatus.active));
    query.orderBy([
      (p) => OrderingTerm.desc(p.createdAt),
      (p) => OrderingTerm.desc(p.prescriptionNumber),
    ]);
    return query.get();
  }

  /// Full header + item lines for [id], resolving the customer name and item
  /// trade names. Null when the prescription or any referenced data is gone.
  Future<PrescriptionDetail?> detail(String id) async {
    final header = await byId(id);
    if (header == null) return null;
    final customer = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(header.customerId)))
        .getSingleOrNull();
    final customerName = customer?.name ?? '';
    final itemRows = await (_db.select(_db.prescriptionItems)
          ..where((pi) => pi.prescriptionId.equals(id))
          ..orderBy([(pi) => OrderingTerm.asc(pi.createdAt)]))
        .get();
    final itemIds = {for (final it in itemRows) it.itemId};
    final (itemNames, unitPrices) = await _itemMeta(itemIds);
    return PrescriptionDetail(
      prescription: header,
      customerName: customerName,
      items: [
        for (final it in itemRows)
          PrescriptionItemView(
            id: it.id,
            prescriptionId: id,
            itemId: it.itemId,
            itemTradeName: itemNames[it.itemId] ?? '',
            quantityBase: it.quantityBase,
            dosage: it.dosage,
            frequency: it.frequency,
            durationDays: it.durationDays,
            notes: it.notes,
            isDispensed: it.isDispensed,
            unitPriceMicros: unitPrices[it.itemId] ?? 0,
          ),
      ],
    );
  }

  /// Cheap IN lookup for item trade names + master selling price (bounded).
  Future<(Map<String, String>, Map<String, int>)> _itemMeta(Set<String> ids) async {
    if (ids.isEmpty) return (<String, String>{}, <String, int>{});
    final rows = await (_db.select(_db.items)..where((i) => i.id.isIn(ids))).get();
    final names = <String, String>{};
    final prices = <String, int>{};
    for (final r in rows) {
      names[r.id] = r.tradeName;
      prices[r.id] = r.sellingPriceMicros;
    }
    return (names, prices);
  }

  /// Inserts the prescription header and all its items in one atomic
  /// transaction — no partial prescriptions, no orphan items (§26, §27).
  Future<void> insertWithItems(
    PrescriptionRow header,
    List<PrescriptionItemRow> items,
  ) {
    return _db.transaction(() async {
      await _db.into(_db.prescriptions).insert(header);
      for (final item in items) {
        await _db.into(_db.prescriptionItems).insert(item);
      }
    });
  }

  static String newPrescriptionNumber() =>
      'RX-${DateTime.now().millisecondsSinceEpoch}';

  static String newPrescriptionItemId() => newId('rxi');

  static String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}