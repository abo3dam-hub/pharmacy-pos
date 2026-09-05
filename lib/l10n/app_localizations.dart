import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'نظام إدارة الصيدلية'**
  String get appTitle;

  /// No description provided for @appSlogan.
  ///
  /// In ar, this message translates to:
  /// **'نظام احترافي لإدارة الصيدلية و نقطة البيع'**
  String get appSlogan;

  /// No description provided for @navDashboard.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navDashboard;

  /// No description provided for @navSale.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات'**
  String get navSale;

  /// No description provided for @navInventory.
  ///
  /// In ar, this message translates to:
  /// **'المخزون'**
  String get navInventory;

  /// No description provided for @navPurchases.
  ///
  /// In ar, this message translates to:
  /// **'المشتريات'**
  String get navPurchases;

  /// No description provided for @navCustomers.
  ///
  /// In ar, this message translates to:
  /// **'العملاء'**
  String get navCustomers;

  /// No description provided for @navSuppliers.
  ///
  /// In ar, this message translates to:
  /// **'الموردون'**
  String get navSuppliers;

  /// No description provided for @navAccounts.
  ///
  /// In ar, this message translates to:
  /// **'الحسابات'**
  String get navAccounts;

  /// No description provided for @navReports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @navAlternatives.
  ///
  /// In ar, this message translates to:
  /// **'البدائل'**
  String get navAlternatives;

  /// No description provided for @navLostSales.
  ///
  /// In ar, this message translates to:
  /// **'النواقص'**
  String get navLostSales;

  /// No description provided for @navReturn.
  ///
  /// In ar, this message translates to:
  /// **'المرتجعات'**
  String get navReturn;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @commonSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get commonSearch;

  /// No description provided for @commonAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get commonAdd;

  /// No description provided for @commonDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get commonEdit;

  /// No description provided for @commonPrint.
  ///
  /// In ar, this message translates to:
  /// **'طباعة'**
  String get commonPrint;

  /// No description provided for @commonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get commonConfirm;

  /// No description provided for @commonClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get commonPrevious;

  /// No description provided for @commonLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get commonRetry;

  /// No description provided for @commonNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد'**
  String get commonNone;

  /// No description provided for @commonYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get commonNo;

  /// No description provided for @commonTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get commonTotal;

  /// No description provided for @commonSubtotal.
  ///
  /// In ar, this message translates to:
  /// **'المجموع الفرعي'**
  String get commonSubtotal;

  /// No description provided for @commonDiscount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get commonDiscount;

  /// No description provided for @commonTax.
  ///
  /// In ar, this message translates to:
  /// **'الضريبة'**
  String get commonTax;

  /// No description provided for @commonChange.
  ///
  /// In ar, this message translates to:
  /// **'الباقي'**
  String get commonChange;

  /// No description provided for @commonPaid.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get commonPaid;

  /// No description provided for @commonProfit.
  ///
  /// In ar, this message translates to:
  /// **'الربح'**
  String get commonProfit;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginTitle;

  /// No description provided for @loginUsername.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get loginPassword;

  /// No description provided for @loginButton.
  ///
  /// In ar, this message translates to:
  /// **'دخول'**
  String get loginButton;

  /// No description provided for @loginFailed.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم أو كلمة المرور غير صحيحة'**
  String get loginFailed;

  /// No description provided for @userLogout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get userLogout;

  /// No description provided for @userRole.
  ///
  /// In ar, this message translates to:
  /// **'الدور'**
  String get userRole;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير'**
  String get roleAdmin;

  /// No description provided for @rolePharmacist.
  ///
  /// In ar, this message translates to:
  /// **'صيدلي'**
  String get rolePharmacist;

  /// No description provided for @roleCashier.
  ///
  /// In ar, this message translates to:
  /// **'أمين الصندوق'**
  String get roleCashier;

  /// No description provided for @checkout.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء البيع'**
  String get checkout;

  /// No description provided for @holdBill.
  ///
  /// In ar, this message translates to:
  /// **'تعليق الفاتورة'**
  String get holdBill;

  /// No description provided for @cartEmpty.
  ///
  /// In ar, this message translates to:
  /// **'السلة فارغة'**
  String get cartEmpty;

  /// No description provided for @notEnoughStock.
  ///
  /// In ar, this message translates to:
  /// **'المخزون غير كافٍ'**
  String get notEnoughStock;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In ar, this message translates to:
  /// **'الكمية'**
  String get quantity;

  /// No description provided for @batchNo.
  ///
  /// In ar, this message translates to:
  /// **'رقم الدفعة'**
  String get batchNo;

  /// No description provided for @expiryDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get expiryDate;

  /// No description provided for @unitBoxes.
  ///
  /// In ar, this message translates to:
  /// **'علب'**
  String get unitBoxes;

  /// No description provided for @unitStrips.
  ///
  /// In ar, this message translates to:
  /// **'شرائط'**
  String get unitStrips;

  /// No description provided for @dashboardTodayOrders.
  ///
  /// In ar, this message translates to:
  /// **'طلبات اليوم'**
  String get dashboardTodayOrders;

  /// No description provided for @dashboardDailySales.
  ///
  /// In ar, this message translates to:
  /// **'مبيعات اليوم'**
  String get dashboardDailySales;

  /// No description provided for @dashboardLowStock.
  ///
  /// In ar, this message translates to:
  /// **'أصناف منخفضة المخزون'**
  String get dashboardLowStock;

  /// No description provided for @dashboardProfitToday.
  ///
  /// In ar, this message translates to:
  /// **'ربح اليوم'**
  String get dashboardProfitToday;

  /// No description provided for @inventoryLowStock.
  ///
  /// In ar, this message translates to:
  /// **'منخفض المخزون'**
  String get inventoryLowStock;

  /// No description provided for @inventoryOutOfStock.
  ///
  /// In ar, this message translates to:
  /// **'نفد المخزون'**
  String get inventoryOutOfStock;

  /// No description provided for @saleNewSale.
  ///
  /// In ar, this message translates to:
  /// **'بيع جديد'**
  String get saleNewSale;

  /// No description provided for @saleRecentInvoices.
  ///
  /// In ar, this message translates to:
  /// **'الفواتير الأخيرة'**
  String get saleRecentInvoices;

  /// No description provided for @purchaseNewPurchase.
  ///
  /// In ar, this message translates to:
  /// **'شراء جديد'**
  String get purchaseNewPurchase;

  /// No description provided for @purchaseRecent.
  ///
  /// In ar, this message translates to:
  /// **'فواتير الشراء الأخيرة'**
  String get purchaseRecent;

  /// No description provided for @customersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة العملاء'**
  String get customersList;

  /// No description provided for @suppliersList.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الموردين'**
  String get suppliersList;

  /// No description provided for @accountsCashbox.
  ///
  /// In ar, this message translates to:
  /// **'الصندوق'**
  String get accountsCashbox;

  /// No description provided for @accountsJournal.
  ///
  /// In ar, this message translates to:
  /// **'دفتر اليومية'**
  String get accountsJournal;

  /// No description provided for @accountsLedger.
  ///
  /// In ar, this message translates to:
  /// **'دفتر الأستاذ'**
  String get accountsLedger;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsDatabase.
  ///
  /// In ar, this message translates to:
  /// **'قاعدة البيانات'**
  String get settingsDatabase;

  /// No description provided for @settingsBackup.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get settingsBackup;

  /// No description provided for @settingsAppInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات التطبيق'**
  String get settingsAppInfo;

  /// No description provided for @settingsSchemaVersion.
  ///
  /// In ar, this message translates to:
  /// **'إصدار المخطط'**
  String get settingsSchemaVersion;

  /// No description provided for @settingsVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get settingsVersion;

  /// No description provided for @itemTradeName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم التجاري'**
  String get itemTradeName;

  /// No description provided for @itemBarcode.
  ///
  /// In ar, this message translates to:
  /// **'الباركود'**
  String get itemBarcode;

  /// No description provided for @itemCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get itemCategory;

  /// No description provided for @itemUnit.
  ///
  /// In ar, this message translates to:
  /// **'الوحدة'**
  String get itemUnit;

  /// No description provided for @itemCost.
  ///
  /// In ar, this message translates to:
  /// **'التكلفة'**
  String get itemCost;

  /// No description provided for @itemPrice.
  ///
  /// In ar, this message translates to:
  /// **'سعر البيع'**
  String get itemPrice;

  /// No description provided for @itemStock.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get itemStock;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
