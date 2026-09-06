import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_sections.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Application shell — the navigation + content frame reused by every module.
///
/// Foundation only (§11): hosts `NavigationRail`/`AppDrawer`, a top bar with
/// the current section title, and the main content area. Future slots — global
/// search (F1), notifications and the user area — attach through the top-bar
/// `actions`. No business functionality is implemented here.
///
/// Two usage modes (backward compatible):
///   * stateless routing — pass [selectedSection], [child],
///     [onSectionSelected] (used by GoRouter's shell route); navigation taps
///     call back so the router moves pages.
///   * stateful foundation — no extra args; taps swap the internal placeholder.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.selectedSection = AppSection.dashboard,
    this.child,
    this.onSectionSelected,
    this.appBarActions = const [],
  });

  /// Section currently shown by the surrounding router (defaults in
  /// standalone mode). Kept in sync with the rail/drawer highlight.
  final AppSection selectedSection;

  /// Page body rendered inside the shell when routing is active.
  final Widget? child;

  /// Invoked when the user picks a destination in routing mode (e.g.
  /// `context.go`); absent → internal placeholder selection.
  final ValueChanged<AppSection>? onSectionSelected;

  /// Extra top-bar actions (e.g. the auth feature's logout button).
  final List<Widget> appBarActions;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  bool get _routed => widget.onSectionSelected != null;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routed) {
      _index = AppSection.values.indexOf(widget.selectedSection);
    }
  }

  void _select(AppSection section) {
    if (_routed) {
      widget.onSectionSelected?.call(section);
      return;
    }
    setState(() => _index = AppSection.values.indexOf(section));
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = AppSection.values;
    final selected = _routed ? widget.selectedSection : sections[_index];
    final layout = AppLayout.of(context);
    final compact = layout == AppLayout.compact;

    final page = widget.child ??
        SectionPlaceholder(
          icon: selected.icon,
          subtitle: l10n.appSlogan,
          title: selected.label(l10n),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label(l10n)),
        actions: widget.appBarActions,
      ),
      drawer: compact ? AppDrawer(selected: selected, onSelect: _select) : null,
      body: SafeArea(
        child: compact
            ? page
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: AppSection.values.indexOf(selected),
                    labelType: layout == AppLayout.desktop
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                    onDestinationSelected: (i) => _select(sections[i]),
                    destinations: [
                      for (final section in sections)
                        NavigationRailDestination(
                          icon: Icon(section.icon),
                          selectedIcon: Icon(section.icon),
                          label: Text(section.label(l10n)),
                        ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  Expanded(child: page),
                ],
              ),
      ),
    );
  }
}

/// Side navigation shown on compact (<600) layouts.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NavigationDrawer(
      selectedIndex: AppSection.values.indexOf(selected),
      onDestinationSelected: (i) => onSelect(AppSection.values[i]),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.m,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Text(l10n.appTitle, style: context.appTypography.sectionTitle),
        ),
        for (final section in AppSection.values)
          NavigationDrawerDestination(
            icon: Icon(section.icon),
            label: Text(section.label(l10n)),
          ),
      ],
    );
  }
}

/// Transient placeholder rendered until the real module pages land in later
/// phases. Public so module pages can reuse it for empty states.
class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({
    super.key,
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
    final typography = context.appTypography;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 88, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.l),
          Text(title, style: typography.pageTitle),
          const SizedBox(height: AppSpacing.s),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: typography.bodySecondary,
          ),
        ],
      ),
    );
  }
}