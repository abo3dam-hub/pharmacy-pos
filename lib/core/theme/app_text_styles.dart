import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'app_colors.dart';

/// Typography design tokens — a single named hierarchy used by the whole app.
///
/// Every screen reads styles from `AppTypography` (a Material 3
/// `ThemeExtension`) instead of hand-writing `TextStyle`s. Roles:
/// pageTitle/sectionTitle (titles), body/bodySecondary (paragraphs + fields),
/// label/labelSmall (controls + captions), table/tableHeader (grids),
/// numeric/numericStrong (tabular figures), price, quantity, invoiceNumber.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.pageTitle,
    required this.sectionTitle,
    required this.body,
    required this.bodySecondary,
    required this.label,
    required this.labelSmall,
    required this.table,
    required this.tableHeader,
    required this.numeric,
    required this.numericStrong,
    required this.price,
    required this.quantity,
    required this.invoiceNumber,
  });

  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle body;
  final TextStyle bodySecondary;
  final TextStyle label;
  final TextStyle labelSmall;
  final TextStyle table;
  final TextStyle tableHeader;
  final TextStyle numeric;
  final TextStyle numericStrong;
  final TextStyle price;
  final TextStyle quantity;
  final TextStyle invoiceNumber;

  static const String _font = AppConfig.fontFamilyArabic;

  static const List<FontFeature> _t = [FontFeature.tabularFigures()];

  factory AppTypography.light(TextTheme base) => _build(
        base,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        accent: AppColors.primarySeed,
      );

  factory AppTypography.dark(TextTheme base) => _build(
        base,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        accent: AppColors.darkSuccess,
      );

  static AppTypography _build(
    TextTheme base, {
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
  }) =>
      AppTypography(
        pageTitle: base.headlineMedium!.copyWith(
          fontFamily: _font,
          fontSize: 28,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        sectionTitle: base.titleLarge!.copyWith(
          fontFamily: _font,
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        body: base.bodyLarge!.copyWith(
          fontFamily: _font,
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySecondary: base.bodyMedium!.copyWith(
          fontFamily: _font,
          fontSize: 14,
          height: 1.5,
          color: textSecondary,
        ),
        label: base.labelLarge!.copyWith(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelSmall: base.labelMedium!.copyWith(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        table: base.bodyMedium!.copyWith(
          fontFamily: _font,
          fontSize: 13,
          height: 1.4,
          fontFeatures: _t,
          color: textPrimary,
        ),
        tableHeader: base.labelMedium!.copyWith(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: textSecondary,
        ),
        numeric: base.bodyMedium!.copyWith(
          fontFamily: _font,
          fontSize: 14,
          fontFeatures: _t,
          color: textPrimary,
        ),
        numericStrong: base.bodyMedium!.copyWith(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFeatures: _t,
          color: textPrimary,
        ),
        price: base.titleMedium!.copyWith(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFeatures: _t,
          color: accent,
        ),
        quantity: base.titleSmall!.copyWith(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFeatures: _t,
          color: textPrimary,
        ),
        invoiceNumber: base.labelMedium!.copyWith(
          fontFamily: _font,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          fontFeatures: _t,
          color: textPrimary,
        ),
      );

  @override
  AppTypography copyWith({
    TextStyle? pageTitle,
    TextStyle? sectionTitle,
    TextStyle? body,
    TextStyle? bodySecondary,
    TextStyle? label,
    TextStyle? labelSmall,
    TextStyle? table,
    TextStyle? tableHeader,
    TextStyle? numeric,
    TextStyle? numericStrong,
    TextStyle? price,
    TextStyle? quantity,
    TextStyle? invoiceNumber,
  }) {
    return AppTypography(
      pageTitle: pageTitle ?? this.pageTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      body: body ?? this.body,
      bodySecondary: bodySecondary ?? this.bodySecondary,
      label: label ?? this.label,
      labelSmall: labelSmall ?? this.labelSmall,
      table: table ?? this.table,
      tableHeader: tableHeader ?? this.tableHeader,
      numeric: numeric ?? this.numeric,
      numericStrong: numericStrong ?? this.numericStrong,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySecondary: TextStyle.lerp(bodySecondary, other.bodySecondary, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      table: TextStyle.lerp(table, other.table, t)!,
      tableHeader: TextStyle.lerp(tableHeader, other.tableHeader, t)!,
      numeric: TextStyle.lerp(numeric, other.numeric, t)!,
      numericStrong: TextStyle.lerp(numericStrong, other.numericStrong, t)!,
      price: TextStyle.lerp(price, other.price, t)!,
      quantity: TextStyle.lerp(quantity, other.quantity, t)!,
      invoiceNumber: TextStyle.lerp(invoiceNumber, other.invoiceNumber, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppTypography &&
      other.pageTitle == pageTitle &&
      other.sectionTitle == sectionTitle &&
      other.body == body &&
      other.bodySecondary == bodySecondary &&
      other.label == label &&
      other.labelSmall == labelSmall &&
      other.table == table &&
      other.tableHeader == tableHeader &&
      other.numeric == numeric &&
      other.numericStrong == numericStrong &&
      other.price == price &&
      other.quantity == quantity &&
      other.invoiceNumber == invoiceNumber;

  @override
  int get hashCode => Object.hashAll([
        pageTitle,
        sectionTitle,
        body,
        bodySecondary,
        label,
        labelSmall,
        table,
        tableHeader,
        numeric,
        numericStrong,
        price,
        quantity,
        invoiceNumber,
      ]);
}

extension AppTypographyContext on BuildContext {
  AppTypography get appTypography =>
      Theme.of(this).extension<AppTypography>()!;
}