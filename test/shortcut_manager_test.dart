import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_pos/core/di/providers.dart';
import 'package:pharmacy_pos/core/shortcuts/pos_shortcuts.dart';
import 'package:pharmacy_pos/core/shortcuts/shortcut_bindings_controller.dart';
import 'package:pharmacy_pos/core/shortcuts/shortcut_manager.dart';
import 'package:pharmacy_pos/core/widgets/pos_shortcut_scope.dart';
import 'package:pharmacy_pos/shared/database/app_database.dart';
import 'package:pharmacy_pos/shared/database/settings_dao.dart';

import 'helpers.dart';

void main() {
  ensureSqlite();

  group('PosShortcutManager — §21 defaults', () {
    test('defaults match the roadmap table exactly', () {
      expect(
        PosShortcutManager.defaultBindings,
        const {
          PosShortcutKind.search: 'f1',
          PosShortcutKind.toggleUnit: 'f2',
          PosShortcutKind.holdBill: 'f5',
          PosShortcutKind.checkout: 'f12',
          PosShortcutKind.alternatives: 'alt_s',
        },
      );
      // Every default is an assignable key.
      for (final token in PosShortcutManager.defaultBindings.values) {
        expect(PosShortcutManager.assignable.containsKey(token), isTrue);
      }
    });

    test('intent map wires every action to its workspace intent', () {
      final map =
          PosShortcutManager.buildIntentMap(PosShortcutManager.defaultBindings);
      expect(map[const SingleActivator(LogicalKeyboardKey.f1)],
          isA<SearchFocusIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f2)],
          isA<ToggleUnitModeIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f5)],
          isA<HoldBillIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f12)],
          isA<CheckoutIntent>());
      expect(
        map[const SingleActivator(LogicalKeyboardKey.keyS, alt: true)],
        isA<ShowAlternativesIntent>(),
      );
    });

    test('unknown tokens are skipped instead of crashing', () {
      final map = PosShortcutManager.buildIntentMap({
        PosShortcutKind.search: 'nope',
        PosShortcutKind.checkout: 'f12',
      });
      expect(map.length, 1);
      expect(map[const SingleActivator(LogicalKeyboardKey.f12)],
          isA<CheckoutIntent>());
    });

    test('settingsMap persists only non-default bindings', () {
      final customized = Map<PosShortcutKind, String>.of(
          PosShortcutManager.defaultBindings)
        ..[PosShortcutKind.checkout] = 'f9';
      final persisted = PosShortcutManager.settingsMap(customized);
      expect(persisted, const {'shortcut.checkout': 'f9'});
      expect(PosShortcutManager.settingsMap(PosShortcutManager.defaultBindings),
          isEmpty);
    });

    test('resolveFromSettings falls back to defaults for bad values', () {
      final resolved = PosShortcutManager.resolveFromSettings({
        'shortcut.checkout': 'f11',
        'shortcut.search': 'garbage',
      });
      expect(resolved[PosShortcutKind.checkout], 'f11');
      expect(resolved[PosShortcutKind.search], 'f1');
      expect(resolved[PosShortcutKind.toggleUnit], 'f2');
    });

    test('firstConflict detects duplicate keys', () {
      expect(PosShortcutManager.firstConflict(PosShortcutManager.defaultBindings),
          isNull);
      expect(
        PosShortcutManager.firstConflict(
          Map.of(PosShortcutManager.defaultBindings)
            ..[PosShortcutKind.checkout] = 'f1',
        ),
        PosShortcutKind.checkout,
      );
    });
  });

  group('ShortcutBindingsController — persistence', () {
    late AppDatabase db;

    setUp(() => db = newDatabase());
    tearDown(() => db.close());

    test('starts from defaults and applies stored overrides once', () async {
      final dao = SettingsDao(db);
      await dao.setString('shortcut.holdBill', 'f6', updatedBy: 'test');
      final controller = ShortcutBindingsController(dao);
      expect(controller.state[PosShortcutKind.holdBill], 'f5');

      await controller.ensureLoaded();
      expect(controller.state[PosShortcutKind.holdBill], 'f6');
      expect(controller.state[PosShortcutKind.checkout], 'f12');

      // Second call is a no-op (idempotent).
      await dao.setString('shortcut.checkout', 'f7', updatedBy: 'test');
      await controller.ensureLoaded();
      expect(controller.state[PosShortcutKind.checkout], 'f12');
    });

    test('rebind persists the new binding through app_settings', () async {
      final dao = SettingsDao(db);
      final controller = ShortcutBindingsController(dao);
      await controller.ensureLoaded();

      final ok = await controller.rebind(PosShortcutKind.checkout, 'f9');
      expect(ok, isTrue);
      expect(controller.state[PosShortcutKind.checkout], 'f9');
      final stored = await dao.getString('shortcut.checkout');
      expect(stored, 'f9');
      expect(await dao.getString('shortcut.search'), isNull);
    });

    test('duplicate or unknown rebinds are rejected without persisting',
        () async {
      final dao = SettingsDao(db);
      final controller = ShortcutBindingsController(dao);
      await controller.ensureLoaded();

      expect(await controller.rebind(PosShortcutKind.checkout, 'f2'), isFalse);
      expect(await controller.rebind(PosShortcutKind.checkout, 'zzz'), isFalse);
      expect(controller.state[PosShortcutKind.checkout], 'f12');
      expect(await dao.getString('shortcut.checkout'), isNull);
    });
  });

  group('PosShortcutScope — app-wide registration (§21)', () {
    testWidgets('registers the five §21 keys above the shell', (tester) async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final container = ProviderContainer(
        overrides: [
          settingsDaoProvider.overrideWithValue(dao),
          shortcutBindingsProvider.overrideWith(
              (ref) => ShortcutBindingsController(dao)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PosShortcutScope(child: SizedBox()),
        ),
      ));
      await tester.pump();

      final shortcuts = tester.widget<Shortcuts>(find
          .ancestor(of: find.byType(SizedBox), matching: find.byType(Shortcuts))
          .first);
      final map = shortcuts.shortcuts;
      expect(map[const SingleActivator(LogicalKeyboardKey.f1)],
          isA<SearchFocusIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f2)],
          isA<ToggleUnitModeIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f5)],
          isA<HoldBillIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f12)],
          isA<CheckoutIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.keyS, alt: true)],
          isA<ShowAlternativesIntent>());
    });

    testWidgets('rebinding from settings re-registers live', (tester) async {
      final db = newDatabase();
      addTearDown(db.close);
      final dao = SettingsDao(db);
      final container = ProviderContainer(
        overrides: [
          settingsDaoProvider.overrideWithValue(dao),
          shortcutBindingsProvider.overrideWith(
              (ref) => ShortcutBindingsController(dao)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PosShortcutScope(child: SizedBox()),
        ),
      ));
      await tester.pump();

      final notifier = container.read(shortcutBindingsProvider.notifier);
      await notifier.rebind(PosShortcutKind.checkout, 'f9');
      await tester.pump();

      final map = tester
          .widget<Shortcuts>(find
              .ancestor(of: find.byType(SizedBox), matching: find.byType(Shortcuts))
              .first)
          .shortcuts;
      expect(map[const SingleActivator(LogicalKeyboardKey.f9)],
          isA<CheckoutIntent>());
      expect(map[const SingleActivator(LogicalKeyboardKey.f12)], isNull);
    });
  });
}