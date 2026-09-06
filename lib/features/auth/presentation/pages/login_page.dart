import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/auth_controller.dart';

/// Authentication entry point (§16 U1).
///
/// Arabic-first, keyboard friendly (submit on Enter), shows a friendly
/// localized error for invalid credentials / inactive accounts and never
/// echoes passwords. Stays inside the design system — no ad-hoc styling.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _attempted = true;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(_username.text, _password.text);
    // Router refresh (stream listener) navigates away on success; nothing
    // else to do here — keep password field state clean.
    _password.clear();
    if (!ok && mounted) {
      setState(() {});
    }
  }

  String? _errorMessage(AppLocalizations l10n, AuthState state) {
    if (!_attempted) return null;
    if (state.error == AuthError.inactive) return l10n.loginUserInactive;
    return l10n.loginFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = context.appTypography;
    final submitting = ref.watch(authControllerProvider.select((s) => s.submitting));
    final errorText =
        _errorMessage(l10n, ref.watch(authControllerProvider));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.local_pharmacy_outlined,
                      size: 72,
                      color: AppColors.primarySeed,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: typography.pageTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.loginWelcome,
                      textAlign: TextAlign.center,
                      style: typography.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.loginUsername,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? l10n.userRequiredField
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submitting ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.loginPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? l10n.userRequiredField
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.l),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Text(
                          errorText,
                          textAlign: TextAlign.center,
                          style: typography.bodySecondary
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: AppSpacing.m,
                              width: AppSpacing.m,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.loginButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}