import 'package:cenko/app_theme.dart';
import 'package:cenko/core/utils/auth_util.dart';
import 'package:cenko/shared/widgets/large_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider).sendPasswordResetEmail(_emailCtrl.text.trim());
      setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = authErrorMessage(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(leading: const BackButton(), backgroundColor: colors.surface),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _sent
              ? _ConfirmationView(email: _emailCtrl.text.trim())
              : _FormView(formKey: _formKey, emailCtrl: _emailCtrl, loading: _loading, error: _error, onSubmit: _submit),
        ),
      ),
    );
  }
}

// Form view — enter email

class _FormView extends StatelessWidget {
  const _FormView({required this.formKey, required this.emailCtrl, required this.loading, required this.error, required this.onSubmit});

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Hero
        Text('Reset password', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text("Enter your email and we'll send you a link to reset your password.", style: Theme.of(context).textTheme.bodyMedium),

        const SizedBox(height: 32),

        // Form
        Form(
          key: formKey,
          child: TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            autofocus: true,
            style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
        ),

        // Error
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(error!, style: GoogleFonts.manrope(fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],

        const SizedBox(height: 32),

        LargeButton(label: 'Send reset link', onPressed: loading ? null : onSubmit, loading: loading),
      ],
    );
  }
}

// Confirmation view — email sent

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 28),
        ),

        const SizedBox(height: 24),

        Text('Check your email', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.manrope(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6),
            children: [
              const TextSpan(text: "We've sent a password reset link to "),
              TextSpan(
                text: email,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
              ),
              const TextSpan(text: '. Follow the link in the email to set a new password.'),
            ],
          ),
        ),

        const SizedBox(height: 44),

        LargeButton(label: 'Back to sign in', onPressed: () => context.go('/login')),

        const SizedBox(height: 32),
      ],
    );
  }
}
