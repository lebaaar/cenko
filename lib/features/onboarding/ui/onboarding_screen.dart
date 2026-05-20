import 'package:cenko/l10n/app_localizations.dart';
import 'package:cenko/shared/providers/intro_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(seconds: 5);
  static const _totalSlides = 5;

  late AnimationController _progressController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: _slideDuration);
    _progressController.addStatusListener(_onProgressStatus);
    _progressController.forward();
  }

  void _onProgressStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && _currentIndex < _totalSlides - 1) _advance();
  }

  void _goToSlide(int index) {
    setState(() => _currentIndex = index);
    _progressController.reset();
    _progressController.forward();
  }

  void _advance() {
    if (_currentIndex < _totalSlides - 1) {
      _goToSlide(_currentIndex + 1);
    } else {
      _markShownAndGo('/login');
    }
  }

  void _retreat() {
    if (_currentIndex > 0) {
      _goToSlide(_currentIndex - 1);
    }
  }

  Future<void> _markShownAndGo(String path) async {
    await setIntroductionShown();
    if (!mounted) return;
    ref.read(introductionShownProvider.notifier).state = true;
    context.go(path);
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressStatus);
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = _buildSlides(l10n);
    final slide = slides[_currentIndex];
    final isLast = _currentIndex == _totalSlides - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00746C), Color(0xFF001A18)]),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: List.generate(_totalSlides, (i) {
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(right: i < _totalSlides - 1 ? 4 : 0),
                          height: 2.5,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(2)),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                double progress;
                                if (i < _currentIndex) {
                                  progress = 1.0;
                                } else if (i == _currentIndex) {
                                  progress = _progressController.value;
                                } else {
                                  progress = 0.0;
                                }
                                return FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _markShownAndGo('/login'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.75)),
                      child: Text(l10n.onboardingSkip, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final width = MediaQuery.of(context).size.width;
                      if (details.globalPosition.dx < width / 2) {
                        _retreat();
                      } else {
                        _advance();
                      }
                    },
                    child: _SlideContent(key: ValueKey(_currentIndex), slide: slide),
                  ),
                ),
                if (isLast) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _markShownAndGo('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF006760),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(l10n.onboardingGetStarted, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: TextButton(
                            onPressed: () => _markShownAndGo('/login'),
                            style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.7)),
                            child: Text(l10n.onboardingSignIn, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_OnboardingSlide> _buildSlides(AppLocalizations l10n) {
    return [
      _OnboardingSlide(icon: Icons.local_offer_rounded, title: l10n.onboardingSlide1Title, body: l10n.onboardingSlide1Body),
      _OnboardingSlide(icon: Icons.qr_code_scanner_rounded, title: l10n.onboardingSlide2Title, body: l10n.onboardingSlide2Body),
      _OnboardingSlide(icon: Icons.receipt_long_rounded, title: l10n.onboardingSlide3Title, body: l10n.onboardingSlide3Body),
      _OnboardingSlide(icon: Icons.checklist_rounded, title: l10n.onboardingSlide4Title, body: l10n.onboardingSlide4Body),
      _OnboardingSlide(icon: Icons.rocket_launch_rounded, title: l10n.onboardingSlide5Title, body: l10n.onboardingSlide5Body),
    ];
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardingSlide({required this.icon, required this.title, required this.body});
}

class _SlideContent extends StatefulWidget {
  final _OnboardingSlide slide;
  const _SlideContent({super.key, required this.slide});

  @override
  State<_SlideContent> createState() => _SlideContentState();
}

class _SlideContentState extends State<_SlideContent> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                ),
                child: Icon(widget.slide.icon, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 44),
              Text(
                widget.slide.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
              ),
              const SizedBox(height: 16),
              Text(
                widget.slide.body,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.78), height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
