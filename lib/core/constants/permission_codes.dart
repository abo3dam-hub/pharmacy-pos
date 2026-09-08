/// Canonical RBAC permission codes. These strings are persisted in the
/// `permissions.code` column and must never change.
final class Perm {
  Perm._();

  // ---------- Canonical codes (§16) ----------
  /// Sell products at the POS.
  static const String sell = 'sell';
  static const String returnProducts = 'return';
  static const String search = 'search';
  static const String viewInventory = 'view_inventory';
  static const String viewAlternatives = 'view_alternatives';
  static const String changePrices = 'change_prices';
  static const String changePurchaseCost = 'change_purchase_cost';
  static const String deleteInvoice = 'delete_invoice';
  static const String manageUsers = 'manage_users';
  static const String managePermissions = 'manage_permissions';
  static const String modifySettings = 'modify_settings';
  static const String adjustStock = 'adjust_stock';

  // ---------- Inventory ----------
  static const String inventoryView = 'inventory.view';
  static const String inventoryCreate = 'inventory.create';
  static const String inventoryEdit = 'inventory.edit';
  static const String inventoryDelete = 'inventory.delete';
  static const String inventoryPrintBarcode = 'inventory.print_barcode';
  static const String pricingEdit = 'pricing.edit';
  static const String stockView = 'stock.view';
  static const String stockAdjust = 'stock.adjust';
  static const String stockTransfer = 'stock.transfer';

  // ---------- Purchases ----------
  static const String purchasesView = 'purchases.view';
  static const String purchasesCreate = 'purchases.create';
  static const String purchasesEdit = 'purchases.edit';
  static const String purchasesVoid = 'purchases.void';
  static const String suppliersView = 'suppliers.view';
  static const String suppliersCreate = 'suppliers.create';
  static const String suppliersEdit = 'suppliers.edit';

  // ---------- Sales ----------
  static const String salesView = 'sales.view';
  static const String salesCreate = 'sales.create';
  static const String salesVoid = 'sales.void';
  static const String salesReturnCreate = 'sales.return.create';
  static const String customersView = 'customers.view';
  static const String customersCreate = 'customers.create';
  static const String customersEdit = 'customers.edit';
  static const String prescriptionsView = 'prescriptions.view';
  static const String prescriptionsCreate = 'prescriptions.create';

  // ---------- Financial ----------
  static const String cashboxView = 'cashbox.view';
  static const String cashboxOperate = 'cashbox.operate';
  static const String expensesView = 'expenses.view';
  static const String expensesCreate = 'expenses.create';
  static const String expensesEdit = 'expenses.edit';
  static const String expensesVoid = 'expenses.void';
  static const String expenseCategoriesView = 'expenses.categories.view';
  static const String expenseCategoriesManage = 'expenses.categories.manage';
  static const String accountingView = 'accounting.view';
  static const String accountingPost = 'accounting.post';

  // ---------- Lost sales ----------
  static const String lostSalesView = 'lost_sales.view';
  static const String lostSalesCreate = 'lost_sales.create';
  static const String lostSalesClose = 'lost_sales.close';

  // ---------- Reports ----------
  static const String reportsViewSales = 'reports.view_sales';
  static const String reportsViewPurchases = 'reports.view_purchases';
  static const String reportsViewInventory = 'reports.view_inventory';
  static const String reportsViewProfit = 'reports.view_profit';

  // ---------- Administration ----------
  static const String usersView = 'users.view';
  static const String usersCreate = 'users.create';
  static const String usersEdit = 'users.edit';
  static const String rolesView = 'roles.view';
  static const String rolesEdit = 'roles.edit';
  static const String auditView = 'audit.view';
  static const String settingsView = 'settings.view';
  static const String settingsEdit = 'settings.edit';
  static const String backup = 'backup';
  static const String backupRestore = 'backup.restore';
  static const String exportData = 'export.data';
}

/// Seed definitions: (code, Arabic name).
final List<({String code, String name})> kSeedPermissions = [
  // Canonical §16 codes.
  (code: Perm.sell, name: 'بيع المنتجات'),
  (code: Perm.returnProducts, name: 'إنشاء مرتجعات'),
  (code: Perm.search, name: 'بحث'),
  (code: Perm.viewInventory, name: 'عرض المخزون العام'),
  (code: Perm.viewAlternatives, name: 'عرض البدائل'),
  (code: Perm.changePrices, name: 'تغيير الأسعار'),
  (code: Perm.changePurchaseCost, name: 'تغيير تكلفة الشراء'),
  (code: Perm.deleteInvoice, name: 'حذف الفواتير'),
  (code: Perm.manageUsers, name: 'إدارة المستخدمين'),
  (code: Perm.managePermissions, name: 'إدارة الصلاحيات'),
  (code: Perm.modifySettings, name: 'تعديل الإعدادات'),
  (code: Perm.adjustStock, name: 'تسوية المخزون'),

// ---------- Inventory ----------
  (code: Perm.inventoryView, name: 'عرض المواد'),
  (code: Perm.inventoryCreate, name: 'إضافة المواد'),
  (code: Perm.inventoryEdit, name: 'تعديل المواد'),
  (code: Perm.inventoryDelete, name: 'حذف المواد'),
  (code: Perm.inventoryPrintBarcode, name: 'طباعة الباركود'),
  (code: Perm.pricingEdit, name: 'تعديل الأسعار'),
  (code: Perm.stockView, name: 'عرض المخزون'),
  (code: Perm.stockAdjust, name: 'تسوية المخزون'),
  (code: Perm.stockTransfer, name: 'تحويل مخزون'),
  (code: Perm.purchasesView, name: 'عرض فواتير الشراء'),
  (code: Perm.purchasesCreate, name: 'إنشاء فواتير الشراء'),
  (code: Perm.purchasesEdit, name: 'تعديل فواتير الشراء'),
  (code: Perm.purchasesVoid, name: 'إلغاء فواتير الشراء'),
  (code: Perm.suppliersView, name: 'عرض الموردين'),
  (code: Perm.suppliersCreate, name: 'إضافة مورد'),
  (code: Perm.suppliersEdit, name: 'تعديل مورد'),
  (code: Perm.salesView, name: 'عرض فواتير البيع'),
  (code: Perm.salesCreate, name: 'إنشاء فواتير البيع'),
  (code: Perm.salesVoid, name: 'إلغاء فواتير البيع'),
  (code: Perm.salesReturnCreate, name: 'إنشاء المرتجعات'),
  (code: Perm.customersView, name: 'عرض العملاء'),
  (code: Perm.customersCreate, name: 'إضافة عميل'),
  (code: Perm.customersEdit, name: 'تعديل عميل'),
  (code: Perm.prescriptionsView, name: 'عرض الوصفات'),
  (code: Perm.prescriptionsCreate, name: 'إنشاء الوصفات'),
  (code: Perm.cashboxView, name: 'عرض الصندوق'),
  (code: Perm.cashboxOperate, name: 'التعامل مع الصندوق'),
  (code: Perm.expensesView, name: 'عرض المصروفات'),
  (code: Perm.expensesCreate, name: 'تسجيل مصروف'),
  (code: Perm.expensesEdit, name: 'تعديل مصروف'),
  (code: Perm.expensesVoid, name: 'إلغاء مصروف'),
  (code: Perm.expenseCategoriesView, name: 'عرض فئات المصروفات'),
  (code: Perm.expenseCategoriesManage, name: 'إدارة فئات المصروفات'),
  (code: Perm.accountingView, name: 'عرض القيود'),
  (code: Perm.accountingPost, name: 'ترحيل قيود'),
  (code: Perm.lostSalesView, name: 'عرض النواقص'),
  (code: Perm.lostSalesCreate, name: 'تسجيل ناقص'),
  (code: Perm.lostSalesClose, name: 'إغلاق ناقص'),
  (code: Perm.reportsViewSales, name: 'تقارير المبيعات'),
  (code: Perm.reportsViewPurchases, name: 'تقارير المشتريات'),
  (code: Perm.reportsViewInventory, name: 'تقارير المخزون'),
  (code: Perm.reportsViewProfit, name: 'تقارير الأرباح'),
  (code: Perm.usersView, name: 'عرض المستخدمين'),
  (code: Perm.usersCreate, name: 'إضافة مستخدم'),
  (code: Perm.usersEdit, name: 'تعديل مستخدم'),
  (code: Perm.rolesView, name: 'عرض الأدوار'),
  (code: Perm.rolesEdit, name: 'تعديل الأدوار'),
  (code: Perm.auditView, name: 'عرض سجل التدقيق'),
  (code: Perm.settingsView, name: 'عرض الإعدادات'),
  (code: Perm.settingsEdit, name: 'تعديل الإعدادات'),
  (code: Perm.backup, name: 'النسخ الاحتياطي'),
  (code: Perm.backupRestore, name: 'الاستعادة من نسخة'),
  (code: Perm.exportData, name: 'تصدير البيانات'),
];