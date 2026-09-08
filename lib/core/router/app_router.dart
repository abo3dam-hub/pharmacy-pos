import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sections.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/pages/access_denied_page.dart';
import '../../features/auth/presentation/pages/admin_hub_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/accounts/presentation/pages/accounts_hub_page.dart';
import '../../features/accounts/presentation/pages/cashbox_page.dart';
import '../../features/accounts/presentation/pages/chart_of_accounts_page.dart';
import '../../features/accounts/presentation/pages/journal_page.dart';
import '../../features/accounts/presentation/pages/journal_detail_page.dart';
import '../../features/accounts/presentation/pages/account_statement_page.dart';
import '../../features/accounts/presentation/pages/periods_page.dart';
import '../../features/audit/presentation/pages/audit_log_page.dart';
import '../../features/customers/presentation/pages/customer_statement_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/inventory/presentation/pages/batches_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/prescriptions/presentation/pages/prescription_detail_page.dart';
import '../../features/prescriptions/presentation/pages/prescription_form_page.dart';
import '../../features/purchases/presentation/pages/purchase_detail_page.dart';
import '../../features/purchases/presentation/pages/purchase_form_page.dart';
import '../../features/purchases/presentation/pages/purchases_page.dart';
import '../../features/sales/presentation/pages/pos_invoice_page.dart';
import '../../features/sales/presentation/pages/pos_workspace_page.dart';
import '../../features/sales/presentation/pages/z_report_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/suppliers/presentation/pages/supplier_statement_page.dart';
import '../../features/suppliers/presentation/pages/suppliers_page.dart';
import '../../features/reports/presentation/pages/reports_hub_page.dart';

/// Bridges a [Stream] to the [Listenable] interface GoRouter refreshes on.
class _GoRouterListenable extends ChangeNotifier {
  _GoRouterListenable(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// App navigation via GoRouter (§36).
///
/// Authentication-aware:
///   * unauthenticated → `/login`
///   * authenticated + `/login` → `/`
///   * section pages render inside `AppShell` (single shell, no second router)
///   * `/users` requires `users.view` → otherwise `/access-denied`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider.notifier);

  final router = GoRouter(
    refreshListenable: _GoRouterListenable(auth.stream),
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;
      if (!authState.isAuthenticated) {
        return path == '/login' ? null : '/login';
      }
      if (path == '/login') return '/';
      if (path == AppSection.users.path &&
          !authState.permissions.contains(Perm.usersView) &&
          !authState.permissions.contains(Perm.rolesView)) {
        return '/access-denied';
      }
      if (path.startsWith('${AppSection.users.path}/roles') ||
          path.startsWith('${AppSection.users.path}/permissions')) {
        if (!authState.permissions.contains(Perm.rolesView)) {
          return '/access-denied';
        }
      }
      if (path == AppSection.audit.path &&
          !authState.permissions.contains(Perm.auditView)) {
        return '/access-denied';
      }
      if (path == AppSection.settings.path &&
          !authState.permissions.contains(Perm.settingsView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.sale.path) &&
          !authState.permissions.contains(Perm.salesView)) {
        return '/access-denied';
      }
      if (path == '${AppSection.sale.path}/z-report' &&
          !authState.permissions.contains(Perm.reportsViewSales)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.inventory.path) &&
          !authState.permissions.contains(Perm.inventoryView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.suppliers.path) &&
          !authState.permissions.contains(Perm.suppliersView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.purchases.path) &&
          !authState.permissions.contains(Perm.purchasesView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.customers.path) &&
          !authState.permissions.contains(Perm.customersView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.accounts.path) &&
          !authState.permissions.contains(Perm.cashboxView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.expenses.path) &&
          !authState.permissions.contains(Perm.expensesView)) {
        return '/access-denied';
      }
      if (path.startsWith(AppSection.reports.path) &&
          !_hasAnyReportPermission(authState.permissions)) {
        return '/access-denied';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, _) => const LoginPage(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, _) => const AccessDeniedPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final section = AppSection.fromPath(state.uri.path);
          return AppShell(
            selectedSection: section,
            onSectionSelected: (s) => context.go(s.path),
            appBarActions: [
              _LogoutButton(),
            ],
            child: child,
          );
        },
        routes: [
          for (final section in AppSection.values)
            GoRoute(
              path: section.path == '/' ? '/' : section.path,
              builder: (context, _) => _sectionPage(section, context),
              routes: [
                if (section == AppSection.users) ...[
                  GoRoute(
                    path: 'roles',
                    builder: (context, _) =>
                        const AdminHubPage(initialTab: AdminTab.roles),
                  ),
                  GoRoute(
                    path: 'permissions',
                    builder: (context, _) =>
                        const AdminHubPage(initialTab: AdminTab.permissions),
                  ),
                ],
                if (section == AppSection.inventory)
                  GoRoute(
                    path: 'batches/:itemId',
                    builder: (context, state) => BatchesPage(
                      itemId: state.pathParameters['itemId']!,
                    ),
                  ),
                if (section == AppSection.suppliers)
                  GoRoute(
                    path: 'statement/:supplierId',
                    builder: (context, state) => SupplierStatementView(
                      supplierId: state.pathParameters['supplierId']!,
                    ),
                  ),
                if (section == AppSection.purchases) ...[
                  GoRoute(
                    path: 'new',
                    builder: (context, _) => const PurchaseFormPage(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    builder: (context, state) => PurchaseFormPage(
                      invoiceId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) => PurchaseDetailPage(
                      invoiceId: state.pathParameters['id']!,
                    ),
                  ),
                ],
                if (section == AppSection.sale) ...[
                  GoRoute(
                    path: 'invoice/:invoiceId',
                    builder: (context, state) => PosInvoicePage(
                      invoiceId: state.pathParameters['invoiceId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'z-report',
                    builder: (context, _) => const ZReportPage(),
                  ),
                ],
                if (section == AppSection.customers) ...[
                  GoRoute(
                    path: 'statement/:customerId',
                    builder: (context, state) => CustomerStatementView(
                      customerId: state.pathParameters['customerId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'prescriptions/new',
                    name: 'prescription-new',
                    builder: (context, _) => const PrescriptionFormPage(),
                  ),
                  GoRoute(
                    path: 'prescriptions/detail/:id',
                    name: 'prescription-detail',
                    builder: (context, state) => PrescriptionDetailPage(
                      prescriptionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
                if (section == AppSection.accounts) ...[
                  GoRoute(
                    path: 'cashbox',
                    builder: (context, _) => const CashboxPage(),
                  ),
                  GoRoute(
                    path: 'chart',
                    builder: (context, _) => const ChartOfAccountsPage(),
                  ),
                  GoRoute(
                    path: 'journal',
                    builder: (context, _) => const JournalPage(),
                  ),
                  GoRoute(
                    path: 'journal/detail/:id',
                    builder: (context, state) => JournalDetailPage(
                      entryId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'statement',
                    builder: (context, _) => const AccountStatementPage(),
                  ),
                  GoRoute(
                    path: 'periods',
                    builder: (context, _) => const PeriodsPage(),
                  ),
                ],
              ],
            ),
        ],
      ),
    ],
  );
  return router;
});

/// True when the current role holds any report-producing permission. The hub
/// route itself is gated on the union; individual tabs re-check their own.
bool _hasAnyReportPermission(Set<String> permissions) {
  const reportPerms = <String>{
    Perm.reportsViewSales,
    Perm.reportsViewPurchases,
    Perm.reportsViewInventory,
    Perm.reportsViewProfit,
    Perm.lostSalesView,
    Perm.accountingView,
  };
  return permissions.any(reportPerms.contains);
}

/// Placeholder modules render `SectionPlaceholder`; real modules return their
/// page. `/users` is the first built module (§16).
Widget _sectionPage(AppSection section, BuildContext context) {
  if (section == AppSection.sale) return const PosWorkspacePage();
  if (section == AppSection.users) return const AdminHubPage();
  if (section == AppSection.inventory) return const InventoryPage();
  if (section == AppSection.suppliers) return const SuppliersPage();
  if (section == AppSection.purchases) return const PurchasesPage();
  if (section == AppSection.customers) return const CustomersPage();
  if (section == AppSection.accounts) return const AccountsHubPage();
  if (section == AppSection.expenses) return const ExpensesPage();
  if (section == AppSection.reports) return const ReportsHubPage();
  if (section == AppSection.settings) return const SettingsPage();
  if (section == AppSection.audit) return const AuditLogPage();
  final l10n = AppLocalizations.of(context);
  return SectionPlaceholder(
    icon: section.icon,
    title: section.label(l10n),
    subtitle: l10n.appSlogan,
  );
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: l10n.userLogout,
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
    );
  }
}