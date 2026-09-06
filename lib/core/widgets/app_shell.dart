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
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(AppSection section) {
    setState(() => _index = AppSection.values.indexOf(section));
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = AppSection.values;
    final selected = sections[_index];
    final layout = AppLayout.of(context);
    final compact = layout == AppLayout.compact;

    final page = _SectionPlaceholder(
      icon: selected.icon,
      subtitle: l10n.appSlogan,
      title: selected.label(l10n),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label(l10n)),
        // Future hosts: global search, notifications, user area (§11).
        actions: const [],
      ),
      drawer: compact ? _AppDrawer(selected: selected, onSelect: _select) : null,
      body: SafeArea(
        child: compact
            ? page
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    labelType: layout == AppLayout.desktop
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                    onDestinationSelected: (i) =>
                        setState(() => _index = i),
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

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.selected, required this.onSelect});

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
/// phases — keeps the shell navigable and testable today.
class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder({
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