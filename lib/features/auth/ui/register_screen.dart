import 'package:cenko/app_theme.dart';
import 'package:cenko/core/utils/auth_util.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/widgets/google_button.dart';
import 'package:cenko/shared/widgets/large_button.dart';
import 'package:cenko/shared/widgets/or_divider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException, GoogleSignInExceptionCode;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e.code));
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => _error = 'Google Sign-In failed: ${e.code.name}');
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(() => _error = l10n.mustAgreeToTerms);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider).registerWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text, _nameCtrl.text.trim());
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(leading: const BackButton(), backgroundColor: colors.surface),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              Text(l10n.registerTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(l10n.registerSubtitle, style: Theme.of(context).textTheme.bodyMedium),

              const SizedBox(height: 25),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.manrope(color: colors.onSurface, fontSize: 15),
                      decoration: InputDecoration(labelText: l10n.fullName),
                      validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterYourName : null,
                    ),
                    const SizedBox(height: 14),
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
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.manrope(color: colors.onSurface, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: colors.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? l10n.passwordMin6Chars : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(l10n),
                      style: GoogleFonts.manrope(color: colors.onSurface, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: l10n.confirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: colors.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passwordCtrl.text ? l10n.passwordsDontMatch : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(value: _agreedToTerms, onChanged: (value) => setState(() => _agreedToTerms = value ?? false)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(l10n.iAgreeToThe, style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                                  GestureDetector(
                                    onTap: () => context.push('/legal'),
                                    child: Text(
                                      l10n.termsAndConditions,
                                      style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: colors.error))],

              const SizedBox(height: 32),

              LargeButton(label: l10n.registerTitle, onPressed: _loading || !_agreedToTerms ? null : () => _submit(l10n), loading: _loading),
              const SizedBox(height: 16),
              const OrDivider(),
              const SizedBox(height: 16),
              GoogleButton(onPressed: _loading ? null : _googleSignIn, loading: _loading),

              const SizedBox(height: 32),

              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.authAlreadyHaveAccount, style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        l10n.signIn,
                        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
