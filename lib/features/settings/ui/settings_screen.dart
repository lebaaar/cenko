import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cenko/features/auth/data/user_model.dart';
import 'package:cenko/features/auth/data/user_repository.dart';
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
  Timer? _nameDebounce;
  String? _error;
  String _theme = 'system';
  String _language = 'en';
  bool _notificationsEnabled = true;
  bool _initialized = false;

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameCtrl.dispose();
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

  Future<void> _resetDefaults(String uid) async {
    setState(() {
      _theme = 'system';
      _language = 'en';
      _notificationsEnabled = true;
      _error = null;
    });
    await _savePreferences(uid);
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
        if (!_initialized && user != null) {
          _nameCtrl.text = user.name;
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
                  Text('Account', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Manage your account settings and preferences', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
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
                        Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          onChanged: user == null ? null : (value) => _onNameChanged(user.userId, value),
                          decoration: const InputDecoration(labelText: 'Display name'),
                        ),
                        const SizedBox(height: 24),
                        Text('Theme', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 20),
                        OutlinedButton(onPressed: user == null ? null : () => _resetDefaults(user.userId), child: const Text('Reset to defaults')),
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
