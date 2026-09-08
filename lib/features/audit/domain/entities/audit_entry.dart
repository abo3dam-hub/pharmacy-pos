/// One immutable audit-log row projected for the viewer (§4.27, §17).
///
/// The viewer is read-only: it never mutates `audit_logs`. [beforeData] and
/// [afterData] are raw JSON snapshots (kept as TEXT; the view may pretty-print
/// them). Username/full-name are a left-join convenience for display.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.username,
    this.userFullName,
    this.beforeData,
    this.afterData,
    this.ipAddress,
    this.note,
  });

  final String id;
  final String userId;
  final String? username;
  final String? userFullName;
  final String action;
  final String entityType;
  final String entityId;
  final String? beforeData;
  final String? afterData;
  final String? ipAddress;
  final String? note;
  final int createdAt;

  /// Stable subject label: username when present, otherwise the raw user id.
  String get actorLabel => username ?? userId;
}

/// Filter set applied to the audit query. All fields optional; null = no filter.
class AuditFilters {
  const AuditFilters({
    this.search = '',
    this.fromMillis,
    this.toMillis,
    this.userId,
    this.action,
  });

  final String search;

  /// Inclusive lower bound on `created_at`.
  final int? fromMillis;

  /// Exclusive upper bound on `created_at`.
  final int? toMillis;

  final String? userId;
  final String? action;

  bool get hasFilters =>
      search.trim().isNotEmpty ||
      fromMillis != null ||
      toMillis != null ||
      userId != null ||
      action != null;

  AuditFilters copyWith({
    String? search,
    int? Function()? fromMillis,
    int? Function()? toMillis,
    String? Function()? userId,
    String? Function()? action,
  }) {
    return AuditFilters(
      search: search ?? this.search,
      fromMillis: fromMillis != null ? fromMillis() : this.fromMillis,
      toMillis: toMillis != null ? toMillis() : this.toMillis,
      userId: userId != null ? userId() : this.userId,
      action: action != null ? action() : this.action,
    );
  }
}

/// A distinct user that appears in the audit trail (filter dropdown source).
class AuditActorOption {
  const AuditActorOption({required this.userId, required this.username});

  final String userId;
  final String username;
}