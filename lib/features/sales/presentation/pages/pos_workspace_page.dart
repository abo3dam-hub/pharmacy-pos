import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sections.dart';
import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/money/money.dart';
import '../../../../core/shortcuts/barcode_buffer.dart';
import '../../../../core/shortcuts/pos_shortcuts.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/pos_cart.dart';
import '../../domain/entities/pos_catalog_item.dart';
import '../../domain/entities/pos_customer.dart';
import '../../domain/entities/pos_invoice.dart';
import '../../domain/usecases/payment_calculator.dart';
import '../controllers/pos_workspace_controller.dart';
import '../controllers/pos_workspace_state.dart';

int? _tryParseMicros(String v) {
  try {
    return Money.parse(v).micros;
  } on FormatException {
    return null;
  }
}

/// §5 POS workspace — 10 customer tabs + a Return tab, each with its own
/// Riverpod state (independent carts), a 3-panel responsive layout and one
/// central keyboard shortcut set.
class PosWorkspacePage extends ConsumerStatefulWidget {
  const PosWorkspacePage({super.key});

  @override
  ConsumerState<PosWorkspacePage> createState() => _PosWorkspacePageState();
}

class _PosWorkspacePageState extends ConsumerState<PosWorkspacePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<FocusNode> _searchFocus = List.generate(
      kPosCustomerTabCount, (_) => FocusNode());
  final List<BarcodeBuffer> _buffers =
      List.generate(kPosCustomerTabCount, (_) => BarcodeBuffer());
  final Map<int, int> _selectedLineByTab = {};

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kPosTabCount, vsync: this);
    for (var i = 0; i < kPosCustomerTabCount; i++) {
      final buffer = _buffers[i];
      buffer.onBarcode = (code) => _onScanned(i, code);
    }
  }

  @override
  void dispose() {
    for (final f in _searchFocus) {
      f.dispose();
    }
    for (final b in _buffers) {
      b.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _onScanned(int tabIndex, String code) {
    if (!mounted) return;
    ref
        .read(posWorkspaceControllerProvider(tabIndex).notifier)
        .handleScannedBarcode(code);
  }

  PosWorkspaceController _notifier(int tab) =>
      ref.read(posWorkspaceControllerProvider(tab).notifier);

  Set<String> get _permissions =>
      ref.read(authControllerProvider).permissions;

  @override
  Widget build(BuildContext context) {
    final actions = <Type, Action<Intent>>{
      SearchFocusIntent: CallbackAction<SearchFocusIntent>(
        onInvoke: (_) {
          final tab = _tabController.index;
          if (tab < kPosCustomerTabCount) _requestSearchFocus(tab);
          return null;
        },
      ),
      ToggleUnitModeIntent: CallbackAction<ToggleUnitModeIntent>(
        onInvoke: (_) {
          final tab = _tabController.index;
          if (tab >= kPosCustomerTabCount) return null;
          final index = _selectedLineByTab[tab] ?? 0;
          _notifier(tab).toggleUnitMode(index);
          return null;
        },
      ),
      HoldBillIntent: CallbackAction<HoldBillIntent>(
        onInvoke: (_) {
          final tab = _tabController.index;
          if (tab < kPosCustomerTabCount) _notifier(tab).holdBill();
          return null;
        },
      ),
      CheckoutIntent: CallbackAction<CheckoutIntent>(
        onInvoke: (_) {
          final tab = _tabController.index;
          if (tab < kPosCustomerTabCount) _openPayment(tab);
          return null;
        },
      ),
      ShowAlternativesIntent: CallbackAction<ShowAlternativesIntent>(
        onInvoke: (_) => _showAlternatives(tabIndex: _tabController.index),
      ),
    };

    return Shortcuts(
      shortcuts: PosShortcuts.desktopMap,
      child: Actions(
        actions: actions,
        child: Scaffold(
          body: DefaultTabController(
            length: kPosTabCount,
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (var i = 0; i < kPosCustomerTabCount; i++)
                        Tab(text: _l10n.posCustomerTab(i + 1)),
                      Tab(text: _l10n.posReturnTab),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (var i = 0; i < kPosCustomerTabCount; i++)
                        _TabWorkspace(
                          tabIndex: i,
                          searchFocusNode: _searchFocus[i],
                          barcodeBuffer: _buffers[i],
                          onLineSelected: (lineIndex) =>
                              _selectedLineByTab[i] = lineIndex,
                        ),
                      _ReturnTab(
                        state: ref.watch(
                            posWorkspaceControllerProvider(kReturnTabIndex)),
                        notifier: _notifier(kReturnTabIndex),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _requestSearchFocus(int tab) {
    final node = _searchFocus[tab];
    if (tab != _tabController.index) _tabController.index = tab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      node.requestFocus();
    });
  }

  Future<void> _openPayment(int tab) async {
    final notifier = _notifier(tab);
    if (notifier.currentState.cart.isEmpty) {
      notifier.clearError();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_l10n.posCartItemEmpty)));
      return;
    }
    final done = await showPosPaymentSheet(
      context,
      state: notifier.currentState,
      onInputChanged: (method, cashMicros, cardMicros) => notifier
          .updatePaymentInputs(
              method: method,
              cashReceivedMicros: cashMicros,
              cardReceivedMicros: cardMicros),
      totals: notifier.totals,
    );
    if (done == true && mounted) {
      // The sheet already runs the checkout; outcomes surface as state.
    }
  }

  Future<void> _showAlternatives({required int tabIndex}) async {
    if (tabIndex >= kPosCustomerTabCount) return;
    final notifier = _notifier(tabIndex);
    final state = notifier.currentState;
    PosCatalogItem? item;
    if (_selectedLineByTab[tabIndex] != null &&
        _selectedLineByTab[tabIndex]! < state.cart.length) {
      item = state.cart[_selectedLineByTab[tabIndex]!].item;
    } else if (state.searchResults?.items.isNotEmpty ?? false) {
      item = state.searchResults!.items.first;
    }
    final picked = item;
    if (picked == null || !mounted) return;
    if (!_permissions.contains(Perm.viewAlternatives)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_l10n.authPermissionDenied)));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AlternativesDialog(
        item: picked,
        onPick: (alt) {
          Navigator.of(context).pop();
          notifier.addToCart(alt);
        },
      ),
    );
  }
}

/// One responsive tab body: two-panel on desktop/tablet (search | cart at
/// fraction), full-width search with a floating cart button on compact.
class _TabWorkspace extends ConsumerWidget {
  const _TabWorkspace({
    required this.tabIndex,
    required this.searchFocusNode,
    required this.barcodeBuffer,
    required this.onLineSelected,
  });

  final int tabIndex;
  final FocusNode searchFocusNode;
  final BarcodeBuffer barcodeBuffer;
  final ValueChanged<int> onLineSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(posWorkspaceControllerProvider(tabIndex));
    if (controller.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
        ref
            .read(posWorkspaceControllerProvider(tabIndex).notifier)
            .clearError();
      });
    }

    return AppResponsiveLayout(
      desktop: _PanelsRow(
        tabIndex: tabIndex,
        searchFocusNode: searchFocusNode,
        barcodeBuffer: barcodeBuffer,
        onLineSelected: onLineSelected,
      ),
      tablet: _PanelsRow(
        tabIndex: tabIndex,
        searchFocusNode: searchFocusNode,
        barcodeBuffer: barcodeBuffer,
        onLineSelected: onLineSelected,
      ),
      compact: _CompactLayout(
        tabIndex: tabIndex,
        searchFocusNode: searchFocusNode,
        barcodeBuffer: barcodeBuffer,
        onLineSelected: onLineSelected,
      ),
    );
  }
}

class _PanelsRow extends ConsumerWidget {
  const _PanelsRow({
    required this.tabIndex,
    required this.searchFocusNode,
    required this.barcodeBuffer,
    required this.onLineSelected,
  });

  final int tabIndex;
  final FocusNode searchFocusNode;
  final BarcodeBuffer barcodeBuffer;
  final ValueChanged<int> onLineSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parent `_TabWorkspace` watches the controller and rebuilds this subtree
    // on every state change; read (not watch) here is deliberate.
    final state = ref.read(posWorkspaceControllerProvider(tabIndex));
    final notifier =
        ref.read(posWorkspaceControllerProvider(tabIndex).notifier);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _SearchPanel(
              tabIndex: tabIndex,
              searchFocusNode: searchFocusNode,
              barcodeBuffer: barcodeBuffer,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            flex: 4,
            child: _CartPanel(
              tabIndex: tabIndex,
              state: state,
              notifier: notifier,
              onLineSelected: onLineSelected,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact layout (phones): the full cart interior as a draggable bottom sheet.
Future<void> showPosCartSheet(
  BuildContext context,
  PosWorkspaceState state,
  PosWorkspaceController notifier,
  ValueChanged<int> onLineSelected,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _CartPanel(
          tabIndex: state.tabIndex,
          state: state,
          notifier: notifier,
          onLineSelected: onLineSelected,
        ),
      ),
    ),
  );
}

class _CompactLayout extends ConsumerWidget {
  const _CompactLayout({
    required this.tabIndex,
    required this.searchFocusNode,
    required this.barcodeBuffer,
    required this.onLineSelected,
  });

  final int tabIndex;
  final FocusNode searchFocusNode;
  final BarcodeBuffer barcodeBuffer;
  final ValueChanged<int> onLineSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posWorkspaceControllerProvider(tabIndex));
    final notifier =
        ref.read(posWorkspaceControllerProvider(tabIndex).notifier);
    return Stack(
      children: [
        Positioned.fill(
          child: _SearchPanel(
            tabIndex: tabIndex,
            searchFocusNode: searchFocusNode,
            barcodeBuffer: barcodeBuffer,
          ),
        ),
        Positioned(
          left: AppSpacing.m,
          right: AppSpacing.m,
          bottom: AppSpacing.m,
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isEmptyCart
                        ? null
                        : () => showPosCartSheet(
                            context, state, notifier, onLineSelected),
                    icon: const Icon(Icons.shopping_cart),
                    label: Text('${state.cart.length} '
                        '· ${Money.fromUnits(notifier.totals.totalMicros).formatArabicDigits()}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search panel ────────────────────────────────────────────────────────

class _SearchPanel extends ConsumerStatefulWidget {
  const _SearchPanel({
    required this.tabIndex,
    required this.searchFocusNode,
    required this.barcodeBuffer,
  });

  final int tabIndex;
  final FocusNode searchFocusNode;
  final BarcodeBuffer barcodeBuffer;

  @override
  ConsumerState<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<_SearchPanel> {
  final TextEditingController _query = TextEditingController();
  String _lastText = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Scanner keystrokes arrive as fast appends — feed only the delta into the
    // shared BarcodeBuffer; manual edits reset it.
    if (value.length > _lastText.length && value.startsWith(_lastText)) {
      widget.barcodeBuffer.feedString(value.substring(_lastText.length));
    } else {
      widget.barcodeBuffer.reset();
    }
    _lastText = value;
    _debounce = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      ref
          .read(posWorkspaceControllerProvider(widget.tabIndex).notifier)
          .search(value);
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    // A hardware scanner terminates with Enter — complete the buffer.
    widget.barcodeBuffer.feed(widget.barcodeBuffer.terminator);
    ref
        .read(posWorkspaceControllerProvider(widget.tabIndex).notifier)
        .search(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(posWorkspaceControllerProvider(widget.tabIndex));
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              focusNode: widget.searchFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.posSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ProductList(
                      items: state.searchResults?.items ?? const [],
                      onAdd: (item) => ref
                          .read(posWorkspaceControllerProvider(
                                  widget.tabIndex)
                              .notifier)
                          .addToCart(item),
                      onLostSale: state.searchQuery.isNotEmpty &&
                              (state.searchResults?.items.isEmpty ?? true)
                          ? () => _showLostSaleDialog(l10n, state.searchQuery)
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLostSaleDialog(AppLocalizations l10n, String barcode) async {
    final draft = await showLostSaleDialog(context, barcode: barcode);
    if (draft == null || !mounted) return;
    final notifier =
        ref.read(posWorkspaceControllerProvider(widget.tabIndex).notifier);
    final ok = await notifier.captureLostSale(
      productName: draft.$1,
      quantity: draft.$2,
      actingUserId: ref.read(authControllerProvider).user?.id ?? '',
      permissions: ref.read(authControllerProvider).permissions,
      barcode: barcode,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('تم تسجيل الناقص')));
    }
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.items,
    required this.onAdd,
    this.onLostSale,
  });

  final List<PosCatalogItem> items;
  final ValueChanged<PosCatalogItem> onAdd;
  final VoidCallback? onLostSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: AppSpacing.m),
            Text(l10n.posNoResults),
            if (onLostSale != null) ...[
              const SizedBox(height: AppSpacing.m),
              OutlinedButton.icon(
                onPressed: onLostSale,
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(l10n.posLostSaleTitle),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final available = item.availableStockBase;
        final isOut = available <= 0;
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: isOut
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(
              isOut ? Icons.block : Icons.medication,
              size: 20,
            ),
          ),
          title: Text(item.tradeName, style: context.appTypography.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${item.scientificName}'
            '${(item.activeIngredient?.isNotEmpty ?? false) ? ' · ${item.activeIngredient}' : ''}'
            '${item.partialSaleConfigured ? ' · ${item.sellablePartUnitName ?? ''} ${item.sellablePartBaseQuantity}×${item.partsPerFullProduct} = ${item.unitsPerLarge}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.fromUnits(item.baseUnitPriceMicros).formatArabicDigits(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                isOut ? l10n.posOutOfStock : 'المتاح: $available',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOut
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
              ),
            ],
          ),
          enabled: !isOut,
          onTap: isOut ? null : () => onAdd(item),
        );
      },
    );
  }
}

// ── Cart panel ──────────────────────────────────────────────────────────

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel({
    required this.tabIndex,
    required this.state,
    required this.notifier,
    required this.onLineSelected,
  });

  final int tabIndex;
  final PosWorkspaceState state;
  final PosWorkspaceController notifier;
  final ValueChanged<int> onLineSelected;

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final totals = widget.notifier.totals;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CustomerHeader(state: state, notifier: widget.notifier),
            const SizedBox(height: AppSpacing.s),
            Expanded(
              child: state.cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_shopping_cart_outlined, size: 40),
                          const SizedBox(height: AppSpacing.s),
                          Text(l10n.posCartItemEmpty),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.cart.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final line = state.cart[index];
                        final unitLabel = _unitLabel(l10n, line);
                        return ListTile(
                          dense: true,
                          selected: true,
                          onTap: () => widget.onLineSelected(index),
                          title: Text(line.item.tradeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${_lineQty(line)} $unitLabel'
                            '${line.isRxLinked ? ' · وصفة' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    widget.notifier.updateQuantity(
                                        index, line.quantity - 1),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${line.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    widget.notifier.updateQuantity(
                                        index, line.quantity + 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => widget.notifier.removeLine(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.s),
            _TotalsView(totals: totals),
            const SizedBox(height: AppSpacing.s),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.cart.isEmpty
                        ? null
                        : () => _showHoldBillsSheet(context, widget.notifier),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.posHoldBill),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isEmptyCart
                        ? null
                        : () => showPosPaymentSheet(
                              context,
                              state: state,
                              onInputChanged: (method, cash, card) =>
                                  widget.notifier.updatePaymentInputs(
                                      method: method,
                                      cashReceivedMicros: cash,
                                      cardReceivedMicros: card),
                              totals: totals,
                            ),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.posPayButton),
                  ),
                ),
              ],
            ),
            if (widget.notifier.currentState.returnedLinesNote != null) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                widget.notifier.currentState.returnedLinesNote!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _unitLabel(AppLocalizations l10n, PosCartLine line) =>
      switch (line.unitMode) {
        PosLineUnitMode.largeUnit => l10n.posUnitBox,
        PosLineUnitMode.sellablePart => l10n.posUnitStrip,
        PosLineUnitMode.baseUnit => l10n.posUnitUnit,
      };

  int _lineQty(PosCartLine line) =>
      switch (line.unitMode) {
        PosLineUnitMode.sellablePart => line.quantity,
        _ => line.quantity,
      };

  Future<void> _showHoldBillsSheet(
      BuildContext context, PosWorkspaceController notifier) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _HoldBillsSheet(notifier: notifier),
    );
  }
}

class _TotalsView extends StatelessWidget {
  const _TotalsView({required this.totals});

  final PosCartTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _totalRow(l10n.posTotalLabel, totals.subtotalMicros, context),
        if (totals.discountTotalMicros > 0)
          _totalRow(l10n.commonDiscount, -totals.discountTotalMicros, context),
        if (totals.vatTotalMicros > 0)
          _totalRow(l10n.commonTax, totals.vatTotalMicros, context),
        Divider(color: Theme.of(context).dividerColor),
        _totalRow(
          l10n.posTotalLabel,
          totals.totalMicros,
          context,
          bold: true,
        ),
      ],
    );
  }

  Widget _totalRow(String label, int micros, BuildContext context,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyMedium),
          Text(
            Money.fromUnits(micros).formatArabicDigits(),
            style: bold
                ? const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CustomerHeader extends ConsumerWidget {
  const _CustomerHeader({required this.state, required this.notifier});

  final PosWorkspaceState state;
  final PosWorkspaceController notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customer = state.customer;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickCustomer(context, ref),
          icon: const Icon(Icons.person_outline),
          label: Text(customer == null
              ? l10n.posCustomerLabel
              : '${customer.name}'
                  '${customer.phone != null && customer.phone!.isNotEmpty ? ' · ${customer.phone}' : ''}'),
        ),
        if (customer != null) ...[
          ActionChip(
            avatar: const Icon(Icons.description_outlined),
            label: Text(state.activePrescription == null
                ? l10n.posPrescriptionLabel
                : 'Rx ${state.activePrescription!.prescriptionNumber}'),
            onPressed: () => _pickPrescription(context, ref),
          ),
          if (state.cart.any((l) => l.isRxLinked))
            IconButton(
              tooltip: 'تفريغ السلة',
              onPressed: notifier.clearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ],
    );
  }

  Future<void> _pickCustomer(BuildContext context, WidgetRef ref) async {
    final picked = await showCustomerPickerDialog(context);
    if (picked == null || !context.mounted) return;
    await notifier.selectCustomer(picked);
  }

  Future<void> _pickPrescription(BuildContext context, WidgetRef ref) async {
    final picked = await showPrescriptionPickerDialog(
      context,
      prescriptions: notifier.currentState.activePrescriptions,
    );
    if (picked == null || !context.mounted) return;
    notifier.selectPrescription(picked);
  }
}

// ── Payment / checkout sheet ────────────────────────────────────────────

/// The §11 payment panel as a modal sheet, shared by desktop & compact.
Future<bool?> showPosPaymentSheet(
  BuildContext context, {
  required PosWorkspaceState state,
  required PosCartTotals totals,
  required void Function(
          PosPaymentMethod method, int cashMicros, int cardMicros)
      onInputChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PaymentSheetBody(
      state: state,
      totals: totals,
      onInputChanged: onInputChanged,
    ),
  );
}

class _PaymentSheetBody extends ConsumerStatefulWidget {
  const _PaymentSheetBody({
    required this.state,
    required this.totals,
    required this.onInputChanged,
  });

  final PosWorkspaceState state;
  final PosCartTotals totals;
  final void Function(PosPaymentMethod, int, int) onInputChanged;

  @override
  ConsumerState<_PaymentSheetBody> createState() => _PaymentSheetBodyState();
}

class _PaymentSheetBodyState extends ConsumerState<_PaymentSheetBody> {
  final TextEditingController _cash = TextEditingController();
  final TextEditingController _card = TextEditingController();
  PosPaymentMethod _method = PosPaymentMethod.cash;
  String? _error;
  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _method = widget.state.paymentMethod;
  }

  @override
  void dispose() {
    _cash.dispose();
    _card.dispose();
    super.dispose();
  }

  int? get _cashMicros {
    final v = _cash.text.trim();
    if (v.isEmpty) return 0;
    final m = _tryParseMicros(v);
    return m;
  }

  int? get _cardMicros {
    final v = _card.text.trim();
    if (v.isEmpty) return 0;
    return _tryParseMicros(v);
  }

  void _reload() {
    setState(() {});
    widget.onInputChanged(_method, _cashMicros ?? 0, _cardMicros ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payment = const PaymentCalculator().calculate(
      totalMicros: widget.totals.totalMicros,
      method: _method,
      cashReceivedMicros: _cashMicros ?? 0,
      cardAmountMicros: _cardMicros ?? 0,
    );
    final canSubmit = payment.isValid && payment.fullyPaid;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        top: AppSpacing.s,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.posTotalLabel}: '
            '${Money.fromUnits(payment.totalMicros).formatArabicDigits()}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (payment.changeMicros > 0)
            Text(
              '${l10n.posChangeLabel}: '
              '${Money.fromUnits(payment.changeMicros).formatArabicDigits()}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: AppSpacing.m),
          SegmentedButton<PosPaymentMethod>(
            segments: const [
              ButtonSegment(
                value: PosPaymentMethod.cash,
                label: Text('نقدي'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: PosPaymentMethod.card,
                label: Text('بطاقة'),
                icon: Icon(Icons.credit_card),
              ),
              ButtonSegment(
                value: PosPaymentMethod.mixed,
                label: Text('مختلط'),
                icon: Icon(Icons.account_balance_wallet_outlined),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) {
              setState(() => _method = s.first);
              _reload();
            },
          ),
          const SizedBox(height: AppSpacing.m),
          if (_method == PosPaymentMethod.cash ||
              _method == PosPaymentMethod.mixed)
            TextField(
              controller: _cash,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.posCashReceived,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _reload(),
            ),
          if (_method == PosPaymentMethod.card ||
              _method == PosPaymentMethod.mixed) ...[
            const SizedBox(height: AppSpacing.s),
            TextField(
              controller: _card,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.posCardAmount,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _reload(),
            ),
          ],
          if (!canSubmit) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              _error ?? (payment.error ?? l10n.posInvalidPayment),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.posPayButton),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final notifier = ref.read(posWorkspaceControllerProvider(widget.state.tabIndex).notifier);
    setState(() {
      _error = null;
    });
    final success = await _completeCheckout(notifier);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = notifier.currentState.errorMessage ?? l10n.posInvalidPayment);
    }
  }

  Future<bool> _completeCheckout(PosWorkspaceController notifier) async {
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return false;
    final outcome = await notifier.checkout(
      actingUserId: userId,
      permissions: ref.read(authControllerProvider).permissions,
    );
    if (outcome == null) return false;
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _ReceiptDialog(invoice: outcome.invoice),
      );
    }
    notifier.dismissLastSale();
    return true;
  }
}

// ── Shared dialogs ──────────────────────────────────────────────────────

class _ReceiptDialog extends StatelessWidget {
  const _ReceiptDialog({required this.invoice});

  final PosInvoiceView invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.receipt_long),
          const SizedBox(width: AppSpacing.s),
          Text(l10n.posReceiptSummaryTitle),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.posSaleNumber}: ${invoice.invoiceNumber}'),
              Text('${l10n.posSaleDate}: ${_formatTs(invoice.createdAt)}'),
              const Divider(),
              for (final line in invoice.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${line.itemName} × ${line.quantityBaseSigned}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(Money.fromUnits(line.lineTotalMicros)
                          .formatArabicDigits()),
                    ],
                  ),
                ),
              const Divider(),
              _row(l10n.posTotalLabel, invoice.totalMicros, bold: true),
              _row(l10n.commonPaid, invoice.paidMicros),
              _row(l10n.commonChange, invoice.changeMicros),
              const Divider(),
              Text(
                'فرع الصيدلية · شكراً لتعاملكم معنا',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              context.push('/${AppSection.sale.path}/invoice/${invoice.id}'),
          icon: const Icon(Icons.article_outlined),
          label: Text(l10n.posInvoiceTitle),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }

  Widget _row(String label, int micros, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
            Text(
              Money.fromUnits(micros).formatArabicDigits(),
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
            ),
          ],
        ),
      );

  String _formatTs(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

Future<(String, int)?> showLostSaleDialog(
  BuildContext context, {
  required String barcode,
}) async {
  final name = TextEditingController(text: barcode.trim());
  final qty = TextEditingController(text: '1');
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<(String, int)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.posLostSaleTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: 'اسم/مواصفة المنتج'),
          ),
          const SizedBox(height: AppSpacing.s),
          TextField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'الكمية المطلوبة'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            ctx,
          ).pop((qty.text.trim().isEmpty ? '1' : qty.text.trim(),
              name.text.trim().isEmpty ? barcode : name.text.trim())),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  );
  name.dispose();
  qty.dispose();
  return result;
}

class _HoldBillsSheet extends ConsumerWidget {
  const _HoldBillsSheet({required this.notifier});

  final PosWorkspaceController notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final held = notifier.currentState.heldBills;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: held.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: Text(l10n.posHoldBillEmpty)),
              )
            : ListView.separated(
                itemCount: held.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(held[index].label),
                  subtitle: Text(
                    '${held[index].customerName ?? ''} · '
                    '${held[index].cart.length} صنف',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => notifier.deleteHeldBill(index),
                      ),
                      FilledButton(
                        onPressed: () {
                          notifier.restoreHeldBill(index);
                          Navigator.of(context).pop();
                        },
                        child: Text('استرجاع'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _AlternativesDialog extends ConsumerWidget {
  const _AlternativesDialog({required this.item, required this.onPick});

  final PosCatalogItem item;
  final ValueChanged<PosCatalogItem> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('البدائل المقترحة لـ ${item.tradeName}'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<List<PosCatalogItem>>(
          future: ref
              .read(salesRepositoryProvider)
              .smartAlternatives(item),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snapshot.data ?? const <PosCatalogItem>[];
            if (list.isEmpty) {
              return const Center(child: Text('لا توجد بدائل متاحة حالياً'));
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final alt = list[index];
                return ListTile(
                  title: Text(alt.tradeName),
                  subtitle: Text('${alt.scientificName} · متاح: '
                      '${alt.availableStockBase}'),
                  trailing: Text(Money.fromUnits(alt.baseUnitPriceMicros)
                      .formatArabicDigits()),
                  onTap: () => onPick(alt),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

// ── Customer & prescription pickers ─────────────────────────────────────

Future<PosCustomer?> showCustomerPickerDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<PosCustomer>(
    context: context,
    builder: (_) => const _CustomerPickerDialog(),
    barrierLabel: l10n.posCustomerLabel,
  );
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  const _CustomerPickerDialog();

  @override
  ConsumerState<_CustomerPickerDialog> createState() =>
      _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  final TextEditingController _query = TextEditingController();
  static const int _limit = 20;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.posCustomerLabel),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'ابحث عن عميل بالاسم أو الهاتف',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: FutureBuilder<List<PosCustomer>>(
                future: ref.read(salesRepositoryProvider).findCustomers(
                      _query.text.trim(),
                      limit: _limit,
                    ),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const <PosCustomer>[];
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (list.isEmpty) {
                    return Center(child: Text(l10n.posNoResults));
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(list[index].name),
                      subtitle: Text(list[index].phone ?? ''),
                      onTap: () => Navigator.of(context).pop(list[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

Future<String?> showPrescriptionPickerDialog(
  BuildContext context, {
  required List<PosRxSummary> prescriptions,
}) async {
  if (prescriptions.isEmpty) {
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('اختر الوصفة النشطة'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: prescriptions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final rx = prescriptions[index];
            return ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(rx.prescriptionNumber),
              subtitle: Text(
                '${rx.patientName} · ${rx.items.length} صنف',
              ),
              onTap: () => Navigator.of(ctx).pop(rx.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(AppLocalizations.of(ctx).commonClose),
        ),
      ],
    ),
  );
}

// ── Return tab ──────────────────────────────────────────────────────────

class _ReturnTab extends ConsumerWidget {
  const _ReturnTab({required this.state, required this.notifier});

  final PosWorkspaceState state;
  final PosWorkspaceController notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: l10n.posReturnSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (v) => notifier.searchReturnInvoices(v),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Expanded(
                      child: state.returnLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _InvoiceDropList(
                              invoices:
                                  state.returnSearchResults?.items ?? const [],
                              selectedId: state.selectedReturnInvoice?.id,
                              onSelect: notifier.selectReturnInvoice,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: _ReturnDetails(
                  state: state,
                  notifier: notifier,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceDropList extends ConsumerWidget {
  const _InvoiceDropList({
    required this.invoices,
    required this.selectedId,
    required this.onSelect,
  });

  final List<PosInvoiceView> invoices;
  final String? selectedId;
  final ValueChanged<PosInvoiceView> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 40),
            const SizedBox(height: AppSpacing.s),
            Text(l10n.posNoInvoices),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final selected = invoice.id == selectedId;
        return ListTile(
          selected: selected,
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          leading: const Icon(Icons.receipt_outlined),
          title: Text(invoice.invoiceNumber,
              style: context.appTypography.invoiceNumber),
          subtitle: Text(
            '${invoice.customerName} · '
            '${Money.fromUnits(invoice.totalMicros).formatArabicDigits()}',
          ),
          trailing: invoice.isReturnable
              ? const Icon(Icons.verified_outlined, size: 18)
              : null,
          enabled: invoice.isReturnable,
          onTap: () => onSelect(invoice),
        );
      },
    );
  }
}

class _ReturnDetails extends ConsumerStatefulWidget {
  const _ReturnDetails({required this.state, required this.notifier});

  final PosWorkspaceState state;
  final PosWorkspaceController notifier;

  @override
  ConsumerState<_ReturnDetails> createState() => _ReturnDetailsState();
}

class _ReturnDetailsState extends ConsumerState<_ReturnDetails> {
  final TextEditingController _reason = TextEditingController();
  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invoice = widget.state.selectedReturnInvoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          invoice == null
              ? 'اختر فاتورة من القائمة وحدد الكميات المرتجعة'
              : '${l10n.posInvoiceTitle} · ${invoice.invoiceNumber}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.m),
        if (widget.state.returnedLinesNote != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Text(widget.state.returnedLinesNote!),
            ),
          ),
        const SizedBox(height: AppSpacing.m),
        if (invoice != null)
          Expanded(
            child: ListView.separated(
              itemCount: invoice.lines.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final line = invoice.lines[index];
                final returnable = line.returnableBase;
                final qty = widget.state.returnQuantityByLine[line.id] ?? 0;
                return ListTile(
                  dense: true,
                  title: Text(line.itemName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${l10n.posLineReturnable}: $returnable · '
                    '${Money.fromUnits(line.lineTotalMicros).formatArabicDigits()}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: returnable <= 0
                            ? null
                            : () => widget.notifier
                                .setReturnLineQty(line.id, (qty - 1).clamp(0, returnable)),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: qty >= returnable
                            ? null
                            : () => widget.notifier
                                .setReturnLineQty(line.id, qty + 1),
                      ),
                    ],
                  ),
                  onTap: () {},
                );
              },
            ),
          ),
        if (invoice != null) ...[
          const SizedBox(height: AppSpacing.s),
          TextField(
            controller: _reason,
            decoration: InputDecoration(
              labelText: l10n.posReturnReason,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          FilledButton.icon(
            onPressed: () => _submit(),
            icon: const Icon(Icons.swap_horiz),
            label: Text(l10n.posReturnButton),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    final notifier = widget.notifier;
    final permissions = ref.read(authControllerProvider).permissions;
    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) return;
    final ok = await notifier.submitReturn(
      actingUserId: userId,
      permissions: permissions,
      reason: _reason.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? l10n.posReturnSuccess : (notifier.currentState.errorMessage ?? l10n.posInvalidPayment)),
      ));
    _reason.clear();
    notifier.clearError();
  }
}