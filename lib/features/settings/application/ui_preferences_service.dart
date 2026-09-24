import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/database/settings_dao.dart';
import '../../../../core/di/providers.dart';

/// Display density for data lists.
enum DisplayDensity {
  comfortable,
  compact;

  static DisplayDensity fromString(String? value) =>
      value == 'compact' ? compact : comfortable;

  String get key => name;
}

/// Simple key-value UI preferences stored in `app_settings`.
class UiPreferencesService {
  UiPreferencesService(this._dao);

  final SettingsDao _dao;

  static const String _densityKey = 'ui.display_density';
  static const String _receiptNameKey = 'receipt.pharmacy_name';
  static const String _receiptPromoKey = 'receipt.promo_line';
  static const String _receiptFontSizeKey = 'receipt.font_size';

  Future<DisplayDensity> displayDensity() async =>
      DisplayDensity.fromString(await _dao.getString(_densityKey));

  Future<void> setDisplayDensity(DisplayDensity density) =>
      _dao.setString(_densityKey, density.key);

  Future<String?> receiptPharmacyName() => _dao.getString(_receiptNameKey);

  Future<void> setReceiptPharmacyName(String value) =>
      _dao.setString(_receiptNameKey, value);

  Future<String?> receiptPromoLine() => _dao.getString(_receiptPromoKey);

  Future<void> setReceiptPromoLine(String value) =>
      _dao.setString(_receiptPromoKey, value);

  Future<double> receiptFontSize() async {
    final raw = await _dao.getString(_receiptFontSizeKey);
    return double.tryParse(raw ?? '') ?? 10.0;
  }

  Future<void> setReceiptFontSize(double value) =>
      _dao.setString(_receiptFontSizeKey, value.toString());
}

final uiPreferencesServiceProvider = Provider<UiPreferencesService>((ref) {
  final db = ref.watch(databaseProvider);
  return UiPreferencesService(SettingsDao(db));
});

final displayDensityProvider =
    StateNotifierProvider<DisplayDensityNotifier, DisplayDensity>((ref) {
  return DisplayDensityNotifier(ref.watch(uiPreferencesServiceProvider));
});

class DisplayDensityNotifier extends StateNotifier<DisplayDensity> {
  DisplayDensityNotifier(this._service)
      : super(DisplayDensity.comfortable) {
    _load();
  }

  final UiPreferencesService _service;

  Future<void> _load() async {
    state = await _service.displayDensity();
  }

  Future<void> set(DisplayDensity density) async {
    await _service.setDisplayDensity(density);
    state = density;
  }
}

/// Row height for list items based on density.
double listRowHeight(DisplayDensity density) =>
    density == DisplayDensity.compact ? 48.0 : 64.0;
