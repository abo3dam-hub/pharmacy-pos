import '../../../../l10n/app_localizations.dart';

/// Localized, human-readable labels for stored audit codes.
///
/// The audit trail stores canonical English codes (`action`, `entityType`).
/// Display maps them to Arabic (or English) l10n strings; unknown/new values
/// fall back to the raw stored code so the trail stays readable.
extension AuditLabels on AppLocalizations {
  String auditActionLabel(String action) => switch (action) {
        'create' => auditActionCreate,
        'update' => auditActionUpdate,
        'delete' => auditActionDelete,
        'login' => auditActionLogin,
        'logout' => auditActionLogout,
        'login_failed' => auditActionLoginFailed,
        'void' => auditActionVoid,
        'restore' => auditActionRestore,
        'price_change' => auditActionPriceChange,
        'bulk_op' => auditActionBulkOp,
        'audit_config' => auditActionConfig,
        'backup' => auditActionBackup,
        'restore_backup' => auditActionRestoreBackup,
        _ => action,
      };

  String auditEntityTypeLabel(String entityType) => switch (entityType) {
        'user' => auditEntityUser,
        'role' => auditEntityRole,
        'permission' => auditEntityPermission,
        'app_settings' => auditEntityAppSettings,
        'item' => auditEntityItem,
        'batch' => auditEntityBatch,
        'category' => auditEntityCategory,
        'manufacturer' => auditEntityManufacturer,
        'therapeutic_group' => auditEntityTherapeuticGroup,
        'unit' => auditEntityUnit,
        'customer' => auditEntityCustomer,
        'supplier' => auditEntitySupplier,
        'sales_invoice' => auditEntitySalesInvoice,
        'purchase_invoice' => auditEntityPurchaseInvoice,
        'return' => auditEntityReturn,
        'expense' => auditEntityExpense,
        'prescription' => auditEntityPrescription,
        'cashbox' => auditEntityCashbox,
        'period' => auditEntityPeriod,
        'lost_sale' => auditEntityLostSale,
        'backup' => auditEntityBackup,
        _ => entityType,
      };
}