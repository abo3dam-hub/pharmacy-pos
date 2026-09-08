import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/settings_controller.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/entities/currency_options.dart';

/// Phase 12 Application Settings page (الإعدادات): Business Name, Tax rate and
/// Currency. Values persist through the settings use case + repository into
/// `app_settings` and survive relaunch. Editing requires `settings.edit`;
/// users with only `settings.view` see a read-only form.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessName = TextEditingController();
  final _taxController = TextEditingController();
  String? _currencyCode;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  bool get _canEdit =>
      ref.read(authControllerProvider).permissions.contains(Perm.settingsEdit);
  String? get _actingUserId => ref.read(authControllerProvider).user?.id;
  String? get _actingRoleId => ref.read(authControllerProvider).actingRoleId;

  Future<void> _load() async {
    await ref.read(settingsControllerProvider.notifier).load(
          actingRoleId: _actingRoleId,
        );
    final settings = ref.read(settingsControllerProvider).settings;
    _apply(settings);
  }

  void _apply(AppSettings? settings) {
    if (settings == null) return;
    _businessName.text = settings.businessName;
    _taxController.text = _taxText(settings.taxRate.basisPoints);
    _currencyCode = settings.currencyCode;
    if (mounted) setState(() {});
  }

  /// Formats basis points as a decimal percent, e.g. `1500` → `"15"`.
  static String _taxText(int basisPoints) {
    if (basisPoints % 100 == 0) return '${basisPoints ~/ 100}';
    final major = basisPoints ~/ 100;
    final minor = (basisPoints % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }

  static int _parseTax(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    final parts = trimmed.split('.');
    final major = int.tryParse(parts[0]);
    if (parts.length == 1) return (major ?? 0) * 100;
    final minorRaw = parts[1];
    final minor = int.tryParse(minorRaw) ?? 0;
    final scaled = minorRaw.length == 1 ? minor * 10 : minor;
    return (major ?? 0) * 100 + scaled;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final failure = await ref.read(settingsControllerProvider.notifier).save(
          draft: AppSettingsDraft(
            businessName: _businessName.text.trim(),
            taxRateBasisPoints: _parseTax(_taxController.text),
            currencyCode: _currencyCode ?? kSupportedCurrencies.first.code,
          ),
          actingUserId: _actingUserId,
          actingRoleId: _actingRoleId,
        );
    if (!mounted) return;
    if (failure == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.settingsSavedMessage)));
    } else {
      _showFailure(failure);
    }
  }

  void _showFailure(Failure failure) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      UnauthorizedFailure() => l10n.authPermissionDenied,
      ValidationFailure() => failure.message,
      _ => l10n.authSaveError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(settingsControllerProvider);
    final typography = Theme.of(context).textTheme;

    return LoadingOverlay(
      visible: state.status == SettingsStatus.loading,
      label: l10n.commonLoading,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.settingsGeneralTitle,
                        style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      controller: _businessName,
                      enabled: _canEdit,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.settingsBusinessName,
                        helperText: l10n.settingsBusinessNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? l10n.settingsBusinessNameRequired
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TextFormField(
                      controller: _taxController,
                      enabled: _canEdit,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.settingsTaxRate,
                        helperText: l10n.settingsTaxRateHint,
                        suffixText: '%',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = _parseTax(v ?? '');
                        if (value < 0 || value > 10000) {
                          return l10n.settingsTaxInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.l),
                    DropdownButtonFormField<String>(
                      initialValue: _currencyCode,
                      items: [
                        for (final currency in kSupportedCurrencies)
                          DropdownMenuItem(
                            value: currency.code,
                            child: Text(
                              '${currency.code} — ${currency.arabicName}',
                            ),
                          ),
                      ],
                      onChanged: _canEdit
                          ? (v) => setState(() => _currencyCode = v)
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.settingsCurrency,
                        helperText: l10n.settingsCurrencyHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_canEdit) ...[
                      const SizedBox(height: AppSpacing.l),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(l10n.commonSave),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}