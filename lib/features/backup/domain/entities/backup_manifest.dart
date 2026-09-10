import 'dart:convert';

/// Format version of self-contained Phase 13 backup packages (§37, Env B).
const int kBackupFormatVersion = 1;

/// The highest schema version this application can read. Backups with a
/// `schemaVersion` above this value are rejected (no downgrade, ever).
int get kCurrentSupportedSchemaVersion => 11;

/// Logical layout of the self-contained backup archive (§37).
///
/// ```
/// pharmacy-backup/
///   manifest.json
///   database.sqlite
///   files/
///     expense_receipts/
///       <stored receipt file>
/// ```
class BackupArchiveLayout {
  const BackupArchiveLayout._();

  static const String manifestFileName = 'manifest.json';
  static const String databaseFileName = 'database.sqlite';
  static const String filesRoot = 'files';
  static const String receiptsDirectoryName = 'expense_receipts';

  static String receiptsEntryRoot() =>
      '$filesRoot/$receiptsDirectoryName';

  static String receiptEntryPath(String fileName) =>
      '$filesRoot/$receiptsDirectoryName/$fileName';
}

/// A single managed file recorded inside the backup manifest.
class ManagedFileEntry {
  const ManagedFileEntry({
    required this.relativePath,
    required this.sizeBytes,
    required this.sha256,
  });

  /// Path of the file *inside* the archive, e.g.
  /// `files/expense_receipts/1712345678901.jpg`.
  final String relativePath;

  final int sizeBytes;
  final String sha256;

  Map<String, Object?> toJson() => {
        'path': relativePath,
        'size_bytes': sizeBytes,
        'sha256': sha256,
      };

  factory ManagedFileEntry.fromJson(Map<String, Object?> json) {
    return ManagedFileEntry(
      relativePath: json['path'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256: json['sha256'] as String,
    );
  }
}

/// The `manifest.json` embedded in every self-contained backup (§37, Env B).
///
/// The manifest carries no secrets — only integrity and compatibility
/// metadata used to validate and authorize a restore.
class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.applicationVersion,
    required this.schemaVersion,
    required this.createdAtMillis,
    required this.databaseFileName,
    required this.databaseSizeBytes,
    required this.databaseSha256,
    required this.files,
  });

  final int formatVersion;
  final String applicationVersion;
  final int schemaVersion;
  final int createdAtMillis;
  final String databaseFileName;
  final int databaseSizeBytes;
  final String databaseSha256;
  final List<ManagedFileEntry> files;

  Map<String, Object?> toJson() => {
        'format_version': formatVersion,
        'application_version': applicationVersion,
        'schema_version': schemaVersion,
        'created_at': createdAtMillis,
        'database': {
          'filename': databaseFileName,
          'size_bytes': databaseSizeBytes,
          'sha256': databaseSha256,
        },
        'files': [for (final f in files) f.toJson()],
      };

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final databaseJson =
        (json['database'] as Map).cast<String, Object?>();
    final filesJson = (json['files'] as List?);
    return BackupManifest(
      formatVersion: json['format_version'] as int,
      applicationVersion: json['application_version'] as String,
      schemaVersion: json['schema_version'] as int,
      createdAtMillis: json['created_at'] as int,
      databaseFileName: databaseJson['filename'] as String,
      databaseSizeBytes: databaseJson['size_bytes'] as int,
      databaseSha256: databaseJson['sha256'] as String,
      files: [
        for (final f in filesJson ?? const [])
          ManagedFileEntry.fromJson((f as Map).cast<String, Object?>()),
      ],
    );
  }

  /// Parses + structurally validates a manifest. Returns null when the JSON is
  /// malformed or a required field is missing/typed incorrectly.
  static BackupManifest? tryParse(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return null;
      final manifest = BackupManifest.fromJson(decoded.cast<String, Object?>());
      if (manifest.formatVersion < 1) return null;
      if (manifest.databaseFileName.isEmpty) return null;
      if (manifest.databaseSizeBytes < 0) return null;
      if (manifest.databaseSha256.length != 64) return null;
      for (final f in manifest.files) {
        if (f.relativePath.isEmpty || f.sizeBytes < 0 || f.sha256.length != 64) {
          return null;
        }
      }
      return manifest;
    } catch (_) {
      return null;
    }
  }
}