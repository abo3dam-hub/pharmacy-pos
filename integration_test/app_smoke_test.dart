/// On-device smoke test: the real app launches, the login screen appears,
/// admin login works through the UI, and the dashboard + POS open.
///
/// Run on Windows:  `flutter test integration_test`
/// Run on Android:   connect a device/emulator, then `flutter test integration_test`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: launch -> login -> dashboard -> POS opens',
      (tester) async {
    await pumpE2EApp(tester);

    // 1. Login screen is the entry point for unauthenticated users.
    expect(find.text('دخول'), findsOneWidget);

    // 2. Log in through the real UI.
    await loginViaUI(tester);

    // 3. Dashboard landed.
    expect(find.text('الرئيسية'), findsWidgets);

    // 4. POS workspace opens and renders its empty state.
    await goToSales(tester);
    expect(find.text('السلة فارغة — أضف أصنافاً للبيع'), findsOneWidget);
  });
}
