import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../content/onboarding.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == onboardingPages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => SessionScope.read(context).completeOnboarding();

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const soft = Color(0xB3FFFFFF);

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.leafDeep,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 12, 32),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const AppLogo(size: 40),
                        const SizedBox(width: 10),
                        Text('Tontine BF', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                        const Spacer(),
                        if (!_isLast)
                          TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                            child: const Text('Passer'),
                          ),
                        if (_isLast) const SizedBox(height: 48),
                      ],
                    ),
                    const SizedBox(height: 44),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: WovenBand(
                        height: 36,
                        semanticLabel: 'Illustration : six tours de cotisation',
                        segments: [
                          for (final fill in onboardingPages[_page].fills) WeaveSegment(fill: fill, color: AppColors.gold),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tour 1', style: theme.textTheme.bodySmall?.copyWith(color: soft)),
                          Text('Tour 6', style: theme.textTheme.bodySmall?.copyWith(color: soft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingPages.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) {
                final page = onboardingPages[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(page.title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 12),
                      Text(page.body, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted, fontSize: 17)),
                      if (index == onboardingPages.length - 1) ...[
                        const SizedBox(height: 24),
                        Panel(
                          color: AppColors.goldSoft,
                          borderColor: AppColors.goldSoft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.goldText),
                              const SizedBox(width: 12),
                              Expanded(child: Text(onboardingMoneyNote, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Semantics(
                    label: 'Page ${_page + 1} sur ${onboardingPages.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < onboardingPages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? AppColors.leaf : AppColors.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: _next, child: Text(_isLast ? 'Commencer' : 'Suivant')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
