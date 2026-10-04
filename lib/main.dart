import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/database_warmup.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'shared/database/app_database.dart';

/// Application entrypoint (§3, §33, §34).
///
/// Arabic-first: default locale is `ar` (RTL by `MaterialApp`); English stays
/// available as a secondary locale through the same l10n pipeline. All visual
/// tokens live in `AppTheme` — the single design-system source of truth.
/// Navigation is GoRouter driven (§36) with an authentication-aware redirect;
/// unauthenticated users land on the login page, everything else renders
/// inside the shell.
void main() async {
  // Binding first: the database warm-up below touches platform channels
  // (path resolution) before runApp().
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  // Open the database before the first frame so no list page can race app
  // startup and render empty until the user manually reloads.
  await warmUpDatabase(getIt<AppDatabase>());
  runApp(const ProviderScope(child: PharmacyApp()));
}

class PharmacyApp extends ConsumerWidget {
  const PharmacyApp({super.key, this.locale});

  /// Locale override (tests / future language setting). Defaults to Arabic.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      locale: locale ?? const Locale(AppConfig.defaultLocale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}