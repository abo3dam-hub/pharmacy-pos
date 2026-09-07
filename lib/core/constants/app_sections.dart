import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Primary workspace sections — the shell navigation map (§3, §20 POS tabs).
///
/// Labels come from the centralized string catalog; each section has a single
/// icon so rail/drawer/route reuse the same identity.
enum AppSection {
  dashboard(Icons.dashboard_outlined),
  sale(Icons.point_of_sale),
  inventory(Icons.inventory_2_outlined),
  purchases(Icons.shopping_cart_outlined),
  customers(Icons.people_outline),
  suppliers(Icons.local_shipping_outlined),
  accounts(Icons.account_balance_wallet_outlined),
  expenses(Icons.receipt_long_outlined),
  reports(Icons.bar_chart),
  settings(Icons.settings_outlined),
  users(Icons.manage_accounts_outlined);

  const AppSection(this.icon);

  final IconData icon;

  /// Canonical route path for the section (used by the shell's GoRouter).
  String get path => switch (this) {
        AppSection.dashboard => '/',
        AppSection.sale => '/sale',
        AppSection.inventory => '/inventory',
        AppSection.purchases => '/purchases',
        AppSection.customers => '/customers',
        AppSection.suppliers => '/suppliers',
        AppSection.accounts => '/accounts',
        AppSection.expenses => '/expenses',
        AppSection.reports => '/reports',
        AppSection.settings => '/settings',
        AppSection.users => '/users',
      };

  /// Resolves a route path back to its section (unknown → dashboard).
  /// Nested sub-routes (e.g. `/inventory/batches/:id`) map to their section.
  static AppSection fromPath(String path) {
    if (path == AppSection.dashboard.path) return AppSection.dashboard;
    for (final section in AppSection.values) {
      if (section == AppSection.dashboard) continue;
      if (path == section.path || path.startsWith('${section.path}/')) {
        return section;
      }
    }
    return AppSection.dashboard;
  }

  String label(AppLocalizations l10n) => switch (this) {
        AppSection.dashboard => l10n.navDashboard,
        AppSection.sale => l10n.navSale,
        AppSection.inventory => l10n.navInventory,
        AppSection.purchases => l10n.navPurchases,
        AppSection.customers => l10n.navCustomers,
        AppSection.suppliers => l10n.navSuppliers,
        AppSection.accounts => l10n.navAccounts,
        AppSection.expenses => l10n.navExpenses,
        AppSection.reports => l10n.navReports,
        AppSection.settings => l10n.navSettings,
        AppSection.users => l10n.navUsers,
      };
}