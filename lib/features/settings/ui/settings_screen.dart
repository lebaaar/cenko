import 'dart:async';

import 'package:cenko/features/auth/data/user_repository.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/auth_provider.dart';
import 'package:cenko/shared/providers/current_user_provider.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:cenko/shared/widgets/bullet_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    try {
      await _repo.updateDisplayName(uid, trimmed);
      ref.invalidate(currentUserProvider);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    }
  }

  Future<void> _saveEmail(String uid, String value) async {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    try {
      await _repo.updateEmail(uid, trimmed);
      ref.invalidate(currentUserProvider);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    }
  }

  Future<void> _savePreferences(String uid) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _repo.updateSettings(uid, theme: _theme, lang: _language, notificationsEnabled: _notificationsEnabled);
      ref.invalidate(currentUserProvider);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
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
    } on OwnedSharedListsException catch (e) {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteAccountCannotTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.deleteAccountTransferMsg),
                const SizedBox(height: 12),
                ...e.listNames.map((name) => BulletPoint(name)),
                const SizedBox(height: 4),
                Text(l10n.deleteAccountTransferTitle, style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 8),
                BulletPoint(l10n.deleteAccountStep1),
                BulletPoint.widget(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.deleteAccountStep2Pre),
                        const WidgetSpan(child: Icon(Icons.more_vert, size: 16), alignment: PlaceholderAlignment.middle),
                        TextSpan(text: l10n.deleteAccountStep2Post),
                      ],
                    ),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
                BulletPoint(l10n.deleteAccountStep3),
                BulletPoint.widget(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.deleteAccountStep4Pre),
                        const WidgetSpan(child: Icon(Icons.more_vert, size: 16), alignment: PlaceholderAlignment.middle),
                      ],
                    ),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ),
                BulletPoint(l10n.deleteAccountStep5),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurface),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleteLoading = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteAccountFailedTitle),
          content: Text(l10n.errorGeneric),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.onSurface),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _error = l10n.settingsNoEmailForReset);
      return;
    }

    setState(() => _resetPasswordLoading = true);
    try {
      await ref.read(authNotifierProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      setState(() => _error = null);
      SnackBarService.show(l10n.settingsPasswordResetSent(email), duration: const Duration(seconds: 5));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.errorGeneric);
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
      error: (_, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: Text(AppLocalizations.of(context)!.errorGeneric)),
      ),
      data: (user) {
        final hasPasswordProvider = user?.authProvider == 'email';
        final l10n = AppLocalizations.of(context)!;

        if (!_initialized && user != null) {
          _nameCtrl.text = user.displayName;
          _emailCtrl.text = user.email;
          _theme = user.theme;
          _language = user.lang;
          _notificationsEnabled = user.notificationsEnabled;
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
                              onChanged: user == null ? null : (value) => _onNameChanged(user.id, value),
                              decoration: InputDecoration(labelText: l10n.settingsDisplayName),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailCtrl,
                              textInputAction: TextInputAction.next,
                              onChanged: user == null ? null : (value) => _onEmailChanged(user.id, value),
                              decoration: InputDecoration(labelText: l10n.email),
                              enabled: false, // TODO
                            ),
                            const SizedBox(height: 10),
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
                            Text(l10n.preferencesTitle, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(l10n.preferencesAccountSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 12),
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
                                  _savePreferences(user.id);
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
                                if (user != null) _savePreferences(user.id);
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
                                  _savePreferences(user.id);
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
