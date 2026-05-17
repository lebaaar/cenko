import 'dart:convert';

import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/date_util.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchLegal();
  }

  Future<Map<String, dynamic>> _fetchLegal() async {
    final response = await http.get(Uri.parse(kLegalContentUrl));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final lastEdited = data['lastEdited'] as String? ?? '';
            final contactEmail = data['contactEmail'] as String? ?? kContactEmail;
            final documents = (data['documents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            final legalDoc = documents.isEmpty ? null : documents.first;
            final sections = (legalDoc?['sections'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

            DateTime? lastEditedDate;
            if (lastEdited.isNotEmpty) {
              lastEditedDate = DateTime.tryParse(lastEdited);
            }

            return _LegalContent(lastEditedDate: lastEditedDate, contactEmail: contactEmail, sections: sections);
          },
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.lastEditedDate, required this.contactEmail, required this.sections});

  final DateTime? lastEditedDate;
  final String contactEmail;
  final List<Map<String, dynamic>> sections;

  static IconData _iconFor(String title) => switch (title) {
    'Using Cenko' => Icons.check_circle_outline_rounded,
    'Information we handle' => Icons.data_usage_rounded,
    'Your rights' => Icons.tune_rounded,
    'How information is used' => Icons.tune_rounded,
    'Legal basis for processing (GDPR Article 6)' => Icons.balance_rounded,
    'Data retention' => Icons.history_rounded,
    'Sharing and transfers' => Icons.share_outlined,
    'Children' => Icons.child_care_rounded,
    'Third-party services' => Icons.link_rounded,
    'Liability and warranty' => Icons.gpp_maybe_rounded,
    'Data breach notification' => Icons.warning_amber_rounded,
    'Governing law' => Icons.account_balance_rounded,
    'Updates to this page' => Icons.update_rounded,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
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
          child: Row(
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
                    if (lastEditedDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last updated: ${displayWordedDate(lastEditedDate!)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final section in sections)
          _SectionCard(
            title: section['title'] as String? ?? '',
            icon: _iconFor(section['title'] as String? ?? ''),
            bullets: (section['bullets'] as List<dynamic>? ?? []).cast<String>(),
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
              Text('Email: $contactEmail', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/contact'),
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  label: const Text('Contact us'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.bullets});

  final String title;
  final IconData icon;
  final List<String> bullets;

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
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final bullet in bullets) _BulletPoint(bullet),
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
