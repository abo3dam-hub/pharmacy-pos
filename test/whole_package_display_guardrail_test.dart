/// Whole-package display guardrail (Ali 2026-10-05, 4th report).
///
/// The pharmacist thinks and counts in whole commercial packages; the
/// database stores base units. Every past "parts leak" was a presentation
/// file interpolating a raw `*Base` quantity straight into the UI. This test
/// scans all presentation code and fails CI if any display string shows a
/// bare base-unit quantity.
///
/// Allowed:
///  * `formatBaseQuantity(qty, unitsPerLarge)` / `formatMixedQuantity(qty,
///    unitsPerLarge)` — the display gateways;
///  * explicit package conversion (`~/ unitsPerLarge`);
///  * entries in [_allowlisted] with a documented justification.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `file.dart:line` entries that legitimately interpolate a base quantity in
/// presentation code, with the reason why each is NOT a parts leak.
const Map<String, String> _allowlisted = {
  // Purchase form: deliberate base-unit ENTRY mode (segmented toggle labeled
  // with the unit name). Defaults to package mode when unitsPerLarge > 1.
  'lib/features/purchases/presentation/pages/purchase_form_page.dart:554':
      'base-unit entry mode fallback of _displayQty (explicit user toggle)',
  // Purchase form: bonus quantity INPUT field. Bonus entry stays in base
  // units by design (2026-09-24 decision); this is an editor, not a display.
  'lib/features/purchases/presentation/pages/purchase_form_page.dart:1228':
      'bonus quantity input field (editor, not display)',
  // POS search row: part-sale CONFIGURATION label ("شريط 10×3 = 30").
  // Describes the item's packaging structure, not a transacted quantity.
  'lib/features/sales/presentation/pages/pos_workspace_page.dart:794':
      'packaging-structure label, not a quantity',
};

/// Bare base-unit quantity identifiers that must never reach the UI raw.
/// Matches any identifier containing capital-`Base` (e.g. `quantityBase`,
/// `quantityBaseSigned`, `availableStockBase`); identifiers with only
/// lowercase "base" (e.g. `baseUnitName`) don't match.
final _bareBaseQty = RegExp(
  r'''\$\{?[A-Za-z_][A-Za-z0-9_.]*Base[A-Za-z0-9_]*''',
);

void main() {
  test('no raw base-unit quantity is interpolated in presentation UI', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from the repo root');

    final violations = <String>[];
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            f.path.contains('/presentation/') ||
            f.path.contains('lib/core/widgets/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files, isNotEmpty, reason: 'no presentation files found');

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_bareBaseQty.hasMatch(line)) continue;
        // The sanctioned display gateways.
        if (line.contains('formatBaseQuantity(')) continue;
        if (line.contains('formatMixedQuantity(')) continue;
        // Explicit package conversion, e.g. '${q ~/ upl}'.
        if (line.contains('~/')) continue;
        final key = '${file.path}:${i + 1}';
        if (_allowlisted.containsKey(key)) continue;
        violations.add('$key\n    $line\n    → wrap in formatBaseQuantity()');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Raw base-unit quantities shown in the UI '
          '(whole-package rule):\n${violations.join('\n')}',
    );
  });
}
