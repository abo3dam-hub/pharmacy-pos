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
}
