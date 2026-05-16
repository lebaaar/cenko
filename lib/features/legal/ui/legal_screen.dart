import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/date_util.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/**
 * TODO - legal page content should be on the web and loaded in a webview or loaded from an API call
 * This is so we can update it without needing an app update
 */
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: colorScheme.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.gavel_rounded, color: colorScheme.onSurface, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Legal information', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Last updated: ${displayWordedDate(kLegalLastUpdated)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionCard(
              title: 'Using Cenko',
              icon: Icons.check_circle_outline_rounded,
              children: [
                _BulletPoint('Use the app only in a lawful way and respect the rights of other people and businesses.'),
                _BulletPoint(
                  'Do not try to interfere with the app, reverse engineer it, or use it in a way that could harm the service or other users.',
                ),
                _BulletPoint(
                  'If you create an account, you are responsible for keeping your access secure and for activity that happens under your account.',
                ),
              ],
            ),
            const _SectionCard(
              title: 'Information we handle',
              icon: Icons.data_usage_rounded,
              children: [
                _BulletPoint('Account details such as your email address and profile information.'),
                _BulletPoint('Content you add to the app, including shopping lists, receipts, favorites, and similar records.'),
                _BulletPoint('Technical information such as app version, device details, and diagnostic data when needed to keep the app working.'),
              ],
            ),
            const _SectionCard(
              title: 'Your rights',
              icon: Icons.tune_rounded,
              children: [
                _BulletPoint('You may request access to, correction of, or deletion of your personal information.'),
                _BulletPoint('You may object to certain types of processing or request restriction where applicable.'),
                _BulletPoint('You may delete your account and data associated with it at any time.'),
                _BulletPoint('You may contact us if you have questions about your privacy rights or data handling practices.'),
              ],
            ),
            const _SectionCard(
              title: 'How information is used',
              icon: Icons.tune_rounded,
              children: [
                _BulletPoint('To provide core features like authentication, shopping lists, deal discovery, receipt scanning, and support.'),
                _BulletPoint('To maintain, secure, troubleshoot, and improve the app.'),
                _BulletPoint('To meet legal, regulatory, and operational requirements.'),
              ],
            ),
            const _SectionCard(
              title: 'Data retention',
              icon: Icons.history_rounded,
              children: [
                _BulletPoint(
                  'We keep personal information only for as long as needed to provide the app, fulfill the purposes described here, or meet legal and operational requirements.',
                ),
                _BulletPoint('When you delete your account, we remove all associated data immediately.'),
                _BulletPoint('Some records may remain in backups or logs for a limited time before they are overwritten or deleted.'),
              ],
            ),
            const _SectionCard(
              title: 'Sharing and transfers',
              icon: Icons.share_outlined,
              children: [
                _BulletPoint('We may share information with service providers who help us operate the app and deliver its features.'),
                _BulletPoint(
                  'We may disclose information when required by law, to protect rights and safety, or in connection with a merger, acquisition, or similar business transaction.',
                ),
                _BulletPoint(
                  'If you choose to connect other services or submit content through an integrated feature, that information may be processed by the relevant provider as part of the feature you use.',
                ),
              ],
            ),
            const _SectionCard(
              title: 'Children',
              icon: Icons.child_care_rounded,
              children: [
                _BulletPoint(
                  'The app is not intended for children under the minimum age required by applicable law in their country. We do not knowingly collect personal information from them.',
                ),
                _BulletPoint('If you believe a child has provided personal information, contact us so we can review and address it.'),
              ],
            ),
            const _SectionCard(
              title: 'Third-party services',
              icon: Icons.link_rounded,
              children: [
                _BulletPoint('The app uses Google Sign-In and Firebase Authentication for sign-in and account access.'),
                _BulletPoint(
                  'The app uses Firebase Firestore, Firebase Functions, Firebase Storage, Firebase App Check, and Firebase AI to store data, run backend features, protect the service, and support AI-assisted functions.',
                ),
                _BulletPoint(
                  'The app uses Google ML Kit Text Recognition, Camera, Mobile Scanner, and Image Picker for receipt and barcode-related features.',
                ),
                _BulletPoint(
                  'The app uses Connectivity Plus, Device Info Plus, Package Info Plus, In-App Update, and URL Launcher for connectivity checks, device diagnostics, app version checks, updates, and opening external links.',
                ),
              ],
            ),
            const _SectionCard(
              title: 'Liability and warranty',
              icon: Icons.gpp_maybe_rounded,
              children: [
                _BulletPoint('The app is provided on an "as is" and "as available" basis without warranties of any kind.'),
                _BulletPoint('We do not guarantee uninterrupted availability, accuracy, or error-free operation of all features.'),
                _BulletPoint(
                  'To the maximum extent permitted by law, we are not liable for indirect, incidental, or consequential damages arising from use of the app.',
                ),
              ],
            ),
            const _SectionCard(
              title: 'Updates to this page',
              icon: Icons.update_rounded,
              children: [
                _BulletPoint(
                  'We may update this page at any time, and a revised version becomes effective immediately when it is posted unless stated otherwise.',
                ),
                _BulletPoint('The date above shows when this page was last changed.'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Questions?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'If you want to ask about this page or how data is handled, send a message through support.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),

                  const SizedBox(height: 10),
                  Text('Email: $kContactEmail', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(onPressed: () => context.push('/contact'), child: const Text('Contact us')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
