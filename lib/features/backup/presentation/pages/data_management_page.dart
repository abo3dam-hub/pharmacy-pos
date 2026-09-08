import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/backup_results.dart';

/// Phase 13 Data Management page (النسخ الاحتياطي والاستعادة وتصدير
/// البيانات). Three permission-gated workflows, all routed through the
/// controller: backup / restore / export. Actions stay busy-aware and every
/// destructive step flows through the confirmation dialogs.
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  @override
  ConsumerState<DataManagementPage> createState() =>
      _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  String? _backupDestinationDir;
  String? _exportDestinationDir;
  String? _archivePath;
  RestorePreview? _preview;

  Set<String> get _permissions =>
      ref.read(authControllerProvider).permissions;
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  bool get _canBackup => _permissions.contains(Perm.backup);
  bool get _canRestore => _permissions.contains(Perm.backupRestore);
  bool get _canExport => _permissions.contains(Perm.exportData);

  Future<void> _pickBackupFolder() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.dataManagementChooseDestinationFolder,
    );
    if (dir != null) setState(() => _backupDestinationDir = dir);
  }

  Future<void> _pickExportFolder() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.dataManagementExportDestination,
    );
    if (dir != null) setState(() => _exportDestinationDir = dir);
  }

  Future<void> _pickArchive() async {
    final result = await FilePicker.pickFile(
      dialogTitle: l10n.dataManagementChooseArchive,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (result == null) return;
    final path = result.path;
    if (path == null) return;
    setState(() {
      _archivePath = path;
      _preview = null;
    });
    try {
      final preview = await ref
          .read(dataManagementControllerProvider.notifier)
          .preview(actingRoleId: _actingRoleId, archivePath: path);
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      setState(() => _preview = preview);
      if (!preview.valid) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('${loc.dataManagementRestoreInvalid}\n'
                '${preview.reason ?? ''}'),
          ));
      }
    } catch (_) {
      // Unauthorized / unexpected: surface a generic message.
      if (mounted) {
        final loc = AppLocalizations.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(loc.authPermissionDenied)));
      }
    }
  }

  Future<void> _createBackup() async {
    if (!_canBackup) {
      _showNotPermitted();
      return;
    }
    final failure = await ref.read(dataManagementControllerProvider.notifier)
        .createBackup(
          actingRoleId: _actingRoleId,
          actingUserId: _actingUserId,
          destinationDirectory: _backupDestinationDir,
        );
    if (!mounted) return;
    if (failure != null) {
      _showFailure(failure);
      return;
    }
    final last = ref.read(dataManagementControllerProvider).lastBackup;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text('${l10n.dataManagementBackupCreated}: ${last?.fileName ?? ''}'),
      ));
  }

  Future<void> _doRestore() async {
    if (!_canRestore || _archivePath == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataManagementRestoreConfirmTitle),
        content: Text(l10n.dataManagementRestoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.dataManagementRestoreNow),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final failure = await ref.read(dataManagementControllerProvider.notifier)
        .restore(
          actingRoleId: _actingRoleId,
          actingUserId: _actingUserId,
          archivePath: _archivePath!,
        );
    if (!mounted) return;
    final state = ref.read(dataManagementControllerProvider);
    if (failure != null) {
      _showFailure(failure);
      // A failed restore that closed the live connection must lead to a
      // restart: the data on disk is safe (rolled back to the emergency
      // backup, which stays preserved) but the in-memory connection is no
      // longer usable.
      if (state.dbClosed) {
        await _promptRestartRequired();
      }
      return;
    }
    // Successful restore replaced the live database file, so the in-memory
    // singleton connection must not be used further — restart is required.
    await _promptRestartRequired();
  }

  Future<void> _promptRestartRequired() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dataManagementRestartRequiredTitle),
        content: Text(l10n.dataManagementRestoreRestartRequired),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
    if (mounted) context.go('/login');
  }

  Future<void> _doExport() async {
    if (!_canExport) {
      _showNotPermitted();
      return;
    }
    final failure = await ref.read(dataManagementControllerProvider.notifier)
        .exportData(
          actingRoleId: _actingRoleId,
          destinationDirectory:
              _exportDestinationDir!,
        );
    if (!mounted) return;
    if (failure != null) {
      _showFailure(failure);
      return;
    }
    final last = ref.read(dataManagementControllerProvider).lastExport;
    final summary = last == null
        ? ''
        : ' — ${l10n.dataManagementExportSummary(
            last.totalRows, last.tableCount)}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('${l10n.dataManagementExportDone}$summary')));
  }

  void _showNotPermitted() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(l10n.dataManagementNotPermitted)));
  }

  void _showFailure(Failure failure) {
    if (!mounted) return;
    final message = switch (failure) {
      UnauthorizedFailure() => l10n.authPermissionDenied,
      ValidationFailure() => failure.message,
      InvalidOperationFailure() => failure.message,
      _ => failure.message,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataManagementControllerProvider);
    final typography = Theme.of(context).textTheme;
    final lastBackup = state.lastBackup;
    final lastRestore = state.lastRestore;
    final lastExport = state.lastExport;

    if (!_canBackup && !_canRestore && !_canExport) {
      return Center(child: Text(l10n.dataManagementNotPermitted));
    }

    return LoadingOverlay(
      visible: state.busy,
      label: l10n.commonLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (_canBackup)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.dataManagementBackupTitle,
                        style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Text(l10n.dataManagementBackupHint,
                        style: typography.bodySmall),
                    const SizedBox(height: AppSpacing.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickBackupFolder,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: Text(_backupDestinationDir ??
                                l10n.dataManagementChooseDestinationFolder),
                            style: OutlinedButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        FilledButton.icon(
                          onPressed: _createBackup,
                          icon: const Icon(Icons.backup_outlined),
                          label: Text(l10n.dataManagementCreateBackup),
                        ),
                      ],
                    ),
                    if (lastBackup != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      _InfoRow(
                        label: l10n.dataManagementBackupSize(
                            _formatBytes(lastBackup.archiveSizeBytes)),
                        value: lastBackup.fileName,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_canRestore) ...[
            const SizedBox(height: AppSpacing.m),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.dataManagementRestoreTitle,
                        style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Text(l10n.dataManagementRestoreHint,
                        style: typography.bodySmall),
                    const SizedBox(height: AppSpacing.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickArchive,
                            icon: const Icon(Icons.archive_outlined),
                            label: Text(_archivePath == null
                                ? l10n.dataManagementChooseArchive
                                : _basename(_archivePath!)),
                            style: OutlinedButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        FilledButton.icon(
                          onPressed:
                              (_archivePath != null && _preview?.valid == true)
                                  ? _doRestore
                                  : null,
                          icon: const Icon(Icons.settings_backup_restore),
                          label: Text(l10n.dataManagementRestoreNow),
                        ),
                      ],
                    ),
                    if (_preview != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      _previewPanel(_preview!, l10n),
                    ],
                    if (lastRestore != null) ...[
                      const SizedBox(height: AppSpacing.s),
                      _InfoRow(
                        label: l10n.dataManagementRestorePreviewDate,
                        value:
                            '${_formatMillis(lastRestore.manifest.createdAtMillis)} — ${lastRestore.emergencyBackupPath}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_canExport) ...[
            const SizedBox(height: AppSpacing.m),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.dataManagementExportTitle,
                        style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.s),
                    Text(l10n.dataManagementExportHint,
                        style: typography.bodySmall),
                    const SizedBox(height: AppSpacing.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickExportFolder,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: Text(_exportDestinationDir ??
                                l10n.dataManagementExportDestination),
                            style: OutlinedButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        FilledButton.icon(
                          onPressed: _exportDestinationDir == null
                              ? null
                              : _doExport,
                          icon: const Icon(Icons.download_outlined),
                          label: Text(l10n.dataManagementExportNow),
                        ),
                      ],
                    ),
                    if (lastExport != null) ...[
                      const SizedBox(height: AppSpacing.l),
                      _InfoRow(
                        label: l10n.dataManagementExportSummary(
                            lastExport.totalRows, lastExport.tableCount),
                        value:
                            '${lastExport.directory} (${_formatBytes(lastExport.totalBytes)})',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewPanel(RestorePreview preview, AppLocalizations l10n) {
    final manifest = preview.manifest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoRow(
          label: l10n.dataManagementRestorePreviewStatus,
          value: preview.valid
              ? l10n.dataManagementRestorePreviewValid
              : l10n.dataManagementRestorePreviewInvalid,
        ),
        if (preview.reason != null && preview.reason!.isNotEmpty)
          _InfoRow(label: l10n.dataManagementRestoreInvalid, value: preview.reason!),
        if (manifest != null) ...[
          _InfoRow(
            label: l10n.dataManagementRestorePreviewDate,
            value: _formatMillis(manifest.createdAtMillis),
          ),
          _InfoRow(
            label: l10n.dataManagementRestorePreviewSchema,
            value: l10n.dataManagementRestoreSchemaNote(manifest.schemaVersion),
          ),
          _InfoRow(
            label: l10n.dataManagementRestorePreviewApp,
            value: manifest.applicationVersion,
          ),
          _InfoRow(
            label: l10n.dataManagementFilesCount(manifest.files.length),
            value: manifest.databaseFileName,
          ),
        ],
      ],
    );
  }

  AppLocalizations get l10n => AppLocalizations.of(context);

  static String _formatMillis(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _basename(String path) {
    final idx = path.lastIndexOf('/');
    final slash = path.lastIndexOf('\\');
    final last = idx > slash ? idx : slash;
    return last >= 0 ? path.substring(last + 1) : path;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: typography.bodySmall),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(value,
                style: typography.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}