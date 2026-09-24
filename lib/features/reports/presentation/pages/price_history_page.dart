import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';

/// Price change history — who changed which price, when, from what to what.
/// Reads the immutable audit trail (`action = 'price_change'`).
class PriceHistoryPage extends ConsumerStatefulWidget {
  const PriceHistoryPage({super.key});

  @override
  ConsumerState<PriceHistoryPage> createState() => _PriceHistoryPageState();
}

class _PriceHistoryPageState extends ConsumerState<PriceHistoryPage> {
  String _query = '';
  List<AuditLogRow> _rows = [];
  Map<String, String> _userNames = {};
  Map<String, String> _itemNames = {};
  bool _loading = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted) await _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final q = _query.trim();
    final rows = await (db.select(db.auditLogs)
          ..where((a) => a.action.equals('price_change'))
          ..orderBy([(a) => drift.OrderingTerm.desc(a.createdAt)])
          ..limit(200))
        .get();

    final filtered = q.isEmpty
        ? rows
        : rows.where((r) {
            final note = (r.note ?? '').toLowerCase();
            return note.contains(q.toLowerCase());
          }).toList();

    // Resolve names (best effort, cached per load).
    final userIds = {for (final r in filtered) r.userId};
    final itemIds = {for (final r in filtered) r.entityId};
    if (userIds.isNotEmpty) {
      final users = await (db.select(db.users)
            ..where((u) => u.id.isIn(userIds)))
          .get();
      _userNames = {for (final u in users) u.id: u.fullName};
    }
    if (itemIds.isNotEmpty) {
      final items = await (db.select(db.items)
            ..where((i) => i.id.isIn(itemIds)))
          .get();
      _itemNames = {for (final i in items) i.id: i.tradeName};
    }

    if (!mounted) return;
    setState(() {
      _rows = filtered;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: SearchField(
              hintText: l10n.searchHint,
              onChanged: (v) {
                _query = v;
                _load();
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _rows.isEmpty && !_loading
                ? Center(child: Text(l10n.noResults))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      return _PriceChangeCard(
                        row: row,
                        itemName:
                            _itemNames[row.entityId] ?? row.note ?? row.entityId,
                        userName: _userNames[row.userId] ?? '—',
                      );
                    },
                  ),
          ),
        ],
    );
  }
}

class _PriceChangeCard extends StatelessWidget {
  const _PriceChangeCard({
    required this.row,
    required this.itemName,
    required this.userName,
  });

  final AuditLogRow row;
  final String itemName;
  final String userName;

  static const _priceKeys = <String, String>{
    'selling_price_micros': 'سعر البيع',
    'sub_unit_price_micros': 'سعر الجزء',
    'wholesale_price_micros': 'سعر الجملة',
    'half_wholesale_price_micros': 'سعر نصف الجملة',
    'custom_price1_micros': 'سعر خاص 1',
    'custom_price2_micros': 'سعر خاص 2',
    'cost_micros': 'الكلفة',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(row.createdAt);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(date);

    Map<String, dynamic> before = {};
    Map<String, dynamic> after = {};
    try {
      if (row.beforeData != null) {
        before = jsonDecode(row.beforeData!) as Map<String, dynamic>;
      }
      if (row.afterData != null) {
        after = jsonDecode(row.afterData!) as Map<String, dynamic>;
      }
    } catch (_) {}

    final changes = <Widget>[];
    for (final entry in _priceKeys.entries) {
      final b = before[entry.key];
      final a = after[entry.key];
      if (b != a) {
        changes.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(entry.value)),
                Text(
                  b is int
                      ? Money.fromUnits(b).formatArabicDigits()
                      : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Icon(Icons.arrow_back, size: 14),
                Text(
                  a is int
                      ? Money.fromUnits(a).formatArabicDigits()
                      : '—',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(itemName, style: theme.textTheme.titleSmall),
                ),
                Text(dateStr, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'بواسطة: $userName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(),
            ...changes,
          ],
        ),
      ),
    );
  }
}
