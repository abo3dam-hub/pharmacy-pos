import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'balance_sheet_tab.dart';
import 'customer_statement_tab.dart';
import 'income_statement_tab.dart';
import 'inventory_report_tab.dart';
import 'lost_sales_tab.dart';
import 'purchase_report_tab.dart';
import 'sales_report_tab.dart';
import 'supplier_statement_tab.dart';
import 'trial_balance_tab.dart';

/// Reports section hub (التقارير): read-only financial, sales, purchase,
/// inventory and lost-sales reports plus customer/supplier statements.
/// Every tab re-checks its own permission and renders a localized message when
/// the current role cannot view it.
class ReportsHubPage extends StatefulWidget {
  const ReportsHubPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ReportsHubPage> createState() => _ReportsHubPageState();
}

class _ReportsHubPageState extends State<ReportsHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 9,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.reportTrialBalance),
              Tab(text: l10n.reportIncomeStatement),
              Tab(text: l10n.reportBalanceSheet),
              Tab(text: l10n.reportSales),
              Tab(text: l10n.reportPurchases),
              Tab(text: l10n.reportInventory),
              Tab(text: l10n.reportLostSales),
              Tab(text: l10n.reportCustomerStatement),
              Tab(text: l10n.reportSupplierStatement),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              TrialBalanceTab(),
              IncomeStatementTab(),
              BalanceSheetTab(),
              SalesReportTab(),
              PurchaseReportTab(),
              InventoryReportTab(),
              LostSalesTab(),
              CustomerStatementTab(),
              SupplierStatementTab(),
            ],
          ),
        ),
      ],
    );
  }
}