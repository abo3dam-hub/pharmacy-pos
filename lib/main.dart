import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'l10n/app_localizations.dart';

/// App shell (§3, §33): Arabic-first RTL POS workspace.
///
/// Phase 1 wires the structural workspace (localization, RTL, fonts,
/// navigation). Module pages land in later phases; the shell renders a
/// labeled placeholder per section so navigation is testable today.
void main() {
  runApp(const PharmacyApp());
}

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00696D)),
        fontFamily: AppConfig.fontFamilyArabic,
      ),
      locale: const Locale(AppConfig.defaultLocale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

/// Persian/Arabic section list kept mirrored with §3 (roles/routes).
enum AppSection {
  dashboard(Icons.dashboard_outlined),
  sale(Icons.point_of_sale),
  inventory(Icons.inventory_2_outlined),
  purchases(Icons.shopping_cart_outlined),
  customers(Icons.people_outline),
  suppliers(Icons.local_shipping_outlined),
  accounts(Icons.account_balance_wallet_outlined),
  reports(Icons.bar_chart),
  settings(Icons.settings_outlined);

  const AppSection(this.icon);

  final IconData icon;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  String _label(AppLocalizations l10n, AppSection section) {
    return switch (section) {
      AppSection.dashboard => l10n.navDashboard,
      AppSection.sale => l10n.navSale,
      AppSection.inventory => l10n.navInventory,
      AppSection.purchases => l10n.navPurchases,
      AppSection.customers => l10n.navCustomers,
      AppSection.suppliers => l10n.navSuppliers,
      AppSection.accounts => l10n.navAccounts,
      AppSection.reports => l10n.navReports,
      AppSection.settings => l10n.navSettings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = AppSection.values;
    final selected = sections[_index];

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final section in sections)
                  NavigationRailDestination(
                    icon: Icon(section.icon),
                    label: Text(_label(l10n, section)),
                  ),
              ],
            ),
            Expanded(
              child: _SectionPage(
                icon: selected.icon,
                title: _label(l10n, selected),
                subtitle: l10n.appSlogan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 88, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}