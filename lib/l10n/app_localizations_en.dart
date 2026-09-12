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
  String get unitStrips => 'Sachets';

  @override
  String get dashboardTodayOrders => 'Today\'s orders';

  @override
  String get dashboardDailySales => 'Today\'s sales';

  @override
  String get dashboardLowStock => 'Low-stock items';

  @override
  String get dashboardProfitToday => 'Today\'s profit';

  @override
  String get dashboardKpis => 'Overview';

  @override
  String get dashboardUnitsSold => 'Units sold today';

  @override
  String get dashboardActiveItems => 'Active products';

  @override
  String get dashboardStockValue => 'Stock value';

  @override
  String get dashboardLowStockEmpty => 'No low-stock items — well stocked.';

  @override
  String get dashboardNearExpiry => 'Near expiry';

  @override
  String get dashboardNearExpiryEmpty => 'No batches expiring soon.';

  @override
  String get dashboardRecentSales => 'Recent sales';

  @override
  String get dashboardRecentPurchases => 'Recent purchases';

  @override
  String get dashboardRecentEmpty => 'None yet.';

  @override
  String get dashboardError => 'Could not load the dashboard.';

  @override
  String get dashboardRetry => 'Try again';

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
  String get inventoryInStock => 'Items in stock';

  @override
  String get inventoryProductTree => 'Product tree';

  @override
  String inventoryStockTooltip(String stock, String price) {
    return 'Current stock: $stock · Selling price: $price';
  }

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
  String inventoryImportMaster(int count) {
    return 'Created $count new master records';
  }

  @override
  String get inventoryExportDone => 'File exported';

  @override
  String get inventoryImportFailed => 'Could not read the file';

  @override
  String get inventoryImportParsing => 'Parsing Excel file...';

  @override
  String get inventoryImportApplying => 'Importing products...';

  @override
  String inventoryImportProgress(int processed, int total) {
    return '$processed of $total';
  }

  @override
  String get inventoryImportCancel => 'Cancel import';

  @override
  String get inventoryImportCancelled => 'Import cancelled';

  @override
  String get itemBarcodePrimary => 'Primary barcode';

  @override
  String get itemScientificName => 'Scientific name';

  @override
  String get itemActiveIngredient => 'Active ingredient';

  @override
  String get itemTradeNameEn => 'Trade name (English)';

  @override
  String get itemManufacturer => 'Manufacturer';

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
  String get itemIsControlled => 'Controlled drug';

  @override
  String get itemLockPriceAutoUpdate => 'Lock auto price update';

  @override
  String get itemRequiresPrescription => 'Requires prescription';

  @override
  String get itemPurchaseDiscount => 'Purchase discount';

  @override
  String get itemSellingPrice => 'Selling price';

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
  String get itemBaseUnit => 'Parts';

  @override
  String get itemLargeUnit => 'Large unit';

  @override
  String get itemPackagingUnit => 'Commercial packaging';

  @override
  String get itemUnitsPerLarge => 'Number of parts';

  @override
  String get itemSuppliers => 'Suppliers';

  @override
  String get itemAddNew => 'Add new';

  @override
  String get inventoryUnitsRequired => 'Parts and packaging are required';

  @override
  String get inventorySelectBaseUnit => 'Select the parts';

  @override
  String get inventorySelectLargeUnit => 'Select the commercial packaging';

  @override
  String get inventoryUnitsPerLargeInvalid =>
      'Number of parts must be greater than zero';

  @override
  String get itemClassificationSection => 'Classification & drug info';

  @override
  String get itemPricePartsSection => 'Cost / Price / Parts';

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
  String get bulkPriceScopeTitle => 'Apply to';

  @override
  String get bulkPriceScopeAll => 'All products';

  @override
  String get bulkPriceScopeManufacturer => 'Products of a manufacturer';

  @override
  String get bulkPriceScopeSupplier => 'Products from a supplier';

  @override
  String bulkPriceScopeManual(int count) {
    return '$count selected products';
  }

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesAddTitle => 'Add new category';

  @override
  String get categoriesEditTitle => 'Edit category';

  @override
  String get categoriesEmpty => 'No categories';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameEn => 'Category name (English)';

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
  String get activeIngredientName => 'Active ingredient';

  @override
  String get indicationName => 'Indication';

  @override
  String get activeIngredientsAdd => 'Add active ingredient';

  @override
  String get activeIngredientsEditTitle => 'Edit active ingredient';

  @override
  String get activeIngredientsEmpty => 'No active ingredients';

  @override
  String get indicationsAdd => 'Add indication';

  @override
  String get indicationsEditTitle => 'Edit indication';

  @override
  String get indicationsEmpty => 'No indications';

  @override
  String get itemActiveIngredients => 'Active ingredients';

  @override
  String get activeIngredientStrength => 'Strength';

  @override
  String get itemActiveIngredientsSearch => 'Search active ingredient…';

  @override
  String get itemActiveIngredientsHint =>
      'Search and add active ingredients with their strength';

  @override
  String get itemActiveIngredientsRemove => 'Remove active ingredient';

  @override
  String get itemIndications => 'Indications';

  @override
  String get inventoryTabActiveIngredients => 'Active ingredients';

  @override
  String get inventoryTabIndications => 'Indications';

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
  String supplierDeactivateConfirmMessage(Object name) {
    return 'Deactivate supplier\"$name\"?';
  }

  @override
  String supplierActivateConfirmMessage(Object name) {
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
  String statementRowInvoice(Object number) {
    return 'Purchase invoice $number';
  }

  @override
  String statementRowReturn(Object number) {
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

  @override
  String get customersTab => 'Customers';

  @override
  String get customersEmpty => 'No customers found';

  @override
  String get customersSearchHint => 'Search by name, phone, or email';

  @override
  String get customerAdd => 'Add customer';

  @override
  String get customerAddTitle => 'New customer';

  @override
  String get customerEditTitle => 'Edit customer';

  @override
  String get customerName => 'Customer name';

  @override
  String get customerPhone => 'Phone';

  @override
  String get customerSecondaryPhone => 'Secondary phone';

  @override
  String get customerEmail => 'Email';

  @override
  String get customerAddress => 'Address';

  @override
  String get customerNotes => 'Notes';

  @override
  String get customerHasAccount => 'Credit account';

  @override
  String get customerAccount => 'Account';

  @override
  String get customerAccountEnabled => 'Enabled';

  @override
  String get customerAccountDisabled => 'Disabled';

  @override
  String get customerOpeningBalance => 'Opening balance';

  @override
  String get customerCreditLimit => 'Credit limit';

  @override
  String get customerDateOfBirth => 'Date of birth';

  @override
  String get customerGender => 'Gender';

  @override
  String get customerGenderMale => 'Male';

  @override
  String get customerGenderFemale => 'Female';

  @override
  String get customerMedicalHistory => 'Medical history';

  @override
  String get customerTaxVatNumber => 'Tax / VAT number';

  @override
  String get customerBalance => 'Account balance';

  @override
  String get customerNameRequired => 'Customer name is required';

  @override
  String get customerCreatedMessage => 'Customer added';

  @override
  String get customerUpdatedMessage => 'Customer updated';

  @override
  String get customerActivatedMessage => 'Customer re-activated';

  @override
  String get customerDeactivatedMessage => 'Customer deactivated';

  @override
  String get customerAccountEnabledMessage => 'Credit account enabled';

  @override
  String get customerAccountDisabledMessage => 'Credit account disabled';

  @override
  String customerDeactivateConfirmMessage(String name) {
    return 'Deactivate customer\"$name\"?';
  }

  @override
  String customerActivateConfirmMessage(String name) {
    return 'Re-activate customer\"$name\"?';
  }

  @override
  String customerAccountDisableConfirmMessage(String name) {
    return 'Disable credit account for\"$name\"?';
  }

  @override
  String customerAccountEnableConfirmMessage(String name) {
    return 'Enable credit account for\"$name\"?';
  }

  @override
  String get customerStatement => 'Statement';

  @override
  String get customerViewPrescriptions => 'Customer prescriptions';

  @override
  String get customerStatementDateFrom => 'From';

  @override
  String get customerStatementDateTo => 'To';

  @override
  String statementRowSaleInvoice(String number) {
    return 'Sales invoice $number';
  }

  @override
  String statementRowSaleReturn(String number) {
    return 'Sales return $number';
  }

  @override
  String get prescriptionsTab => 'Prescriptions';

  @override
  String get prescriptionsEmpty => 'No prescriptions found';

  @override
  String get prescriptionsSearchHint => 'Search by number, patient, or doctor';

  @override
  String get prescriptionAdd => 'New prescription';

  @override
  String get prescriptionAddTitle => 'New prescription';

  @override
  String get prescriptionNumber => 'Prescription No.';

  @override
  String get prescriptionPatient => 'Patient';

  @override
  String get prescriptionPatientName => 'Patient name';

  @override
  String get prescriptionPatientAge => 'Age';

  @override
  String get prescriptionPatientGender => 'Patient gender';

  @override
  String get prescriptionDoctorName => 'Doctor name';

  @override
  String get prescriptionDoctorSpecialty => 'Specialty';

  @override
  String get prescriptionClinicHospital => 'Clinic / hospital';

  @override
  String get prescriptionIssuedAt => 'Prescription date';

  @override
  String get prescriptionExpiryAt => 'Expiry date';

  @override
  String get prescriptionNotes => 'Prescription notes';

  @override
  String get prescriptionImagePath => 'Prescription image path';

  @override
  String get prescriptionItems => 'Prescription items';

  @override
  String get prescriptionAddItem => 'Add item';

  @override
  String get prescriptionItem => 'Item';

  @override
  String get prescriptionQuantity => 'Quantity';

  @override
  String get prescriptionDosage => 'Dosage';

  @override
  String get prescriptionFrequency => 'Frequency';

  @override
  String get prescriptionDurationDays => 'Duration (days)';

  @override
  String get prescriptionLineNotes => 'Line notes';

  @override
  String get prescriptionStatus => 'Status';

  @override
  String get prescriptionStatusActive => 'Active';

  @override
  String get prescriptionStatusPartiallyDispensed => 'Partially Dispensed';

  @override
  String get prescriptionStatusDispensed => 'Dispensed';

  @override
  String get prescriptionStatusExpired => 'Expired';

  @override
  String get prescriptionStatusCancelled => 'Cancelled';

  @override
  String get prescriptionCustomer => 'Customer';

  @override
  String get prescriptionRequiredCustomer =>
      'Select a customer — prescriptions require a patient';

  @override
  String get prescriptionRequiredPatient => 'Patient name is required';

  @override
  String get prescriptionRequiredItems => 'Add at least one item';

  @override
  String get prescriptionRequiredQuantity =>
      'Quantity must be greater than zero';

  @override
  String get prescriptionCreatedMessage => 'Prescription created';

  @override
  String get prescriptionDetail => 'Prescription details';

  @override
  String get prescriptionPrepareForSale => 'Prepare for sale';

  @override
  String get prescriptionPreparedMessage =>
      'Prescription is ready to link at the POS';

  @override
  String get prescriptionCannotPrepare =>
      'This prescription cannot be linked to a sale';

  @override
  String get partialSaleSection => 'Partial Sale Configuration';

  @override
  String get partialSaleEnabled => 'Allow Partial Selling';

  @override
  String get partialSalePartsPerFull => 'Parts Per Box';

  @override
  String get partialSaleMarkupPercent => 'Markup %';

  @override
  String get partialSalePartPrice => 'Part selling price';

  @override
  String get partialSaleRestoreAuto => 'Restore automatic price';

  @override
  String get partialSalePartPriceInvalid => 'Enter a valid part price';

  @override
  String get partialSalePartsRequired => 'Enter parts per full product';

  @override
  String get partialSalePartsInvalid => 'Parts per box must be greater than 1';

  @override
  String get partialSaleMarkupInvalid => 'Markup must be between 0 and 100%';

  @override
  String get posSearchHint => 'Search by name or barcode...';

  @override
  String get posScanOrSearch => 'Scan barcode or search products';

  @override
  String posCustomerTab(int tab) {
    return 'Customer $tab';
  }

  @override
  String get posReturnTab => 'Returns';

  @override
  String get posCartItemEmpty => 'Cart is empty — add items to sell';

  @override
  String get posDeleteHeldBill => 'Delete held bill';

  @override
  String get posUnitBox => 'Box';

  @override
  String get posUnitStrip => 'Sachets';

  @override
  String get posUnitUnit => 'Unit';

  @override
  String get posTotalLabel => 'Total';

  @override
  String get posPayButton => 'Pay (F12)';

  @override
  String get posHoldBill => 'Hold Bill (F5)';

  @override
  String get posHoldBillSaved => 'Bill held successfully';

  @override
  String get posHoldBillRestored => 'Bill restored';

  @override
  String get posHoldBillEmpty => 'No held bills';

  @override
  String get posCheckoutComplete => 'Sale completed successfully';

  @override
  String get posPrintReceipt => 'Print Receipt';

  @override
  String get posPrintFailed => 'Failed to print document';

  @override
  String get posQtyDecrease => 'Decrease quantity';

  @override
  String get posQtyIncrease => 'Increase quantity';

  @override
  String get posRemoveLine => 'Remove item';

  @override
  String get zReportTitle => 'End-of-Shift Report (Z)';

  @override
  String get zReportPrint => 'Print Report';

  @override
  String get zReportPeriodPrefix => 'Period';

  @override
  String get zReportFrom => 'From';

  @override
  String get zReportTo => 'To';

  @override
  String get zReportDays => 'day(s)';

  @override
  String get zReportSalesSummary => 'Sales Summary';

  @override
  String get zReportReturnsSection => 'Returns & Voided';

  @override
  String get zReportDrawerSection => 'Drawer Reconciliation';

  @override
  String get zReportInvoicesCount => 'Invoices';

  @override
  String get zReportUnitsSold => 'Units Sold';

  @override
  String get zReportTotalSales => 'Total Sales';

  @override
  String get zReportCash => 'Cash';

  @override
  String get zReportCard => 'Card';

  @override
  String get zReportCredit => 'Credit (A/R)';

  @override
  String get zReportReturnsBrief => 'Returns (count / value)';

  @override
  String get zReportVoidsBrief => 'Voided invoices (count / value)';

  @override
  String get zReportCustomerCollected => 'Customer credit collected';

  @override
  String get zReportCustomerRefunded => 'Customer credit refunded';

  @override
  String get zReportDrawerOpening => 'Opening balance';

  @override
  String get zReportDrawerNet => 'Net moves';

  @override
  String get zReportDrawerExpected => 'Expected closing';

  @override
  String get zReportDrawerLedger => 'Ledger running balance';

  @override
  String get zReportDrawerDeclared => 'Declared closing';

  @override
  String get zReportDrawerDiff => 'Drawer difference';

  @override
  String get zReportEmptyPeriod => 'No sales in the selected period';

  @override
  String get posReceiptSummaryTitle => 'Receipt Summary';

  @override
  String get posCashReceived => 'Cash Received';

  @override
  String get posCardAmount => 'Card Amount';

  @override
  String get posChangeLabel => 'Change';

  @override
  String get posMixedPayment => 'Mixed Payment (Cash + Card)';

  @override
  String get posInvalidPayment => 'Insufficient or invalid amount';

  @override
  String get posItemNotFound => 'Product not found';

  @override
  String get posOutOfStock => 'Out of stock';

  @override
  String get posRequiresPrescription => 'Requires active prescription';

  @override
  String get posReturnSearchHint => 'Search by invoice number or customer...';

  @override
  String get posNoInvoices => 'No matching invoices';

  @override
  String get posReturnableQuantity => 'Returnable Quantity';

  @override
  String get posReturnButton => 'Return';

  @override
  String get posReturnReason => 'Return Reason';

  @override
  String get posReturnSuccess => 'Return processed successfully';

  @override
  String get posOverReturnBlocked =>
      'Cannot return more than original quantity';

  @override
  String get posLostSaleTitle => 'Record Lost Sale';

  @override
  String get posLostSalePrompt => 'Enter product name and quantity';

  @override
  String get posLostSaleName => 'Product name / description';

  @override
  String get posLostSaleSciName => 'Scientific name';

  @override
  String get posLostSaleNotes => 'Notes';

  @override
  String get posLostSaleQty => 'Requested quantity';

  @override
  String get posLostSaleSaved => 'Lost sale recorded';

  @override
  String get posNoResults => 'No matching results';

  @override
  String get posCustomerLabel => 'Customer';

  @override
  String get posPrescriptionLabel => 'Prescription';

  @override
  String get posActivePrescriptions => 'Active Prescriptions';

  @override
  String get posNoPrescriptions => 'No active prescriptions for this customer';

  @override
  String get posPriceChange => 'Change Price';

  @override
  String get posItemAdded => 'Item added to cart';

  @override
  String get posCartCleared => 'Cart cleared';

  @override
  String get posQuantityUpdated => 'Quantity updated';

  @override
  String get posInvoiceTitle => 'Sale Invoice';

  @override
  String get posSaleNumber => 'Invoice Number';

  @override
  String get posSaleDate => 'Date';

  @override
  String get posLineItem => 'Product';

  @override
  String get posLineQty => 'Qty';

  @override
  String get posLineUnitPrice => 'Unit Price';

  @override
  String get posLineTotal => 'Total';

  @override
  String get posLineDiscount => 'Discount';

  @override
  String get posLineReturnable => 'Returnable Quantity';

  @override
  String get posAlternativesTitle => 'Suggested alternatives for';

  @override
  String get posAlternativesTier1 => 'Match: same ingredient, dose & form';

  @override
  String get posAlternativesTier2 => 'Same ingredient, different dose or form';

  @override
  String get posAlternativesTier3 => 'Shares an active ingredient';

  @override
  String get posAlternativesEmpty => 'No alternatives available';

  @override
  String get posAlternativesFailed => 'Could not load alternatives';

  @override
  String get posAvailableStock => 'Available';

  @override
  String get posCreditLabel => 'Credit';

  @override
  String get posCreditDownCash => 'Cash down payment';

  @override
  String get posCreditDownCard => 'Card down payment';

  @override
  String get posCreditRemaining => 'Due from customer';

  @override
  String get posCreditOutstanding => 'Current balance';

  @override
  String get posCreditAvailable => 'Available before limit';

  @override
  String get posCreditLimit => 'Credit limit';

  @override
  String get posCreditUnlimited => 'Unlimited';

  @override
  String get posCreditCustomerRequired =>
      'Credit sale requires selecting a customer with an account';

  @override
  String get posCashLabel => 'Cash';

  @override
  String get posCardLabel => 'Card';

  @override
  String get posMixedLabel => 'Mixed';

  @override
  String get posClearCart => 'Clear cart';

  @override
  String get posRx => 'Rx';

  @override
  String get posReceiptFooter =>
      'Pharmacy branch · Thank you for your business';

  @override
  String posItemCount(int count) {
    return '$count items';
  }

  @override
  String get posRestore => 'Restore';

  @override
  String get posCustomerSearchHint => 'Search customer by name or phone';

  @override
  String get posChooseActiveRx => 'Choose active prescription';

  @override
  String get posReturnSelectInvoiceHint =>
      'Choose an invoice from the list and set the quantities to return';

  @override
  String get posVoidInvoice => 'Void invoice';

  @override
  String get posInvoiceVoided => 'Invoice voided';

  @override
  String get posVoidInvoiceFailed => 'Could not void invoice';

  @override
  String get cashboxTitle => 'Cash Box';

  @override
  String get cashboxReadOnly =>
      'Read-only - you need the \'Operate Cash Box\' permission to run operations';

  @override
  String get cashboxActionOpen => 'Open Cash Box';

  @override
  String get cashboxActionClose => 'Close Cash Box';

  @override
  String get cashboxActionDeposit => 'Cash Deposit';

  @override
  String get cashboxActionWithdraw => 'Cash Withdrawal';

  @override
  String get cashboxActionAdjust => 'Adjust Drawer';

  @override
  String get cashboxSessionOpen => 'Session open';

  @override
  String get cashboxSessionClosed => 'Session closed';

  @override
  String get cashboxOpenedBy => 'Opened by';

  @override
  String get cashboxOpenedAt => 'Opened at';

  @override
  String get cashboxClosedBy => 'Closed by';

  @override
  String get cashboxClosedAt => 'Closed at';

  @override
  String get cashboxRunning => 'Running balance';

  @override
  String get cashboxExpected => 'Expected';

  @override
  String get cashboxDeclared => 'Declared';

  @override
  String get cashboxSurplus => 'Surplus';

  @override
  String get cashboxShortage => 'Shortage';

  @override
  String get cashboxMovementsTitle => 'Drawer Movements';

  @override
  String get cashboxTypeOpen => 'Opening';

  @override
  String get cashboxTypeClose => 'Closing';

  @override
  String get cashboxTypeSale => 'Cash sales';

  @override
  String get cashboxTypeRefund => 'Refunds';

  @override
  String get cashboxTypePayment => 'Customer collections';

  @override
  String get cashboxTypeDeposit => 'Deposits';

  @override
  String get cashboxTypeWithdraw => 'Withdrawals';

  @override
  String get cashboxTypeExpense => 'Expenses';

  @override
  String get cashboxTypeAdjustment => 'Adjustments';

  @override
  String get cashboxInflows => 'Inflows';

  @override
  String get cashboxOutflows => 'Outflows';

  @override
  String get cashboxNetMoves => 'Net moves';

  @override
  String get cashboxHistoryTitle => 'Cash Box Ledger';

  @override
  String get cashboxHistoryEmpty => 'No cash-box movements';

  @override
  String get cashboxFilterAll => 'All types';

  @override
  String get cashboxColTime => 'Time';

  @override
  String get cashboxColType => 'Type';

  @override
  String get cashboxColAmount => 'Amount';

  @override
  String get cashboxColRemaining => 'Balance';

  @override
  String get cashboxColOperator => 'Operator';

  @override
  String get cashboxColNote => 'Note';

  @override
  String get cashboxNotOpened => 'Cash box not opened';

  @override
  String get cashboxNotOpenedHint =>
      'Open the cash box to start a shift and record movements';

  @override
  String get cashboxNotOpenedReadOnly =>
      'Cash box not opened — ask the pharmacy manager to open it';

  @override
  String get cashboxOpeningLabel => 'Opening balance';

  @override
  String get cashboxNoteOptional => 'Note (optional)';

  @override
  String get cashboxDeclaredLabel => 'Counted cash on closing';

  @override
  String get cashboxReason => 'Reason';

  @override
  String get cashboxAmountLabel => 'Amount';

  @override
  String get cashboxAdjustHint =>
      'Positive adds to the drawer, negative removes';

  @override
  String get cashboxOpeningRequired => 'Enter the opening balance';

  @override
  String get cashboxOpeningInvalid => 'Invalid opening amount';

  @override
  String get cashboxClosingRequired => 'Enter the counted cash on closing';

  @override
  String get cashboxClosingInvalid => 'Invalid closing amount';

  @override
  String get cashboxMoveRequired => 'Enter an amount';

  @override
  String get cashboxMoveInvalid => 'Amount must be greater than zero';

  @override
  String get cashboxReasonRequired => 'Reason is required';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get expensesAdd => 'Record expense';

  @override
  String get expensesAddTitle => 'Record a new expense';

  @override
  String get expensesEmpty => 'No expenses recorded yet';

  @override
  String get expensesTotalCount => 'Total records';

  @override
  String get expensesPageTotal => 'This page total';

  @override
  String get expensesSearchHint => 'Search by description or expense number';

  @override
  String get expensesFilterAllCategories => 'All categories';

  @override
  String get expensesFilterAllPayments => 'All payment methods';

  @override
  String get expensesFilterAllStatus => 'All statuses';

  @override
  String get expensesFilterActiveOnly => 'Active only';

  @override
  String get expensesFilterVoidedOnly => 'Voided only';

  @override
  String get expensesStatusActive => 'Active';

  @override
  String get expensesStatusVoided => 'Voided';

  @override
  String get expensesReadOnly => 'Read-only — you do not manage expenses';

  @override
  String get expensesColNumber => 'Reference';

  @override
  String get expensesColDate => 'Date';

  @override
  String get expensesColDescription => 'Description';

  @override
  String get expensesColCategory => 'Category';

  @override
  String get expensesColPayment => 'Payment';

  @override
  String get expensesColAmount => 'Amount';

  @override
  String get expensesColOperator => 'Operator';

  @override
  String get expensesColStatus => 'Status';

  @override
  String get expensesCash => 'Cash';

  @override
  String get expensesCard => 'Card';

  @override
  String get expensesShowReceipt => 'View receipt';

  @override
  String get expensesAttachReceipt => 'Attach receipt';

  @override
  String get expensesCancelAction => 'Void expense';

  @override
  String get expenseAmount => 'Amount';

  @override
  String get expenseAmountRequired => 'Enter an amount';

  @override
  String get expenseAmountInvalid => 'Amount must be greater than zero';

  @override
  String get expenseDescription => 'Description';

  @override
  String get expenseDescriptionRequired => 'Enter an expense description';

  @override
  String get expenseCategory => 'Expense category';

  @override
  String get expenseCategoryRequired => 'Choose an expense category';

  @override
  String get expenseSupplier => 'Supplier (optional)';

  @override
  String get expenseNoSupplier => 'No supplier';

  @override
  String get expensePaymentNote =>
      'Payment is booked here and reversed cash/card on void';

  @override
  String get expenseDate => 'Expense date';

  @override
  String get expenseNotesOptional => 'Notes (optional)';

  @override
  String get expenseReceiptUnreadable =>
      'Cannot open file — it may be corrupt or unsupported';

  @override
  String get expenseEditDescription => 'Edit expense';

  @override
  String get expenseAmountImmutableHint =>
      'Amount, category and payment method are frozen after posting';

  @override
  String get expenseCancelTitle => 'Void expense';

  @override
  String get expenseCancelReason => 'Void reason';

  @override
  String get expenseCancelReasonRequired => 'Enter a void reason';

  @override
  String expenseCancelConfirmMessage(String number) {
    return 'Expense $number will be fully reversed in cash and in the ledger. This cannot be undone.';
  }

  @override
  String get expenseCategoryEditTitle => 'Edit category';

  @override
  String get expenseCategoryAddTitle => 'New expense category';

  @override
  String get expenseCategoryCode => 'Category code';

  @override
  String get expenseCategoryCodeHint => 'e.g. utilities, transport…';

  @override
  String get expenseCategoryName => 'Category name';

  @override
  String get expenseCategoryNameEn => 'Name (English, optional)';

  @override
  String get expenseCategoryAccount => 'Account (chart, e.g. 5100)';

  @override
  String get expenseCategorySystemBlock =>
      'System categories cannot be edited or disabled';

  @override
  String get expenseCategoriesTitle => 'Expense categories';

  @override
  String get expenseNoCategories => 'No expense categories';

  @override
  String get expenseCategoryAdd => 'New category';

  @override
  String get expenseCreatedMessage => 'Expense recorded';

  @override
  String get expenseUpdatedMessage => 'Expense updated';

  @override
  String get expenseCancelledMessage => 'Expense voided';

  @override
  String get expenseReceiptAttached => 'Receipt attached';

  @override
  String get expenseCategoryCreatedMessage => 'Category created';

  @override
  String get expenseCategoryUpdatedMessage => 'Category updated';

  @override
  String get expenseCategoryActivated => 'Category activated';

  @override
  String get expenseCategoryDeactivated => 'Category deactivated';

  @override
  String get navCashbox => 'Cashbox';

  @override
  String get navChartAccounts => 'Chart of Accounts';

  @override
  String get navJournal => 'Journal';

  @override
  String get navAccountStatement => 'Account Statement';

  @override
  String get navPeriodClose => 'Period Close';

  @override
  String get chartAccountsTitle => 'Chart of Accounts';

  @override
  String get journalTitle => 'Journal';

  @override
  String get accountStatementTitle => 'Account Statement';

  @override
  String get periodCloseTitle => 'Period Close';

  @override
  String get accountsAddTitle => 'Add Account';

  @override
  String get accountsEditTitle => 'Edit Account';

  @override
  String get accountsColCode => 'Code';

  @override
  String get accountsColName => 'Name';

  @override
  String get accountsColType => 'Type';

  @override
  String get accountsColBalance => 'Balance';

  @override
  String get accountsColStatus => 'Status';

  @override
  String get accountsNameEn => 'English Name';

  @override
  String get accountsOpeningBalance => 'Opening Balance';

  @override
  String get accountsNotes => 'Notes';

  @override
  String get accountsNoData => 'No data';

  @override
  String get accountsCodeRequired => 'Enter account code';

  @override
  String get accountsNameRequired => 'Enter account name';

  @override
  String get accountsFilterAll => 'All';

  @override
  String get accountTypeAsset => 'Asset';

  @override
  String get accountTypeLiability => 'Liability';

  @override
  String get accountTypeEquity => 'Equity';

  @override
  String get accountTypeRevenue => 'Revenue';

  @override
  String get accountTypeExpense => 'Expense';

  @override
  String get journalColEntryNumber => 'Entry #';

  @override
  String get journalColDate => 'Date';

  @override
  String get journalColDescription => 'Description';

  @override
  String get journalColRefType => 'Reference';

  @override
  String get journalColDebit => 'Debit';

  @override
  String get journalColCredit => 'Credit';

  @override
  String get journalFilterRefType => 'Ref Type';

  @override
  String get journalReversalBadge => 'Reversal';

  @override
  String get journalDetailTitle => 'Journal Detail';

  @override
  String get journalDetailLines => 'Journal Lines';

  @override
  String get accountStatementFromDate => 'From date';

  @override
  String get accountStatementToDate => 'To date';

  @override
  String get accountStatementClosingBalance => 'Closing Balance';

  @override
  String get accountStatementSelectAccount =>
      'Select an account to view statement';

  @override
  String get periodName => 'Period Name';

  @override
  String get periodStartDate => 'Start Date';

  @override
  String get periodEndDate => 'End Date';

  @override
  String get periodStatus => 'Status';

  @override
  String get periodOpen => 'Open';

  @override
  String get periodClosed => 'Closed';

  @override
  String get periodCreate => 'New Period';

  @override
  String get periodNameRequired => 'Enter period name';

  @override
  String get periodCreatedMessage => 'Period created';

  @override
  String get periodClosedMessage => 'Period closed';

  @override
  String get periodCloseConfirmMessage =>
      'Are you sure you want to close this period?';

  @override
  String get periodCloseReason => 'Close reason';

  @override
  String get refTypeSale => 'Sale';

  @override
  String get refTypePurchase => 'Purchase';

  @override
  String get refTypeReturn => 'Return';

  @override
  String get refTypeExpense => 'Expense';

  @override
  String get refTypeCashbox => 'Cashbox';

  @override
  String get refTypeOpeningBalance => 'Opening Balance';

  @override
  String get refTypeAdjustment => 'Adjustment';

  @override
  String get refTypeManual => 'Manual';

  @override
  String get refTypeCustomerPayment => 'Customer Payment';

  @override
  String get csRecordPayment => 'Record Payment';

  @override
  String get csPaymentTitle => 'Receive Customer Payment';

  @override
  String get csPaymentAmount => 'Amount';

  @override
  String get csPaymentCash => 'Cash';

  @override
  String get csPaymentCard => 'Card';

  @override
  String get csPaymentNote => 'Note';

  @override
  String get csPaymentAmountError => 'Enter a positive amount';

  @override
  String get csPaymentSplitError => 'Cash + card must equal the amount';

  @override
  String get csPaymentSaved => 'Payment recorded';

  @override
  String get csPaymentRefundTitle => 'Refund to Customer';

  @override
  String get reportExportExcel => 'Export to Excel';

  @override
  String get reportExportExcelDone => 'Excel file exported';

  @override
  String get reportTitle => 'Reports';

  @override
  String get reportAddTitle => 'Add Report';

  @override
  String get reportTrialBalance => 'Trial Balance';

  @override
  String get reportIncomeStatement => 'Income Statement';

  @override
  String get reportBalanceSheet => 'Balance Sheet';

  @override
  String get reportAccountStatement => 'Account Statement';

  @override
  String get reportSales => 'Sales';

  @override
  String get reportPurchases => 'Purchases';

  @override
  String get reportInventory => 'Inventory';

  @override
  String get reportLostSales => 'Lost Sales';

  @override
  String get reportCustomerStatement => 'Customer Statement';

  @override
  String get reportSupplierStatement => 'Supplier Statement';

  @override
  String get reportFromDate => 'From date';

  @override
  String get reportToDate => 'To date';

  @override
  String get reportRefresh => 'Refresh';

  @override
  String get reportNoPermission =>
      'You do not have permission to view this report';

  @override
  String get reportTrialBalanceTitle => 'Trial Balance';

  @override
  String get reportTrialBalanceAccount => 'Account';

  @override
  String get reportTrialBalanceOpening => 'Opening Balance';

  @override
  String get reportTrialBalanceDebit => 'Debit';

  @override
  String get reportTrialBalanceCredit => 'Credit';

  @override
  String get reportTrialBalanceClosing => 'Closing Balance';

  @override
  String get reportBalanced => 'Balanced';

  @override
  String get reportNotBalanced => 'Not balanced';

  @override
  String get reportIncomeSalesRevenue => 'Sales Revenue';

  @override
  String get reportIncomeSalesReturns => 'Sales Returns';

  @override
  String get reportIncomeNetRevenue => 'Net Revenue';

  @override
  String get reportIncomeCogs => 'Cost of Goods Sold';

  @override
  String get reportIncomeGrossProfit => 'Gross Profit';

  @override
  String get reportIncomeOperatingExpenses => 'Operating Expenses';

  @override
  String get reportIncomeNetIncome => 'Net Income';

  @override
  String get reportIncomeExpenseRow => 'Expense';

  @override
  String get reportBalanceAssets => 'Assets';

  @override
  String get reportBalanceLiabilities => 'Liabilities';

  @override
  String get reportBalanceEquity => 'Equity';

  @override
  String get reportBalanceTotal => 'Total';

  @override
  String get reportBalanceAsset => 'Asset';

  @override
  String get reportBalanceLiability => 'Liability';

  @override
  String get reportBalanceEquityItem => 'Item';

  @override
  String get reportBalanceRetainedEarnings =>
      'Retained Earnings (Accumulated Profit)';

  @override
  String get reportDate => 'Date';

  @override
  String get reportSalesCount => 'Invoices';

  @override
  String get reportSalesUnits => 'Units Sold';

  @override
  String get reportSalesSubtotal => 'Subtotal';

  @override
  String get reportSalesDiscount => 'Discount';

  @override
  String get reportSalesVat => 'VAT';

  @override
  String get reportSalesTotal => 'Total Sales';

  @override
  String get reportSalesNet => 'Net Sales';

  @override
  String get reportSalesPaid => 'Paid';

  @override
  String get reportSalesCash => 'Cash';

  @override
  String get reportSalesCard => 'Card';

  @override
  String get reportSalesCredit => 'Credit';

  @override
  String get reportSalesVoided => 'Voided';

  @override
  String get reportSalesReturns => 'Returns';

  @override
  String get reportSalesProfit => 'Profit';

  @override
  String get reportCustomer => 'Customer';

  @override
  String get reportAllCustomers => 'All customers';

  @override
  String get reportUser => 'User';

  @override
  String get reportAllUsers => 'All users';

  @override
  String get reportPurchasesCount => 'Invoices';

  @override
  String get reportPurchasesSubtotal => 'Subtotal';

  @override
  String get reportPurchasesDiscount => 'Discount';

  @override
  String get reportPurchasesTax => 'Tax';

  @override
  String get reportPurchasesShipping => 'Shipping';

  @override
  String get reportPurchasesTotal => 'Total Purchases';

  @override
  String get reportPurchasesPaid => 'Paid';

  @override
  String get reportPurchasesRemaining => 'Remaining';

  @override
  String get reportPurchasesNet => 'Net Purchases';

  @override
  String get reportPurchasesReturns => 'Purchase Returns';

  @override
  String get reportSupplier => 'Supplier';

  @override
  String get reportAllSuppliers => 'All suppliers';

  @override
  String get reportInventoryCount => 'Items';

  @override
  String get reportInventoryTotalStock => 'Total Stock';

  @override
  String get reportInventoryValue => 'Stock Value';

  @override
  String get reportInventoryLowStock => 'Low Stock';

  @override
  String get reportInventoryOutOfStock => 'Out of Stock';

  @override
  String get reportInventoryItemCode => 'Barcode';

  @override
  String get reportInventoryItemName => 'Item';

  @override
  String get reportInventoryCurrentStock => 'Current Stock';

  @override
  String get reportInventoryMin => 'Min';

  @override
  String get reportInventoryMax => 'Max';

  @override
  String get reportInventoryUnitCost => 'Avg. Cost';

  @override
  String get reportInventoryValue2 => 'Value';

  @override
  String get reportInventoryMovement => 'Inventory Movements';

  @override
  String get reportMovementType => 'Type';

  @override
  String get reportMovementCount => 'Movements';

  @override
  String get reportMovementQty => 'Quantity';

  @override
  String get reportMovementTotal => 'Total';

  @override
  String get reportLostSalesCount => 'Requests';

  @override
  String get reportLostSalesQty => 'Requested Qty';

  @override
  String get reportLostSalesItem => 'Item';

  @override
  String get reportLostSalesBarcode => 'Barcode';

  @override
  String get reportLostSalesCustomer => 'Customer';

  @override
  String get reportLostSalesStatus => 'Status';

  @override
  String get reportLostSalesNote => 'Note';

  @override
  String get reportLostStatusOpen => 'Open';

  @override
  String get reportLostStatusOrdered => 'Ordered';

  @override
  String get reportLostStatusResolved => 'Resolved';

  @override
  String get reportLostStatusCancelled => 'Cancelled';

  @override
  String get reportAllStatuses => 'All statuses';

  @override
  String get reportGeneratedAt => 'Generated at';

  @override
  String get reportPeriod => 'Period';

  @override
  String get reportSelectEntity => 'Select from list';

  @override
  String get reportStatementOpening => 'Opening Balance';

  @override
  String get reportNoData => 'No data in this range';

  @override
  String get navAudit => 'Audit log';

  @override
  String get auditDetailTitle => 'Event details';

  @override
  String get auditSearchHint => 'Search actions, entities, IDs or notes';

  @override
  String get auditFromDate => 'From date';

  @override
  String get auditToDate => 'To date';

  @override
  String get auditAllActions => 'All actions';

  @override
  String get auditAllUsers => 'All users';

  @override
  String get auditClearFilters => 'Clear filters';

  @override
  String get auditEmpty => 'No matching log entries';

  @override
  String get auditColumnDate => 'Time';

  @override
  String get auditColumnUser => 'User';

  @override
  String get auditColumnAction => 'Action';

  @override
  String get auditColumnEntity => 'Entity';

  @override
  String get auditColumnEntityId => 'ID';

  @override
  String get auditColumnNote => 'Note';

  @override
  String get auditSnapshotsTitle => 'Snapshots';

  @override
  String get auditBeforeLabel => 'Before';

  @override
  String get auditAfterLabel => 'After';

  @override
  String get auditActionCreate => 'Create';

  @override
  String get auditActionUpdate => 'Update';

  @override
  String get auditActionDelete => 'Delete';

  @override
  String get auditActionLogin => 'Sign in';

  @override
  String get auditActionLogout => 'Sign out';

  @override
  String get auditActionLoginFailed => 'Failed sign-in';

  @override
  String get auditActionVoid => 'Void';

  @override
  String get auditActionRestore => 'Restore';

  @override
  String get auditActionPriceChange => 'Price change';

  @override
  String get auditActionBulkOp => 'Bulk operation';

  @override
  String get auditActionConfig => 'Settings change';

  @override
  String get auditActionBackup => 'Backup';

  @override
  String get auditActionRestoreBackup => 'Restore backup';

  @override
  String get auditEntityUser => 'User';

  @override
  String get auditEntityRole => 'Role';

  @override
  String get auditEntityPermission => 'Permission';

  @override
  String get auditEntityAppSettings => 'System settings';

  @override
  String get auditEntityItem => 'Item';

  @override
  String get auditEntityBatch => 'Batch';

  @override
  String get auditEntityCategory => 'Category';

  @override
  String get auditEntityManufacturer => 'Manufacturer';

  @override
  String get auditEntityTherapeuticGroup => 'Therapeutic group';

  @override
  String get auditEntityUnit => 'Unit';

  @override
  String get auditEntityCustomer => 'Customer';

  @override
  String get auditEntitySupplier => 'Supplier';

  @override
  String get auditEntitySalesInvoice => 'Sales invoice';

  @override
  String get auditEntityPurchaseInvoice => 'Purchase invoice';

  @override
  String get auditEntityReturn => 'Return';

  @override
  String get auditEntityExpense => 'Expense';

  @override
  String get auditEntityPrescription => 'Prescription';

  @override
  String get auditEntityCashbox => 'Cashbox';

  @override
  String get auditEntityPeriod => 'Period';

  @override
  String get auditEntityLostSale => 'Lost sale';

  @override
  String get auditEntityBackup => 'Backup';

  @override
  String get settingsGeneralTitle => 'General settings';

  @override
  String get settingsBusinessName => 'Business name';

  @override
  String get settingsBusinessNameHint =>
      'Shown on invoices, receipts and reports';

  @override
  String get settingsBusinessNameRequired => 'Business name is required';

  @override
  String get settingsTaxRate => 'Tax rate';

  @override
  String get settingsTaxRateHint => 'Value-added tax rate';

  @override
  String get settingsTaxInvalid => 'Tax rate must be between 0% and 100%';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsCurrencyHint => 'Currency code displayed in the UI';

  @override
  String get settingsSavedMessage => 'Settings saved';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get shortcutsSubtitle =>
      'Applied across every screen and saved automatically';

  @override
  String get shortcutsSaved => 'Shortcuts updated';

  @override
  String get shortcutsDuplicate =>
      'This key is already used by another action — pick a different one';

  @override
  String get shortcutsSearch => 'Search product';

  @override
  String get shortcutsToggleUnit => 'Toggle box/fraction unit';

  @override
  String get shortcutsHoldBill => 'Hold bill';

  @override
  String get shortcutsCheckout => 'Checkout';

  @override
  String get shortcutsAlternatives => 'Show alternatives';

  @override
  String get rolesSubtitle => 'Manage user roles and their permissions';

  @override
  String get rolesAdd => 'Add role';

  @override
  String get rolesEmpty => 'No roles found';

  @override
  String get rolesCreateTitle => 'New role';

  @override
  String get rolesEditTitle => 'Edit role';

  @override
  String get rolesNameAr => 'Role name';

  @override
  String get rolesNameRequired => 'Role name is required';

  @override
  String get rolesPermissionsTitle => 'Permissions';

  @override
  String rolesPermissionsCount(int count) {
    return '$count permissions';
  }

  @override
  String rolesUsersCount(int count) {
    return '$count users';
  }

  @override
  String get rolesSystemBadge => 'System';

  @override
  String get rolesInactiveBadge => 'Disabled';

  @override
  String get rolesNameExists => 'Role name already exists';

  @override
  String rolesPermissionsFor(String name) {
    return 'Permissions for \"$name\"';
  }

  @override
  String get rolesPermissionsSaved => 'Permissions saved';

  @override
  String get rolesUpdatedMessage => 'Role updated';

  @override
  String get rolesCreatedMessage => 'Role created';

  @override
  String get rolesDeletedMessage => 'Role deleted';

  @override
  String get rolesDelete => 'Delete role';

  @override
  String get rolesDeleteTitle => 'Delete role';

  @override
  String rolesDeleteConfirm(String name) {
    return 'Delete role \"$name\"?';
  }

  @override
  String get rolesTabTitle => 'Roles';

  @override
  String get permissionsTabTitle => 'Permissions';

  @override
  String get permissionsSubtitle => 'All system permissions grouped by module';

  @override
  String get permissionsSelectAll => 'Select all';

  @override
  String get permissionsClearAll => 'Clear all';

  @override
  String get dataManagementTitle => 'Backup, Restore & Data';

  @override
  String get dataManagementSubtitle =>
      'Manage self-contained backups, restore and data export';

  @override
  String get dataManagementBackupTitle => 'Create a backup';

  @override
  String get dataManagementBackupHint =>
      'A self-contained archive with the database, attached expense receipts, manifest and audit trail.';

  @override
  String get dataManagementCreateBackup => 'Create backup';

  @override
  String get dataManagementChooseDestinationFolder =>
      'Choose destination folder';

  @override
  String get dataManagementBackupCreated => 'Backup created successfully';

  @override
  String dataManagementBackupSize(String size) {
    return 'Size: $size';
  }

  @override
  String get dataManagementRestoreTitle => 'Restore from backup';

  @override
  String get dataManagementRestoreHint =>
      'Restore fully replaces the current data. An automatic safety backup is created before any restore.';

  @override
  String get dataManagementChooseArchive => 'Choose backup archive';

  @override
  String get dataManagementRestoreNow => 'Start restore';

  @override
  String get dataManagementRestoreConfirmTitle => 'Confirm restore';

  @override
  String get dataManagementRestoreConfirmBody =>
      'The current data will be fully replaced by the archive contents. A safety backup is created first and this cannot be undone once completed.';

  @override
  String get dataManagementRestoreRestartRequired =>
      'Restore completed successfully. Please log out and restart the app to view the restored data.';

  @override
  String get dataManagementRestoreInvalid =>
      'The archive is not valid for restore';

  @override
  String get dataManagementRestorePreviewStatus => 'Status';

  @override
  String get dataManagementRestorePreviewSchema => 'Database version';

  @override
  String get dataManagementRestorePreviewDate => 'Backup date';

  @override
  String get dataManagementRestorePreviewApp => 'Application version';

  @override
  String get dataManagementRestorePreviewValid => 'Valid';

  @override
  String get dataManagementRestorePreviewInvalid => 'Invalid';

  @override
  String dataManagementRestoreSchemaNote(int version) {
    return 'Schema version in archive: $version';
  }

  @override
  String dataManagementFilesCount(int count) {
    return '$count attached files';
  }

  @override
  String get dataManagementExportTitle => 'Export data';

  @override
  String get dataManagementExportHint =>
      'Full export of all tables into CSV files inside a folder, with an info file, without modifying the database.';

  @override
  String get dataManagementExportNow => 'Start export';

  @override
  String get dataManagementExportDone => 'Data exported successfully';

  @override
  String get dataManagementExportDestination => 'Export folder';

  @override
  String dataManagementExportSummary(int rows, int tables) {
    return '$rows rows in $tables tables';
  }

  @override
  String get dataManagementNotPermitted =>
      'You do not have permission for this action';

  @override
  String get dataManagementRestartRequiredTitle => 'Restart required';

  @override
  String get auditLogDateFrom => 'From';

  @override
  String get auditLogDateTo => 'To';

  @override
  String get inventoryDeleteTitle => 'Delete item';

  @override
  String inventoryDeleteConfirm(String name) {
    return 'Permanently delete the item \"$name\"? This cannot be undone; only unused items can be deleted.';
  }

  @override
  String get inventoryDeleteBlocked =>
      'Cannot delete an item linked to stock, batches or invoices. Deactivate it instead.';

  @override
  String get inventoryDeleteMessage => 'Item deleted';

  @override
  String get masterDataDeleteTitle => 'Delete';

  @override
  String masterDataDeleteConfirm(String name) {
    return 'Permanently delete \"$name\"? An entry used by any product cannot be deleted.';
  }

  @override
  String get masterDataDeleteBlocked =>
      'Cannot delete an entry used by products or invoices. Deactivate it instead.';

  @override
  String get masterDataDeletedMessage => 'Entry deleted';

  @override
  String get masterDataSearchHint => 'Search by name';

  @override
  String masterDataCount(int count) {
    return '$count entries';
  }
}
