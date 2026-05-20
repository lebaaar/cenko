import 'dart:io';

import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/services/discord_webhook_service.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, this.initialType});

  final ContactType? initialType;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  late ContactType _selectedType;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? ContactType.contact;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _collectBugInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = DeviceInfoPlugin();

    String deviceName = 'Unknown';
    String osVersion = 'Unknown';

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      deviceName = 'Android (${info.model})';
      osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      deviceName = 'iOS (${info.model})';
      osVersion = '${info.systemName} ${info.systemVersion}';
    }

    return {
      'Timestamp': DateTime.now().toUtc().toString(),
      'App Version': '${packageInfo.version}+${packageInfo.buildNumber}',
      'Device': deviceName,
      'OS Version': osVersion,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final bugInfo = _selectedType == ContactType.bugReport ? await _collectBugInfo() : null;

      await DiscordWebhookService.send(
        type: _selectedType,
        message: _messageCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        userId: userId,
        bugInfo: bugInfo,
      );
      if (!mounted) return;
      context.pop();
      SnackBarService.show(AppLocalizations.of(context)!.contactMessageSent);
    } catch (_) {
      if (!mounted) return;
      SnackBarService.show(AppLocalizations.of(context)!.contactFailedToSend);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _contactTypeLabel(ContactType type, AppLocalizations l10n) {
    switch (type) {
      case ContactType.contact: return l10n.aboutContact;
      case ContactType.feedback: return l10n.aboutFeedback;
      case ContactType.featureRequest: return l10n.aboutFeatureRequest;
      case ContactType.bugReport: return l10n.aboutBugReport;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.contactTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ContactType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactType),
                  items: ContactType.values.map((t) => DropdownMenuItem(value: t, child: Text(_contactTypeLabel(t, AppLocalizations.of(context)!)))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactNameOptional),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.email),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.contactEmailRequired;
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(v.trim())) return AppLocalizations.of(context)!.contactInvalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageCtrl,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: AppLocalizations.of(context)!.contactMessage, alignLabelWithHint: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.contactMessageRequired;
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSending ? null : _submit,
                    style: FilledButton.styleFrom(foregroundColor: Colors.white),
                    child: _isSending
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(context)!.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
