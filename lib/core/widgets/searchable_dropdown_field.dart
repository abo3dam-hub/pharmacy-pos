import 'package:flutter/material.dart';

/// A combobox-style dropdown whose options can be filtered by typing, used by
/// the product form for master-data lookups (§5). Unlike
/// `DropdownButtonFormField` it is fully controlled: the parent passes `value`
/// and the field reflects external changes on rebuild (needed when a new
/// master-data row is created inline and auto-selected).
class SearchableDropdownField<T> extends StatefulWidget {
  const SearchableDropdownField({
    super.key,
    this.value,
    required this.items,
    required this.idOf,
    required this.nameOf,
    this.onChanged,
    this.label,
    this.width,
    this.maxListHeight = 200,
  });

  final String? value;
  final List<T> items;
  final String Function(T) idOf;
  final String Function(T) nameOf;
  final ValueChanged<String?>? onChanged;
  final String? label;
  final double? width;
  final double maxListHeight;

  @override
  State<SearchableDropdownField<T>> createState() =>
      _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T>
    extends State<SearchableDropdownField<T>> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late String? _selectedId;
  bool _open = false;

  /// True while a pointer is pressed anywhere inside the dropdown subtree.
  /// Closing on focus loss must never happen while the pointer is down,
  /// otherwise the focus change triggered by a row's pointer-down is processed
  /// before the row's tap-up completes — the list is unmounted mid-tap and the
  /// selection ("the item you tapped") is lost. See the regression test
  /// `test/searchable_dropdown_field_test.dart`.
  bool _pointerDown = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.value;
    _syncTextFromValue();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SearchableDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _selectedId) {
      _selectedId = widget.value;
      _syncTextFromValue();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _syncTextFromValue() {
    final selected = _itemById(_selectedId);
    _text.text = selected == null ? '' : widget.nameOf(selected);
  }

  T? _itemById(String? id) {
    if (id == null) return null;
    for (final item in widget.items) {
      if (widget.idOf(item) == id) return item;
    }
    return null;
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus && _open && !_pointerDown) {
      setState(() {
        _open = false;
        _syncTextFromValue();
      });
    }
  }

  void _select(T item) {
    setState(() {
      _selectedId = widget.idOf(item);
      _text.text = widget.nameOf(item);
      _open = false;
    });
    widget.onChanged?.call(_selectedId);
    _focus.unfocus();
  }

  List<T> _filtered() {
    final query = _text.text.trim().toLowerCase();
    final matching = [
      for (final item in widget.items)
        if (query.isEmpty || widget.nameOf(item).toLowerCase().contains(query))
          item,
    ];
    final selected = _itemById(_selectedId);
    if (selected != null &&
        matching.every((i) => widget.idOf(i) != widget.idOf(selected))) {
      return [selected, ...matching];
    }
    return matching;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
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
            TextField(
              controller: _text,
              focusNode: _focus,
              decoration: InputDecoration(
                labelText: widget.label,
                isDense: true,
                suffixIcon: Icon(
                  _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
              ),
              onChanged: (_) => setState(() => _open = true),
              onTap: () => setState(() => _open = true),
            ),
            if (_open && filtered.isNotEmpty)
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.maxListHeight),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in filtered)
                        ListTile(
                          dense: true,
                          selected: widget.idOf(item) == _selectedId,
                          title: Text(
                            widget.nameOf(item),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _select(item),
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