import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'cashbox_page.dart';
import 'chart_of_accounts_page.dart';
import 'journal_page.dart';
import 'account_statement_page.dart';
import 'periods_page.dart';

/// Accounts section hub with tabs for sub-modules.
class AccountsHubPage extends StatefulWidget {
  const AccountsHubPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AccountsHubPage> createState() => _AccountsHubPageState();
}

class _AccountsHubPageState extends State<AccountsHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
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
              Tab(text: l10n.navCashbox),
              Tab(text: l10n.navChartAccounts),
              Tab(text: l10n.navJournal),
              Tab(text: l10n.navAccountStatement),
              Tab(text: l10n.navPeriodClose),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              CashboxPage(),
              ChartOfAccountsPage(),
              JournalPage(),
              AccountStatementPage(),
              PeriodsPage(),
            ],
          ),
        ),
      ],
    );
  }
}
