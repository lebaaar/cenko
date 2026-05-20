import 'dart:async';

import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurface),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteLoading = true);
    try {
      await ref.read(authNotifierProvider).deleteAccount();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
      if (e.code == 'failed-precondition') {
        final ownedLists = (e.details?['ownedLists'] as List?)?.cast<String>() ?? [];
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) {
            final dl10n = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(dl10n.deleteAccountCannotTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dl10n.deleteAccountTransferMsg),
                  if (ownedLists.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...ownedLists.map(
                      (name) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text('• $name', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(dl10n.deleteAccountTransferTitle),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. ${dl10n.deleteAccountStep1}'),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('2. ${dl10n.deleteAccountStep2Pre}'),
                          const Icon(Icons.more_vert, size: 16),
                          Text(dl10n.deleteAccountStep2Post),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('3. ${dl10n.deleteAccountStep3}'),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [Text('4. ${dl10n.deleteAccountStep4Pre}'), const Icon(Icons.more_vert, size: 16)],
                      ),
                      const SizedBox(height: 6),
                      Text('5. ${dl10n.deleteAccountStep5}'),
                    ],
                  ),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(dl10n.close))],
            );
          },
        );
      } else {
        setState(() => _error = e.message ?? e.code);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleteLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _error = l10n.settingsNoEmailForReset);
      return;
    }

    setState(() => _resetPasswordLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _error = null);
      SnackBarService.show(l10n.settingsPasswordResetSent(email), duration: const Duration(seconds: 5));
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
        final l10n = AppLocalizations.of(context)!;

        if (!_initialized && user != null) {
          _nameCtrl.text = user.name;
          _emailCtrl.text = user.email;
          _theme = UserSettings.normalizeTheme(user.settings.theme);
          _language = user.settings.language;
          _notificationsEnabled = user.settings.notificationsEnabled;
          _initialized = true;
        }

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(title: Text(l10n.settingsTitle)),
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
                            Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(l10n.settingsAccountSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              onChanged: user == null ? null : (value) => _onNameChanged(user.userId, value),
                              decoration: InputDecoration(labelText: l10n.settingsDisplayName),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              textInputAction: TextInputAction.next,
                              onChanged: user == null ? null : (value) => _onEmailChanged(user.userId, value),
                              decoration: InputDecoration(labelText: l10n.email),
                              enabled: false, // TODO
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _theme,
                              decoration: InputDecoration(labelText: l10n.settingsThemeLabel),
                              items: [
                                DropdownMenuItem(value: 'system', child: Text(l10n.settingsThemeSystem)),
                                DropdownMenuItem(value: 'light', child: Text(l10n.settingsThemeLight)),
                                DropdownMenuItem(value: 'dark', child: Text(l10n.settingsThemeDark)),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _theme = value);
                                if (user != null) {
                                  _savePreferences(user.userId);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _language,
                              decoration: InputDecoration(labelText: l10n.settingsLanguageLabel),
                              items: [
                                DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
                                DropdownMenuItem(value: 'sl', child: Text(l10n.languageSlovenian)),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _language = value);
                                if (user != null) _savePreferences(user.userId);
                              },
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(l10n.settingsNotificationsTitle),
                              subtitle: Text(l10n.settingsNotificationsSubtitle),
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
                            Text(l10n.settingsSecuritySection, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(l10n.settingsSecuritySubtitle, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 16),
                            if (hasPasswordProvider) ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: (user == null || _resetPasswordLoading || _deleteLoading) ? null : _resetPassword,
                                  child: _resetPasswordLoading
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(l10n.settingsResetPassword),
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
                                child: Text(l10n.settingsDeleteAccount),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_deleteLoading) ...[const ModalBarrier(dismissible: false, color: Colors.black54), const Center(child: CircularProgressIndicator())],
          ],
        );
      },
    );
  }
}
