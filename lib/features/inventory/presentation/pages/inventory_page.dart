import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/items_tab.dart';
import '../widgets/master_data_tabs.dart';

/// Inventory section (§4, §22): items grid + master-data registries. The
/// shell renders the shared AppBar and section navigation around this page.
class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: context.appTypography.label,
              tabs: [
                Tab(text: l10n.inventoryTabItems),
                Tab(text: l10n.inventoryTabCategories),
                Tab(text: l10n.inventoryTabManufacturers),
                Tab(text: l10n.inventoryTabGroups),
                Tab(text: l10n.inventoryTabUnits),
                Tab(text: l10n.inventoryTabActiveIngredients),
                Tab(text: l10n.inventoryTabIndications),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ItemsTab(),
                CategoriesTab(),
                ManufacturersTab(),
                GroupsTab(),
                UnitsTab(),
                ActiveIngredientsTab(),
                IndicationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}