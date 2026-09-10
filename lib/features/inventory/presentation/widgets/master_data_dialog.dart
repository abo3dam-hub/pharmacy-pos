import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/database/app_database.dart';
import '../../domain/repositories/inventory_repository.dart';

enum MasterDataKind { category, manufacturer, unit, activeIngredient, indication }

/// Master-data form result.
class MasterDataFormResult {
  const MasterDataFormResult(this.draft);

  final MasterDataDraft draft;
}

/// Generic create/edit dialog for categories, manufacturers and units (§4.1,
/// §4.3, §4.5).
Future<MasterDataFormResult?> showMasterDataFormDialog(
  BuildContext context, {
  required MasterDataKind kind,
  required String title,
  MasterDataDraft? initial,
  List<CategoryRow> categories = const [],
}) async {
  final result = await showDialog<MasterDataFormResult>(
    context: context,
    builder: (_) => _MasterDataFormDialog(
      kind: kind,
      title: title,
      initial: initial,
      categories: categories,
    ),
  );
  return result;
}

class _MasterDataFormDialog extends StatefulWidget {
  const _MasterDataFormDialog({
    required this.kind,
    required this.title,
    this.initial,
    this.categories = const [],
  });

  final MasterDataKind kind;
  final String title;
  final MasterDataDraft? initial;
  final List<CategoryRow> categories;

  @override
  State<_MasterDataFormDialog> createState() => _MasterDataFormDialogState();
}

class _MasterDataFormDialogState extends State<_MasterDataFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final MasterDataDraft _initial;
  final _name = TextEditingController();
  final _nameEn = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _abbreviation = TextEditingController();
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _initial = widget.initial ?? const MasterDataDraft(name: '');
    _name.text = _initial.name;
    _nameEn.text = _initial.nameEn ?? '';
    _description.text = _initial.description ?? '';
    _country.text = _initial.country ?? '';
    _phone.text = _initial.phone ?? '';
    _website.text = _initial.website ?? '';
    _abbreviation.text = _initial.abbreviation ?? '';
    _categoryId = _initial.categoryId ??
        (widget.categories.isEmpty ? null : widget.categories.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _description.dispose();
    _country.dispose();
    _phone.dispose();
    _website.dispose();
    _abbreviation.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.inventoryRequiredName)));
      return;
    }
    Navigator.of(context).pop(MasterDataFormResult(
      MasterDataDraft(
        name: _name.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        categoryId: _categoryId,
        country: _country.text.trim().isEmpty ? null : _country.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        website: _website.text.trim().isEmpty ? null : _website.text.trim(),
        abbreviation:
            _abbreviation.text.trim().isEmpty ? null : _abbreviation.text.trim(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showManufacturerFields = widget.kind == MasterDataKind.manufacturer;
    final showAbbreviation = widget.kind == MasterDataKind.unit;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: widget.kind == MasterDataKind.manufacturer
                        ? l10n.manufacturerName
                        : widget.kind == MasterDataKind.unit
                            ? l10n.unitName
                            : widget.kind == MasterDataKind.activeIngredient
                                ? l10n.activeIngredientName
                                : widget.kind == MasterDataKind.indication
                                    ? l10n.indicationName
                                    : l10n.categoryName,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.inventoryRequiredName
                      : null,
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  controller: _nameEn,
                  decoration: InputDecoration(
                    labelText: l10n.masterDataNameEn,
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                if (showAbbreviation) ...[
                  TextFormField(
                    controller: _abbreviation,
                    decoration: InputDecoration(labelText: l10n.unitAbbreviation),
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],
                if (showManufacturerFields) ...[
                  TextFormField(
                    controller: _country,
                    decoration: InputDecoration(labelText: l10n.manufacturerCountry),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: l10n.userPhone),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    controller: _website,
                    decoration: InputDecoration(labelText: l10n.manufacturerWebsite),
                  ),
                  const SizedBox(height: AppSpacing.m),
                ],
                TextFormField(
                  controller: _description,
                  decoration: InputDecoration(labelText: l10n.userNotes),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}