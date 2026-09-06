// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pharmacy Management System';

  @override
  String get appSlogan => 'Professional Pharmacy Management & POS system';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSale => 'Sales';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navPurchases => 'Purchases';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navSuppliers => 'Suppliers';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get navUsers => 'Users';

  @override
  String get navAlternatives => 'Alternatives';

  @override
  String get navLostSales => 'Out of Stock';

  @override
  String get navReturn => 'Returns';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonPrint => 'Print';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'An error occurred';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNone => 'None';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonSubtotal => 'Subtotal';

  @override
  String get commonDiscount => 'Discount';

  @override
  String get commonTax => 'Tax';

  @override
  String get commonChange => 'Change';

  @override
  String get commonPaid => 'Paid';

  @override
  String get commonProfit => 'Profit';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginWelcome => 'Sign in to the system';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginFailed => 'Incorrect username or password';

  @override
  String get loginUserInactive => 'This user is inactive';

  @override
  String get userLogout => 'Sign out';

  @override
  String get userRole => 'Role';

  @override
  String get roleAdmin => 'System admin';

  @override
  String get rolePharmacist => 'Pharmacist';

  @override
  String get roleCashier => 'Cashier';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get authPermissionDenied =>
      'You are not allowed to perform this action';

  @override
  String get authSaveError => 'An error occurred while saving data';

  @override
  String get usersTitle => 'Users';

  @override
  String get usersList => 'Users list';

  @override
  String get usersAdd => 'Add user';

  @override
  String get usersCreateTitle => 'Add new user';

  @override
  String get usersEditTitle => 'Edit user';

  @override
  String get usersSearchHint => 'Search users by name or username';

  @override
  String get usersEmpty => 'No matching users found';

  @override
  String get userFullName => 'Full name';

  @override
  String get userUsername => 'Username';

  @override
  String get userPhone => 'Phone';

  @override
  String get userNotes => 'Notes';

  @override
  String get userStatusActive => 'Active';

  @override
  String get userStatusInactive => 'Inactive';

  @override
  String get userLastLogin => 'Last login';

  @override
  String get userNeverLoggedIn => 'Never signed in';

  @override
  String get userLastLoginLabel => 'Last login';

  @override
  String get userActivate => 'Activate';

  @override
  String get userDeactivate => 'Deactivate';

  @override
  String get userDeactivateConfirmTitle => 'Deactivate user';

  @override
  String userDeactivateConfirmMessage(String name) {
    return 'Deactivate user \"$name\"?';
  }

  @override
  String userActivateConfirmMessage(String name) {
    return 'Activate user \"$name\"?';
  }

  @override
  String get userChangePassword => 'Change password';

  @override
  String get userChangePasswordTitle => 'Change password';

  @override
  String get userNewPassword => 'New password';

  @override
  String get userConfirmPassword => 'Confirm password';

  @override
  String get userPasswordMismatch => 'Passwords do not match';

  @override
  String get userPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get userRequiredField => 'This field is required';

  @override
  String get userUsernameExists => 'Username is already taken';

  @override
  String get userCreatedMessage => 'User created';

  @override
  String get userUpdatedMessage => 'User updated';

  @override
  String get userActivatedMessage => 'User activated';

  @override
  String get userDeactivatedMessage => 'User deactivated';

  @override
  String get userPasswordChangedMessage => 'Password changed';

  @override
  String get accessDeniedTitle => 'Access denied';

  @override
  String get accessDeniedMessage =>
      'You do not have permission to access this page';

  @override
  String get checkout => 'Checkout';

  @override
  String get holdBill => 'Hold bill';

  @override
  String get cartEmpty => 'Cart is empty';

  @override
  String get notEnoughStock => 'Insufficient stock';

  @override
  String get price => 'Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get batchNo => 'Batch no.';

  @override
  String get expiryDate => 'Expiry date';

  @override
  String get unitBoxes => 'Boxes';

  @override
  String get unitStrips => 'Strips';

  @override
  String get dashboardTodayOrders => 'Today\'s orders';

  @override
  String get dashboardDailySales => 'Today\'s sales';

  @override
  String get dashboardLowStock => 'Low-stock items';

  @override
  String get dashboardProfitToday => 'Today\'s profit';

  @override
  String get inventoryLowStock => 'Low stock';

  @override
  String get inventoryOutOfStock => 'Out of stock';

  @override
  String get saleNewSale => 'New sale';

  @override
  String get saleRecentInvoices => 'Recent invoices';

  @override
  String get purchaseNewPurchase => 'New purchase';

  @override
  String get purchaseRecent => 'Recent purchase invoices';

  @override
  String get customersList => 'Customers';

  @override
  String get suppliersList => 'Suppliers';

  @override
  String get accountsCashbox => 'Cashbox';

  @override
  String get accountsJournal => 'Journal';

  @override
  String get accountsLedger => 'Ledger';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsDatabase => 'Database';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsAppInfo => 'App info';

  @override
  String get settingsSchemaVersion => 'Schema version';

  @override
  String get settingsVersion => 'Version';

  @override
  String get itemTradeName => 'Trade name';

  @override
  String get itemBarcode => 'Barcode';

  @override
  String get itemCategory => 'Category';

  @override
  String get itemUnit => 'Unit';

  @override
  String get itemCost => 'Cost';

  @override
  String get itemPrice => 'Selling price';

  @override
  String get itemStock => 'Stock';

  @override
  String get inventoryTabItems => 'Items';

  @override
  String get inventoryTabCategories => 'Categories';

  @override
  String get inventoryTabManufacturers => 'Manufacturers';

  @override
  String get inventoryTabGroups => 'Therapeutic Groups';

  @override
  String get inventoryTabUnits => 'Units';

  @override
  String get inventorySearchHint => 'Search items by name or barcode';

  @override
  String get inventoryAddItem => 'Add item';

  @override
  String get inventoryItemAddTitle => 'Add new item';

  @override
  String get inventoryItemEditTitle => 'Edit item';

  @override
  String get inventoryItemsEmpty => 'No matching items';

  @override
  String get inventoryActiveFilter => 'Active only';

  @override
  String get inventoryCreatedMessage => 'Item created';

  @override
  String get inventoryUpdatedMessage => 'Item updated';

  @override
  String get inventoryActivatedMessage => 'Item activated';

  @override
  String get inventoryDeactivatedMessage => 'Item deactivated';

  @override
  String get inventoryImport => 'Import from Excel';

  @override
  String get inventoryExport => 'Export to Excel';

  @override
  String inventoryImportDone(int created, int updated) {
    return 'Import finished: $created created, $updated updated';
  }

  @override
  String inventoryImportIssues(int skipped) {
    return 'Skipped $skipped rows';
  }

  @override
  String get inventoryExportDone => 'File exported';

  @override
  String get inventoryImportFailed => 'Could not read the file';

  @override
  String get itemBarcodePrimary => 'Primary barcode';

  @override
  String get itemScientificName => 'Scientific name';

  @override
  String get itemActiveIngredient => 'Active ingredient';

  @override
  String get itemTradeNameEn => 'Trade name (English)';

  @override
  String get itemSubCategory => 'Sub-category';

  @override
  String get itemManufacturer => 'Manufacturer';

  @override
  String get itemGroup => 'Therapeutic group';

  @override
  String get itemPharmaForm => 'Pharmaceutical form';

  @override
  String get itemDose => 'Dose';

  @override
  String get itemSizeVolume => 'Size / volume';

  @override
  String get itemShelfLocation => 'Shelf location';

  @override
  String get itemSecondaryBarcode => 'Secondary barcode';

  @override
  String get itemEquivalentDrug => 'Equivalent drug';

  @override
  String get itemHasExpiry => 'Has expiry date';

  @override
  String get itemPrintLabel => 'Print barcode label';

  @override
  String get itemIsOtc => 'Over the counter';

  @override
  String get itemIsControlled => 'Controlled drug';

  @override
  String get itemScaleAlert => 'Scale barcode alert';

  @override
  String get itemLockPriceAutoUpdate => 'Lock auto price update';

  @override
  String get itemRequiresPrescription => 'Requires prescription';

  @override
  String get itemPurchaseDiscount => 'Purchase discount';

  @override
  String get itemSellingPrice => 'Selling price';

  @override
  String get itemSubUnitPrice => 'Sub-unit price';

  @override
  String get itemWholesalePrice => 'Wholesale price';

  @override
  String get itemHalfWholesalePrice => 'Half-wholesale price';

  @override
  String get itemCustomPrice1 => 'Custom price 1';

  @override
  String get itemCustomPrice2 => 'Custom price 2';

  @override
  String get itemVatRate => 'VAT rate';

  @override
  String get itemMinimumStock => 'Minimum stock';

  @override
  String get itemMaximumStock => 'Maximum stock';

  @override
  String get itemUsageInstructions => 'Usage instructions';

  @override
  String get itemGeneralNotes => 'General notes';

  @override
  String get itemLicenseNumber => 'License number';

  @override
  String get itemUnitsRelation => 'Unit relation';

  @override
  String get itemBaseUnit => 'Base unit';

  @override
  String get itemLargeUnit => 'Large unit';

  @override
  String get itemUnitsPerLarge => 'Base units per large unit';

  @override
  String get itemCurrentStock => 'Current stock';

  @override
  String get itemProfitMargin => 'Profit margin';

  @override
  String get statusNormal => 'In stock';

  @override
  String get statusHealthy => 'Healthy';

  @override
  String get statusNearExpiry => 'Near expiry';

  @override
  String get statusExpired => 'Expired';

  @override
  String get batchesTitle => 'Item batches';

  @override
  String get batchesAdd => 'Add batch';

  @override
  String get batchesAddTitle => 'Add new batch';

  @override
  String get batchesVoidTitle => 'Void batch';

  @override
  String get batchesVoidConfirm => 'Void this batch?';

  @override
  String get batchesAddedMessage => 'Batch added';

  @override
  String get batchesVoidedMessage => 'Batch voided';

  @override
  String get batchesEmpty => 'No batches';

  @override
  String get batchUnitCost => 'Unit cost';

  @override
  String get batchReceivedDate => 'Received date';

  @override
  String get batchBonusQty => 'Bonus quantity';

  @override
  String get batchNotes => 'Batch notes';

  @override
  String get batchRemaining => 'Remaining qty';

  @override
  String get batchVoided => 'Voided';

  @override
  String get movementType => 'Movement type';

  @override
  String get moveOpening => 'Opening';

  @override
  String get movePurchase => 'Purchase';

  @override
  String get moveSale => 'Sale';

  @override
  String get moveSaleReturn => 'Sale return';

  @override
  String get movePurchaseReturn => 'Purchase return';

  @override
  String get moveAdjustment => 'Stock adjustment';

  @override
  String get moveDamaged => 'Damaged';

  @override
  String get moveExpired => 'Expired';

  @override
  String get moveTransfer => 'Transfer';

  @override
  String get moveCorrection => 'Manual correction';

  @override
  String get movementsList => 'Movement history';

  @override
  String get movementsDate => 'Date';

  @override
  String get movementsDelta => 'Qty';

  @override
  String get movementsBalance => 'Balance after';

  @override
  String get adjustStockTitle => 'Stock adjustment';

  @override
  String get adjustStockDone => 'Adjustment saved';

  @override
  String get adjustNote => 'Adjustment note';

  @override
  String get adjustmentIncrease => 'Add stock';

  @override
  String get adjustmentDecrease => 'Remove stock';

  @override
  String get bulkAction => 'Bulk action';

  @override
  String get bulkTitle => 'Bulk actions';

  @override
  String get bulkChangeCategory => 'Change category';

  @override
  String get bulkChangeShelf => 'Change shelf location';

  @override
  String get bulkAdjustPricePercent => 'Adjust prices by %';

  @override
  String get bulkPercent => 'Percentage';

  @override
  String bulkSelectedCount(int count) {
    return '$count items selected';
  }

  @override
  String bulkDone(int count) {
    return 'Done on $count items';
  }

  @override
  String get bulkSelectHint => 'Select at least one item';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesAddTitle => 'Add new category';

  @override
  String get categoriesEditTitle => 'Edit category';

  @override
  String get subCategoriesAddTitle => 'Add sub-category';

  @override
  String get subCategoriesEditTitle => 'Edit sub-category';

  @override
  String get addSubCategory => 'Add sub-category';

  @override
  String get categoriesEmpty => 'No categories';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameEn => 'Category name (English)';

  @override
  String get subCategoryName => 'Sub-category name';

  @override
  String get manufacturerName => 'Manufacturer name';

  @override
  String get manufacturerCountry => 'Country';

  @override
  String get manufacturerWebsite => 'Website';

  @override
  String get manufacturersAdd => 'Add manufacturer';

  @override
  String get manufacturersEditTitle => 'Edit manufacturer';

  @override
  String get manufacturersEmpty => 'No manufacturers';

  @override
  String get groupName => 'Group name';

  @override
  String get groupsAdd => 'Add group';

  @override
  String get groupsEditTitle => 'Edit group';

  @override
  String get groupsEmpty => 'No groups';

  @override
  String get unitName => 'Unit name';

  @override
  String get unitAbbreviation => 'Abbreviation';

  @override
  String get masterDataNameEn => 'Name (English)';

  @override
  String get unitsAdd => 'Add unit';

  @override
  String get unitsEditTitle => 'Edit unit';

  @override
  String get unitsEmpty => 'No units';

  @override
  String get masterDataSavedMessage => 'Saved successfully';

  @override
  String get inventoryRequiredName => 'Name is required';

  @override
  String get inventorySelectCategory => 'Select category';

  @override
  String get inventoryBatches => 'Batches';

  @override
  String get inventoryAdjustStock => 'Stock adjustment';

  @override
  String get inventoryBatchView => 'View batches';

  @override
  String get suppliersTab => 'Suppliers';

  @override
  String get suppliersBalancesTab => 'Balances';

  @override
  String get suppliersEmpty => 'No suppliers found';

  @override
  String get suppliersSearchHint => 'Search by name, phone or code';

  @override
  String get supplierAdd => 'Add Supplier';

  @override
  String get supplierAddTitle => 'New Supplier';

  @override
  String get supplierEditTitle => 'Edit Supplier';

  @override
  String get supplierName => 'Name';

  @override
  String get supplierCode => 'Code';

  @override
  String get supplierPhone => 'Phone';

  @override
  String get supplierSecondaryPhone => 'Secondary phone';

  @override
  String get supplierEmail => 'Email';

  @override
  String get supplierAddress => 'Address';

  @override
  String get supplierContactPerson => 'Contact person';

  @override
  String get supplierTaxVatNumber => 'Tax / VAT number';

  @override
  String get supplierLicenseRegistration => 'License / registration';

  @override
  String get supplierOpeningBalance => 'Opening balance';

  @override
  String get supplierCreditLimit => 'Credit limit';

  @override
  String get supplierNotes => 'Notes';

  @override
  String get supplierCreatedMessage => 'Supplier added';

  @override
  String get supplierUpdatedMessage => 'Supplier updated';

  @override
  String get supplierActivatedMessage => 'Supplier re-activated';

  @override
  String get supplierDeactivatedMessage => 'Supplier deactivated';

  @override
  String supplierDeactivateConfirmMessage(String name) {
    return 'Deactivate supplier\"$name\"?';
  }

  @override
  String supplierActivateConfirmMessage(String name) {
    return 'Activate supplier\"$name\"?';
  }

  @override
  String get supplierBalance => 'Balance';

  @override
  String get supplierStatement => 'Statement';

  @override
  String get supplierStatementTitle => 'Supplier Statement';

  @override
  String get supplierStatementDateFrom => 'From';

  @override
  String get supplierStatementDateTo => 'To';

  @override
  String get statementDate => 'Date';

  @override
  String get statementDescription => 'Description';

  @override
  String get statementDebit => 'Debit';

  @override
  String get statementCredit => 'Credit';

  @override
  String get statementOpening => 'Opening balance';

  @override
  String get statementClosing => 'Closing balance';

  @override
  String get statementBalance => 'Balance';

  @override
  String statementRowInvoice(String number) {
    return 'Purchase invoice $number';
  }

  @override
  String statementRowReturn(String number) {
    return 'Purchase return $number';
  }

  @override
  String get statementNoData => 'No transactions in this range';

  @override
  String get purchaseStatusPending => 'Pending';

  @override
  String get purchaseStatusReceived => 'Received';

  @override
  String get purchaseStatusCancelled => 'Cancelled';

  @override
  String get purchaseAddInvoice => 'New Purchase';

  @override
  String get purchasesEmpty => 'No purchase invoices found';

  @override
  String get purchasesSearchHint => 'Search by invoice number';

  @override
  String get purchasesFilterSupplier => 'All suppliers';

  @override
  String get purchasesFilterStatus => 'All statuses';

  @override
  String get purchaseInvoiceNumber => 'Invoice No.';

  @override
  String get purchaseInvoiceDate => 'Date';

  @override
  String get purchaseSupplierLabel => 'Supplier';

  @override
  String get purchaseTotal => 'Total';

  @override
  String get purchasePaid => 'Paid';

  @override
  String get purchaseRemaining => 'Remaining';

  @override
  String get purchaseCreateTitle => 'New Purchase Invoice';

  @override
  String get purchaseEditTitle => 'Edit Purchase Invoice';

  @override
  String get purchaseOrderNumber => 'Invoice number';

  @override
  String get purchaseOrderDate => 'Invoice date';

  @override
  String get purchaseExpectedDate => 'Expected date (optional)';

  @override
  String get purchasePaidAmount => 'Paid amount';

  @override
  String get purchaseNotes => 'Notes';

  @override
  String get purchaseSubtotal => 'Subtotal';

  @override
  String get purchaseDiscount => 'Discounts';

  @override
  String get purchaseGrandTotal => 'Grand total';

  @override
  String get purchaseItemPlaceholder => 'Select item';

  @override
  String get purchaseItemSearchHint => 'Search items…';

  @override
  String get purchaseQty => 'Quantity';

  @override
  String get purchaseUnitCost => 'Unit cost';

  @override
  String get purchaseUnitType => 'Unit type';

  @override
  String get purchaseDiscountPct => 'Discount %';

  @override
  String get purchaseBonus => 'Bonus';

  @override
  String get purchaseAddLine => 'Add line';

  @override
  String get purchaseRemoveLine => 'Remove line';

  @override
  String get purchaseNoLines => 'Add at least one line';

  @override
  String get purchaseReceive => 'Receive';

  @override
  String get purchaseCancel => 'Cancel Invoice';

  @override
  String get purchaseReturn => 'Return';

  @override
  String get purchaseReceiveTitle => 'Receive Purchase';

  @override
  String get purchaseReceiveIntro => 'Enter batch numbers to receive stock';

  @override
  String get purchaseBatchNumber => 'Batch number';

  @override
  String get purchaseExpiryDate => 'Expiry date (optional)';

  @override
  String get purchaseReceivedMessage => 'Purchase received - batches created';

  @override
  String get purchaseCreatedMessage => 'Purchase invoice saved';

  @override
  String get purchaseUpdatedMessage => 'Purchase invoice updated';

  @override
  String get purchaseCancelledMessage => 'Purchase invoice cancelled';

  @override
  String get purchaseCancelConfirm => 'Cancel this purchase invoice?';

  @override
  String get purchaseDetailTitle => 'Purchase Invoice';

  @override
  String get purchaseReturnTitle => 'Purchase Return';

  @override
  String get purchaseReturnOrderNo => 'Return number';

  @override
  String get purchaseReturnQty => 'Quantity to return';

  @override
  String get purchaseReturnAvailable => 'Available';

  @override
  String get purchaseReturnReason => 'Reason (optional)';

  @override
  String get purchaseReturnSavedMessage => 'Return recorded';

  @override
  String get purchaseReturnValidation => 'Check return quantities';

  @override
  String get purchaseBonus1 => 'Bonus 1';

  @override
  String get purchaseBonus2 => 'Bonus 2';

  @override
  String get purchaseBonusGift => 'Gift';

  @override
  String get purchaseBonusButton => 'Bonus';

  @override
  String get purchaseBonusItem => 'Bonus item';

  @override
  String get purchaseStatusLabel => 'Status';

  @override
  String get purchaseRequiredSupplier => 'Select a supplier';

  @override
  String get purchaseRequiredLines => 'Add at least one line';

  @override
  String get purchaseRequiredNumber => 'Invoice number is required';

  @override
  String get purchaseItemNotNull => 'Select an item for every line';

  @override
  String get purchaseQtyPositive => 'Quantity must be positive';

  @override
  String get purchaseCostPositive => 'Unit cost must be positive';

  @override
  String get supplierNameRequired => 'Name is required';
}
