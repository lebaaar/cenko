import 'package:cenko/app_theme.dart';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/auth_util.dart';
import 'package:cenko/shared/widgets/google_button.dart';
import 'package:cenko/shared/widgets/large_button.dart';
import 'package:cenko/shared/widgets/or_divider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../shared/providers/auth_provider.dart';

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
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e.code));
    } on FirebaseException catch (e) {
      setState(
        () => _error = e.code == 'permission-denied' ? 'Account setup failed. Firestore access is not allowed for this user.' : e.message ?? e.code,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.code == 'permission-denied' ? 'Account setup failed. Firestore access is not allowed for this user.' : e.message ?? e.code,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),

                // Hero
                const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(appName, style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(catchPhrase, style: Theme.of(context).textTheme.bodyMedium),

                const SizedBox(height: 52),

                // Form
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
                        decoration: const InputDecoration(labelText: 'Email'),
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
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: colors.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                    ],
                  ),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                    ),
                    child: Text('Forgot password?', style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: Theme.of(context).colorScheme.error)),
                ],

                const SizedBox(height: 20),

                // CTAs
                LargeButton(label: 'Sign in', onPressed: _loading ? null : _submit, loading: _loading),
                const SizedBox(height: 24),
                const OrDivider(),
                const SizedBox(height: 24),
                GoogleButton(onPressed: _loading ? null : _googleSignIn, loading: _loading),

                const SizedBox(height: 32),

                // Register link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Don't have an account? ", style: GoogleFonts.manrope(fontSize: 13, color: colors.onSurfaceVariant)),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Create one',
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
      ),
    );
  }
}
