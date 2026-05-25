import 'package:cenko/app_theme.dart';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/auth_util.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/intro_provider.dart';
import 'package:cenko/shared/widgets/auth_locale_button.dart';
import 'package:cenko/shared/widgets/google_button.dart';
import 'package:cenko/shared/widgets/large_button.dart';
import 'package:cenko/shared/widgets/or_divider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider).signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
    } on AuthException catch (e) {
      setState(() => _error = authErrorMessage(e.message));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider).signInWithGoogle();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e.message));
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = l10n.authErrorGoogleSignInFailed);
      }
    } on Exception {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final colors = Theme.of(context).colorScheme;
    final minHeight = (size.height - 80).clamp(0.0, double.infinity);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: AuthLocaleButton()),
                const SizedBox(height: 16),
                Text(kAppName, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(l10n.catchPhrase, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 52),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.manrope(color: colors.onSurface, fontSize: 15),
                        decoration: InputDecoration(labelText: l10n.email),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: GoogleFonts.manrope(color: colors.onSurface, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: colors.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? l10n.enterYourPassword : null,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                    ),
                    child: Text(l10n.authForgotPassword, style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                LargeButton(label: l10n.signIn, onPressed: _loading ? null : _submit, loading: _loading),
                const SizedBox(height: 24),
                const OrDivider(),
                const SizedBox(height: 24),
                GoogleButton(onPressed: _loading ? null : _googleSignIn, loading: _loading),
                const SizedBox(height: 32),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.authDontHaveAccount, style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          l10n.authCreateOne,
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (kDebugMode)
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (!mounted) return;
                        ref.read(introductionShownProvider.notifier).state = false;
                        router.go('/onboarding');
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('[DEV] Reset onboarding'),
                      style: TextButton.styleFrom(foregroundColor: colors.error),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
