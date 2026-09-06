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
  reports(Icons.bar_chart),
  settings(Icons.settings_outlined);

  const AppSection(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
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