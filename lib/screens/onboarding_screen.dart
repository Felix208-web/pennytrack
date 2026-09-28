import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/onboarding_art.dart';
import '../widgets/pennytrack_logo.dart';
import 'app_shell.dart';

class _Slide {
  const _Slide({
    required this.title,
    required this.body,
    required this.icon,
    required this.chips,
  });

  final String title;
  final String body;
  final IconData icon;
  final List<ArtChip> chips;
}

const _slides = [
  _Slide(
    title: 'Track every naira',
    body: 'Log what you earn and spend in seconds, and always know where '
        'your money goes.',
    icon: Icons.account_balance_wallet_rounded,
    chips: [
      ArtChip(
        icon: Icons.south_west_rounded,
        text: '+₦250,000',
        color: AppColors.income,
        alignment: Alignment(-0.95, -0.7),
      ),
      ArtChip(
        icon: Icons.restaurant_rounded,
        text: '-₦4,500',
        color: AppColors.orange,
        alignment: Alignment(0.95, 0.65),
      ),
    ],
  ),
  _Slide(
    title: 'Understand your spending',
    body: 'See which categories take the most each month and spot where '
        'you can cut back.',
    icon: Icons.pie_chart_rounded,
    chips: [
      ArtChip(
        icon: Icons.restaurant_rounded,
        text: 'Food 38%',
        color: Color(0xFFFF8A00),
        alignment: Alignment(0.95, -0.72),
      ),
      ArtChip(
        icon: Icons.directions_bus_rounded,
        text: 'Transport 21%',
        color: Color(0xFF4DA3FF),
        alignment: Alignment(-0.95, 0.7),
      ),
    ],
  ),
  _Slide(
    title: 'Stay ahead of bills',
    body: 'Set a monthly budget and get reminded before rent, data and '
        'subscriptions are due.',
    icon: Icons.event_available_rounded,
    chips: [
      ArtChip(
        icon: Icons.notifications_active_rounded,
        text: 'Rent due in 3 days',
        color: AppColors.orange,
        alignment: Alignment(-0.95, -0.72),
      ),
      ArtChip(
        icon: Icons.check_circle_rounded,
        text: 'Budget on track',
        color: AppColors.income,
        alignment: Alignment(0.95, 0.68),
      ),
    ],
  ),
];

/// Shown the first time the app opens: three welcome slides, then a step
/// asking for the user's name.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final pageController = PageController();
  final nameController = TextEditingController();

  int page = 0;

  /// The slides plus the name step.
  int get pageCount => _slides.length + 1;
  bool get onNameStep => page == _slides.length;

  @override
  void dispose() {
    pageController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final name = nameController.text.trim();

    if (name.isNotEmpty) {
      await DatabaseHelper.setSetting('user_name', name);
    }

    await DatabaseHelper.setSetting('onboarding_done', 'true');
    await NotificationService.requestPermission();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AppShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const PennyTrackLogo(size: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'PennyTrack',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!onNameStep)
                    TextButton(
                      onPressed: () => _goTo(_slides.length),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Skip'),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: pageCount,
                onPageChanged: (index) {
                  FocusScope.of(context).unfocus();

                  setState(() {
                    page = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index == _slides.length) {
                    return _NameStep(
                      controller: nameController,
                      onSubmitted: _finish,
                    );
                  }

                  return _SlideView(slide: _slides[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  _PageDots(count: pageCount, current: page),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: onNameStep ? 'Get Started' : 'Next',
                    icon: onNameStep ? null : Icons.arrow_forward_rounded,
                    onPressed: onNameStep ? _finish : () => _goTo(page + 1),
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: OnboardingArt(icon: slide.icon, chips: slide.chips),
          ),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('👋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'What should we call you?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'We’ll use it to greet you. It stays on your phone.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmitted(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'Your first name (optional)',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == current;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.orange : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
