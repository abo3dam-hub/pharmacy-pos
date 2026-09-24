import 'package:flutter/material.dart';

/// A combobox-style multi-select dropdown with search and inline "add new",
/// used by the product form for master-data pickers (indications, active
/// ingredients, suppliers, …) so long master lists no longer render every
/// option as chips inside the dialog.
///
/// Fully controlled: the parent passes [selectedIds] and receives
/// [onChanged]. Tapping the field opens the searchable option list; each row
/// carries a checkbox. When [onAddNew] is set, a trailing "add new" row
/// creates a master-data value inline and auto-selects it.
class SearchableMultiSelectField<T> extends StatefulWidget {
  const SearchableMultiSelectField({
    super.key,
    required this.selectedIds,
    required this.items,
    required this.idOf,
    required this.nameOf,
    required this.onChanged,
    this.onAddNew,
    this.addNewLabel,
    this.label,
    this.searchHint,
    this.width,
    this.maxListHeight = 240,
  });

  final Set<String> selectedIds;
  final List<T> items;
  final String Function(T) idOf;
  final String Function(T) nameOf;
  final ValueChanged<Set<String>> onChanged;
  final Future<T?> Function(String name)? onAddNew;
  final String? addNewLabel;
  final String? label;
  final String? searchHint;
  final double? width;
  final double maxListHeight;

  @override
  State<SearchableMultiSelectField<T>> createState() =>
      _SearchableMultiSelectFieldState<T>();
}

class _SearchableMultiSelectFieldState<T>
    extends State<SearchableMultiSelectField<T>> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  bool _pointerDown = false;
  bool _adding = false;

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  T? _itemById(String id) {
    for (final item in widget.items) {
      if (widget.idOf(item) == id) return item;
    }
    return null;
  }

  List<T> _filtered() {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final item in widget.items)
        if (query.isEmpty || widget.nameOf(item).toLowerCase().contains(query))
          item,
    ];
  }

  void _toggle(String id) {
    final next = Set<String>.of(widget.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    widget.onChanged(next);
  }

  Future<void> _addNew() async {
    final name = _search.text.trim();
    if (name.isEmpty || widget.onAddNew == null || _adding) return;
    setState(() => _adding = true);
    try {
      final created = await widget.onAddNew!(name);
      if (created != null && mounted) {
        final next = Set<String>.of(widget.selectedIds)
          ..add(widget.idOf(created));
        widget.onChanged(next);
        _search.clear();
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered();
    final query = _search.text.trim();
    final exactMatch = filtered.any(
      (i) => widget.nameOf(i).trim().toLowerCase() == query.toLowerCase(),
    );
    final showAddNew =
        widget.onAddNew != null && query.isNotEmpty && !exactMatch;

    return Listener(
      onPointerDown: (_) => _pointerDown = true,
      onPointerUp: (_) => _pointerDown = false,
      onPointerCancel: (_) => _pointerDown = false,
      child: SizedBox(
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected values as removable chips.
            if (widget.selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in widget.selectedIds)
                      Chip(
                        label: Text(
                          _itemById(id) == null ? id : widget.nameOf(_itemById(id) as T),
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _toggle(id),
                      ),
                  ],
                ),
              ),
            TextField(
              controller: _search,
              focusNode: _focus,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.searchHint,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.selectedIds.isNotEmpty)
                      Text(
                        '${widget.selectedIds.length}',
                        style: theme.textTheme.labelSmall,
                      ),
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
              onChanged: (_) => setState(() {
                if (!_open) _open = true;
              }),
              onTap: () {
                if (!_open) setState(() => _open = true);
              },
              onEditingComplete: () {
                if (!_pointerDown) setState(() => _open = false);
              },
            ),
            if (_open)
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                color: theme.colorScheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxListHeight),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      if (filtered.isEmpty && !showAddNew)
                        const ListTile(
                          dense: true,
                          title: Text('—'),
                        ),
                      for (final item in filtered)
                        CheckboxListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(
                            widget.nameOf(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                          value: widget.selectedIds
                              .contains(widget.idOf(item)),
                          onChanged: (_) => _toggle(widget.idOf(item)),
                        ),
                      if (showAddNew)
                        ListTile(
                          dense: true,
                          leading: _adding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_circle_outline, size: 18),
                          title: Text(
                            '${widget.addNewLabel ?? '+'} "$query"',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: _addNew,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
