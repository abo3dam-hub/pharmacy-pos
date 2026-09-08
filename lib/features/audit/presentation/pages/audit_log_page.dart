import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_data_table.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/search_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/audit_controller.dart';
import '../../domain/entities/audit_entry.dart';
import '../widgets/audit_detail_dialog.dart';
import '../widgets/audit_labels.dart';

/// Phase 12 Audit Log viewer (سجل التدقيق): read-only, paginated audit trail
/// with search + date/actor/action filters. Route guard requires `audit.view`.
///
/// Rows open a detail dialog with the full JSON before/after snapshots. No
/// deletion, no export buttons here — the trail is append-only (§17).
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

/// Sentinel representing the "all" option in action/actor dropdowns
/// (DropdownButton cannot treat `null` as a selectable menu value).
const String _all = '__all__';

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  final _searchController = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  String? _actorId = _all;
  String? _action = _all;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(auditControllerProvider.notifier)
          .load(ref.read(authControllerProvider).actingRoleId),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref
        .read(auditControllerProvider.notifier)
        .setFilters(ref.read(auditControllerProvider).filters.copyWith(search: query));
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'من',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked;
      if (_to != null && _to!.isBefore(_from!)) _to = _from;
    });
    _applyFilters();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'إلى',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _to = picked;
      if (_from != null && _from!.isAfter(_to!)) _from = _to;
    });
    _applyFilters();
  }

  AuditFilters _buildFilters() {
    final state = ref.read(auditControllerProvider);
    return AuditFilters(
      search: state.filters.search,
      fromMillis: _from?.millisecondsSinceEpoch,
      toMillis: _to == null
          ? null
          : DateTime(_to!.year, _to!.month, _to!.day + 1)
              .millisecondsSinceEpoch,
      userId: _actorId == _all ? null : _actorId,
      action: _action == _all ? null : _action,
    );
  }

  void _applyFilters() {
    ref.read(auditControllerProvider.notifier).setFilters(_buildFilters());
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _from = null;
      _to = null;
      _actorId = _all;
      _action = _all;
    });
    ref.read(auditControllerProvider.notifier).setFilters(const AuditFilters());
  }

  void _toPage(int page) => ref.read(auditControllerProvider.notifier).toPage(page);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(auditControllerProvider);
    final typography = context.appTypography;

    return LoadingOverlay(
      visible: state.status == AuditStatus.loading,
      label: l10n.commonLoading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(l10n, state),
          Expanded(
            child: AppResponsiveLayout(
              desktop: _buildTable(l10n, state, typography),
              tablet: _buildTable(l10n, state, typography),
              compact: _buildCards(l10n, state, typography),
            ),
          ),
          _buildPager(l10n, state),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n, AuditViewState state) {
    final hasFilters =
        _from != null || _to != null || _actorId != _all || _action != _all;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.l,
        AppSpacing.xl,
        AppSpacing.s,
      ),
      child: Wrap(
        spacing: AppSpacing.m,
        runSpacing: AppSpacing.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: SearchField(
              controller: _searchController,
              hintText: l10n.auditSearchHint,
              onChanged: _onSearchChanged,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickFrom,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _from == null
                  ? l10n.auditFromDate
                  : _formatDate(_from!.millisecondsSinceEpoch),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickTo,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _to == null ? l10n.auditToDate : _formatDate(_to!.millisecondsSinceEpoch),
            ),
          ),
          DropdownButton<String>(
            value: _action,
            items: [
              DropdownMenuItem(value: _all, child: Text(l10n.auditAllActions)),
              for (final action in state.actions)
                DropdownMenuItem(
                  value: action,
                  child: Text(l10n.auditActionLabel(action)),
                ),
            ],
            onChanged: (v) {
              setState(() => _action = v);
              _applyFilters();
            },
          ),
          DropdownButton<String>(
            value: _actorId,
            items: [
              DropdownMenuItem(value: _all, child: Text(l10n.auditAllUsers)),
              for (final actor in state.actors)
                DropdownMenuItem(value: actor.userId, child: Text(actor.username)),
            ],
            onChanged: (v) {
              setState(() => _actorId = v);
              _applyFilters();
            },
          ),
          if (hasFilters)
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: l10n.auditClearFilters,
            ),
        ],
      ),
    );
  }

  Widget _buildTable(
    AppLocalizations l10n,
    AuditViewState state,
    AppTypography typography,
  ) {
    return AppDataTable(
      emptyMessage: l10n.auditEmpty,
      columns: [
        DataColumn(label: Text(l10n.auditColumnDate)),
        DataColumn(label: Text(l10n.auditColumnUser)),
        DataColumn(label: Text(l10n.auditColumnAction)),
        DataColumn(label: Text(l10n.auditColumnEntity)),
        DataColumn(label: Text(l10n.auditColumnEntityId)),
        DataColumn(label: Text(l10n.auditColumnNote)),
      ],
      rows: [
        for (final entry in state.items)
          DataRow(
            onSelectChanged: (_) => showAuditDetailDialog(context, entry),
            cells: [
              DataCell(Text(_formatDate(entry.createdAt))),
              DataCell(Text(entry.actorLabel)),
              DataCell(Text(l10n.auditActionLabel(entry.action))),
              DataCell(Text(l10n.auditEntityTypeLabel(entry.entityType))),
              DataCell(Text(entry.entityId)),
              DataCell(
                Text(
                  entry.note ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCards(
    AppLocalizations l10n,
    AuditViewState state,
    AppTypography typography,
  ) {
    if (state.items.isEmpty) {
      return Center(
        child: Text(l10n.auditEmpty, style: typography.labelSmall),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      children: [
        for (final entry in state.items)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            child: ListTile(
              onTap: () => showAuditDetailDialog(context, entry),
              leading: Icon(
                _actionIcon(entry.action),
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                l10n.auditActionLabel(entry.action),
                style: typography.sectionTitle,
              ),
              subtitle: Text(
                '${entry.actorLabel} • '
                '${l10n.auditEntityTypeLabel(entry.entityType)} • '
                '${entry.entityId} • ${_formatDate(entry.createdAt)}',
                style: typography.bodySecondary,
              ),
            ),
          ),
      ],
    );
  }

  IconData _actionIcon(String action) => switch (action) {
        'create' => Icons.add_circle_outline,
        'update' => Icons.edit_outlined,
        'delete' => Icons.delete_outline,
        'login' => Icons.login,
        'logout' => Icons.logout,
        'login_failed' => Icons.error_outline,
        'void' => Icons.block_outlined,
        'restore' => Icons.restore,
        'price_change' => Icons.swap_horiz,
        'bulk_op' => Icons.splitscreen_outlined,
        'audit_config' => Icons.settings_outlined,
        'backup' => Icons.backup_outlined,
        'restore_backup' => Icons.history,
        _ => Icons.info_outline,
      };

  Widget _buildPager(AppLocalizations l10n, AuditViewState state) {
    final pageCount = state.pageCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.s,
        AppSpacing.xl,
        AppSpacing.l,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${state.page} / ${pageCount == 0 ? 1 : pageCount}',
            style: context.appTypography.bodySecondary,
          ),
          const SizedBox(width: AppSpacing.m),
          IconButton(
            onPressed: state.page <= 1 ? null : () => _toPage(state.page - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.commonPrevious,
          ),
          IconButton(
            onPressed: state.page >= pageCount || pageCount == 0
                ? null
                : () => _toPage(state.page + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.commonNext,
          ),
        ],
      ),
    );
  }

  static String _formatDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}