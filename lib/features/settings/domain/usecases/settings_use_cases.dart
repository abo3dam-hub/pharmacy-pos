import '../../../../core/errors/exceptions.dart';
import '../../../../domain/services/audit_service.dart';
import '../../../../domain/services/permission_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/models/enums.dart';
import '../entities/app_settings_entity.dart';
import '../repositories/settings_repository.dart';

/// Loads the current application settings (read path). Requires `settings.view`.
class GetAppSettingsUseCase {
  const GetAppSettingsUseCase(this._repository, this._permissions);

  final SettingsRepository _repository;
  final PermissionService _permissions;

  Future<AppSettings> call(
    AppDatabase db,
    String? actingRoleId,
  ) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'settings.view');
    return _repository.getSettings();
  }
}

/// Validates + persists application settings (write path). Requires
/// `settings.edit`; a successful save writes an `audit_config` audit row.
class SaveAppSettingsUseCase {
  const SaveAppSettingsUseCase(
    this._repository,
    this._permissions,
    this._audit,
  );

  final SettingsRepository _repository;
  final PermissionService _permissions;
  final AuditService _audit;

  Future<AppSettings> call(
    AppDatabase db, {
    required AppSettingsDraft draft,
    required String? actingUserId,
    required String? actingRoleId,
  }) async {
    await _permissions.requireRolePermission(db, actingRoleId, 'settings.edit');
    _validate(draft);

    final before = await _repository.getSettings();
    final saved = await _repository.saveSettings(draft);

    if (actingUserId != null) {
      try {
        await _audit.write(
          db,
          userId: actingUserId,
          action: AuditAction.auditConfig,
          entityType: 'app_settings',
          entityId: 'settings',
          before: {
            'businessName': before.businessName,
            'taxRateBasisPoints': before.taxRate.basisPoints,
            'currencyCode': before.currencyCode,
          },
          after: {
            'businessName': saved.businessName,
            'taxRateBasisPoints': saved.taxRate.basisPoints,
            'currencyCode': saved.currencyCode,
          },
          note: 'settings_updated',
        );
      } catch (_) {
        // Audit must never break the settings save.
      }
    }
    return saved;
  }

  void _validate(AppSettingsDraft draft) {
    final name = draft.businessName.trim();
    if (name.isEmpty) {
      throw ValidationException('اسم النشاط التجاري مطلوب');
    }
    if (name.length > 200) {
      throw ValidationException('اسم النشاط التجاري طويل جداً (200 حرف كحد أقصى)');
    }
    final tax = draft.taxRateBasisPoints;
    if (tax < 0 || tax > 10000) {
      throw ValidationException('نسبة الضريبة يجب أن تكون بين 0% و 100%');
    }
    final currency = draft.currencyCode.trim().toUpperCase();
    if (currency.length != 3 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ValidationException('رمز العملة غير صالح (3 أحرف لاتينية)');
    }
  }
}