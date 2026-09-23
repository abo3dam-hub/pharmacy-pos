import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/scanning/barcode_scan_service.dart';
import 'package:pharmacy_pos/core/scanning/scan_barcode_button.dart';
import 'package:pharmacy_pos/core/widgets/search_field.dart';
import 'package:pharmacy_pos/l10n/app_localizations.dart';

class _FakeScanService extends BarcodeScanService {
  _FakeScanService(this.result);

  final String? result;
  int calls = 0;

  @override
  Future<String?> scan(BuildContext context) {
    calls++;
    return Future.value(result);
  }
}

Widget _harness(Widget home) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: home),
);

void main() {
  late bool Function() originalSupport;
  late BarcodeScanService originalService;

  setUp(() {
    originalSupport = BarcodeScanService.isCameraScanSupported;
    originalService = BarcodeScanService.current;
  });

  tearDown(() {
    BarcodeScanService.isCameraScanSupported = originalSupport;
    BarcodeScanService.current = originalService;
  });

  group('BarcodeScanService', () {
    test('scan returns null without opening anything when unsupported', () async {
      BarcodeScanService.isCameraScanSupported = () => false;
      expect(await BarcodeScanService().scan(_NeverContext()), isNull);
    });

    test('isCameraScanSupported is false on the desktop test host', () {
      expect(BarcodeScanService.isCameraScanSupported(), isFalse);
    });
  });

  group('ScanBarcodeButton', () {
    testWidgets('renders nothing on unsupported platforms', (tester) async {
      BarcodeScanService.isCameraScanSupported = () => false;
      await tester.pumpWidget(_harness(ScanBarcodeButton(onScanned: (_) {})));
      await tester.pump();
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    });

    testWidgets('delivers the scanned code to onScanned', (tester) async {
      BarcodeScanService.isCameraScanSupported = () => true;
      BarcodeScanService.current = _FakeScanService('987654321');
      String? scanned;
      await tester.pumpWidget(
        _harness(ScanBarcodeButton(onScanned: (c) => scanned = c)),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();
      expect(scanned, '987654321');
    });

    testWidgets('does nothing when the scan is cancelled', (tester) async {
      BarcodeScanService.isCameraScanSupported = () => true;
      BarcodeScanService.current = _FakeScanService(null);
      var called = false;
      await tester.pumpWidget(
        _harness(ScanBarcodeButton(onScanned: (_) => called = true)),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();
      expect(called, isFalse);
    });
  });

  group('SearchField scan integration', () {
    testWidgets('scan fills the query and reports it immediately', (
      tester,
    ) async {
      BarcodeScanService.isCameraScanSupported = () => true;
      BarcodeScanService.current = _FakeScanService('112233');
      final seen = <String>[];
      final scanned = <String>[];
      await tester.pumpWidget(
        _harness(
          SearchField(
            onChanged: seen.add,
            onScan: scanned.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();
      expect(scanned, ['112233']);
      expect(seen, ['112233']);
      expect(find.text('112233'), findsOneWidget);
    });

    testWidgets('no scan button when onScan is not provided', (tester) async {
      BarcodeScanService.isCameraScanSupported = () => true;
      await tester.pumpWidget(_harness(SearchField(onChanged: (_) {})));
      await tester.pump();
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    });
  });
}

/// A BuildContext stand-in that must never be used — the unsupported path
/// returns before touching the context.
class _NeverContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
