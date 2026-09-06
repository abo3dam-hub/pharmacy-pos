import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'l10n/app_localizations.dart';

/// Application entrypoint (§3, §33, §34).
///
/// Arabic-first: default locale is `ar` (RTL by `MaterialApp`); English stays
/// available as a secondary locale through the same l10n pipeline. All visual
/// tokens live in `AppTheme` — the single design-system source of truth.
void main() {
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key, this.locale});

  /// Locale override (tests / future language setting). Defaults to Arabic.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const AppShell(),
    );
  }
}