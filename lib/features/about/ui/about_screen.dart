import 'dart:io';

import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackBarService.show(l10n.aboutCannotOpenLink);
      }
    } catch (_) {
      SnackBarService.show(l10n.aboutError);
    }
  }

  void _openContact(ContactType type) {
    context.push('/contact', extra: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/cenko/logo_rounded.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kAppName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•'),
                          const SizedBox(width: 6),
                          if (_isCheckingForUpdate)
                            SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => _launchUrl(kGooglePlayStoreUrl),
                              child: Text(
                                _updateInfo?.updateAvailability ==
                                        UpdateAvailability.updateAvailable
                                    ? AppLocalizations.of(
                                        context,
                                      )!.aboutUpdateAvailable
                                    : AppLocalizations.of(
                                        context,
                                      )!.aboutViewOnGooglePlay,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                AppLocalizations.of(context)!.aboutDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.aboutSupport,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.mail_rounded,
              title: AppLocalizations.of(context)!.aboutContact,
              subtitle: AppLocalizations.of(context)!.aboutContactSubtitle,
              onTap: () => _openContact(ContactType.contact),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: AppLocalizations.of(context)!.aboutFeedback,
              subtitle: AppLocalizations.of(context)!.aboutFeedbackSubtitle,
              onTap: () => _openContact(ContactType.feedback),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: AppLocalizations.of(context)!.aboutFeatureRequest,
              subtitle: AppLocalizations.of(
                context,
              )!.aboutFeatureRequestSubtitle,
              onTap: () => _openContact(ContactType.featureRequest),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.bug_report_rounded,
              title: AppLocalizations.of(context)!.aboutBugReport,
              subtitle: AppLocalizations.of(context)!.aboutBugReportSubtitle,
              onTap: () => _openContact(ContactType.bugReport),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.aboutDevelopment,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              icon: Icons.code_rounded,
              title: AppLocalizations.of(context)!.aboutViewSourceCode,
              subtitle: AppLocalizations.of(context)!.aboutViewSourceSubtitle,
              onTap: () => _launchUrl(kGitHubUrl),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              context,
              icon: Icons.favorite_rounded,
              title: AppLocalizations.of(context)!.aboutKofi,
              subtitle: AppLocalizations.of(context)!.aboutKofiSubtitle,
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
              Icon(
                icon,
                color: isPrimary ? primaryColor : onSurfaceVariant,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPrimary ? primaryColor : onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: isPrimary ? primaryColor : onSurfaceVariant,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
