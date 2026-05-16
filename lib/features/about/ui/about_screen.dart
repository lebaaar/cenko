import 'dart:io';
import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/shared/services/discord_webhook_service.dart';
import 'package:cenko/shared/services/snack_bar_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  AppUpdateInfo? _updateInfo;
  bool _isCheckingForUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) return;
    setState(() => _isCheckingForUpdate = true);
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateInfo = info;
        _isCheckingForUpdate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingForUpdate = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackBarService.show('Cannot open link');
      }
    } catch (_) {
      SnackBarService.show('An error occurred');
    }
  }

  void _openContact(ContactType type) {
    context.push('/contact', extra: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', width: 80, height: 80),
                  const SizedBox(height: 8),
                  Text(kAppName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'v${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                          const Text('•'),
                          const SizedBox(width: 6),
                          if (_isCheckingForUpdate)
                            SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            )
                          else
                            GestureDetector(
                              onTap: () => _launchUrl(kGooglePlayStoreUrl),
                              child: Text(
                                _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable ? 'Update available' : 'View on Google Play',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
              child: Text(
                'Cenko brings all deals from major Slovenian stores into one place so you always get the best price. '
                'Share shopping lists with family or friends and scan receipts to automatically track your spending. '
                'Based on your purchase habits, you also get personalized deal recommendations tailored to what you buy most.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Text('Support', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.mail_rounded,
              title: 'Contact',
              subtitle: 'Have a question? Get in touch',
              onTap: () => _openContact(ContactType.contact),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Feedback',
              subtitle: 'Share your thoughts or suggestions',
              onTap: () => _openContact(ContactType.feedback),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: 'Feature Request',
              subtitle: 'Suggest something new',
              onTap: () => _openContact(ContactType.featureRequest),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.bug_report_rounded,
              title: 'Report a Bug',
              subtitle: 'Help us improve the app',
              onTap: () => _openContact(ContactType.bugReport),
            ),
            const SizedBox(height: 24),
            Text('Development', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.code_rounded,
              title: 'View Source Code',
              subtitle: 'Open on GitHub',
              onTap: () => _launchUrl(kGitHubUrl),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.favorite_rounded,
              title: 'Buy Me a Ko-fi ☕',
              subtitle: 'Support development',
              onTap: () => _launchUrl(kKofiUrl),
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surfaceContainerLow;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: isPrimary ? primaryColor : onSurfaceVariant, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: isPrimary ? primaryColor : onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: isPrimary ? primaryColor : onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
