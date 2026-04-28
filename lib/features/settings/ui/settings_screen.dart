import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _repo = UserRepository();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  Timer? _nameDebounce;
  Timer? _emailDebounce;
  String? _error;
  String _theme = 'system';
  String _language = 'en';
  bool _notificationsEnabled = true;
  bool _initialized = false;
  bool _resetPasswordLoading = false;
  bool _deleteLoading = false;

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _emailDebounce?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName(String uid, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    try {
      await _repo.updateDisplayName(uid, trimmed);
      if (mounted) setState(() => _error = null);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  Future<void> _saveEmail(String uid, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    try {
      await _repo.updateEmail(uid, trimmed);
      if (mounted) setState(() => _error = null);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  Future<void> _savePreferences(String uid) async {
    try {
      await _repo.updateSettings(uid, UserSettings(theme: _theme, notificationsEnabled: _notificationsEnabled, language: _language));
      if (mounted) setState(() => _error = null);
    } on FirebaseException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    }
  }

  void _onNameChanged(String uid, String value) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveDisplayName(uid, value);
    });
  }

  void _onEmailChanged(String uid, String value) {
    _emailDebounce?.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveEmail(uid, value);
    });
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('This will permanently delete your account and all associated data. This cannot be undone'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurface),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteLoading = true);
    try {
      await ref.read(authNotifierProvider).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleteLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resetPassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _error = 'No email found for this account');
      return;
    }

    setState(() => _resetPasswordLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Password reset email has been sent to $email. Check your inbox and spam folder'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resetPasswordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: Text(error.toString())),
      ),
      data: (user) {
        final hasPasswordProvider = FirebaseAuth.instance.currentUser?.providerData.any((provider) => provider.providerId == 'password') ?? false;

        if (!_initialized && user != null) {
          _nameCtrl.text = user.name;
          _emailCtrl.text = user.email;
          _theme = UserSettings.normalizeTheme(user.settings.theme);
          _language = user.settings.language;
          _notificationsEnabled = user.settings.notificationsEnabled;
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Account', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Manage your account settings and preferences', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          onChanged: user == null ? null : (value) => _onNameChanged(user.userId, value),
                          decoration: const InputDecoration(labelText: 'Display name'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          textInputAction: TextInputAction.next,
                          onChanged: user == null ? null : (value) => _onEmailChanged(user.userId, value),
                          decoration: const InputDecoration(labelText: 'Email'),
                          enabled: false, // TODO
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _theme,
                          decoration: const InputDecoration(labelText: 'Theme mode'),
                          items: const [
                            DropdownMenuItem(value: 'system', child: Text('System')),
                            DropdownMenuItem(value: 'light', child: Text('Light')),
                            DropdownMenuItem(value: 'dark', child: Text('Dark')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _theme = value);
                            if (user != null) {
                              _savePreferences(user.userId);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Notifications'),
                          subtitle: const Text('Enable app notifications'),
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            if (user != null) {
                              _savePreferences(user.userId);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Manage your sign-in and account security', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        if (hasPasswordProvider) ...[
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: (user == null || _resetPasswordLoading || _deleteLoading) ? null : _resetPassword,
                              child: _resetPasswordLoading
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Reset password'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: (user == null || _deleteLoading) ? null : _deleteAccount,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(color: Theme.of(context).colorScheme.error),
                            ),
                            child: _deleteLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.error),
                                  )
                                : const Text('Delete account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
