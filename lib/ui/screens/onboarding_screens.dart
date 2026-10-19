import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../services/app_services.dart';
import '../shell/app_shell.dart';
import '../widgets/backgrounds.dart';
import '../widgets/controls.dart';

/// Splash — reproduces the uploaded launch screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      context.go(context.services.settings.onboardingDone ? '/home' : '/welcome');
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MarbleBackground(
        child: Stack(children: [
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const LogoMark(size: 100),
                const SizedBox(height: 18),
                Text('TRUHive',
                    style: AppText.display.copyWith(fontSize: 46, height: 1.1, letterSpacing: -0.5, shadows: [
                      Shadow(color: AppColors.lightBlue.withValues(alpha: 0.35), blurRadius: 24),
                    ])),
                const SizedBox(height: 10),
                Text('Search • Download • Play', style: AppText.body.copyWith(fontSize: 16, letterSpacing: 0.2)),
              ]),
            ),
          ),
          Positioned(
            right: 44,
            bottom: 70,
            child: Opacity(
              opacity: 0.45,
              child: CustomPaint(size: const Size(26, 26), painter: _SparklePainter()),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w * 0.55, h * 0.45, w, h / 2)
      ..quadraticBezierTo(w * 0.55, h * 0.55, w / 2, h)
      ..quadraticBezierTo(w * 0.45, h * 0.55, 0, h / 2)
      ..quadraticBezierTo(w * 0.45, h * 0.45, w / 2, 0);
    c.drawPath(p, Paint()..color = AppColors.offWhite);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// First-time welcome — reproduces the uploaded onboarding screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _start(BuildContext context) async {
    await context.services.settings.completeOnboarding();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heroH = (size.height * 0.36).clamp(200.0, 340.0);
    return Scaffold(
      body: MarbleBackground(
        veil: 0.82,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: LayoutBuilder(builder: (context, c) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        SizedBox(
                          height: heroH + 40,
                          child: Stack(alignment: Alignment.center, children: [
                            Container(
                              width: heroH * 0.95,
                              height: heroH * 0.95,
                              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                                BoxShadow(color: AppColors.lightBlue.withValues(alpha: 0.32), blurRadius: 90, spreadRadius: 6),
                              ]),
                            ),
                            Positioned.fill(child: CustomPaint(painter: _WaveLinesPainter())),
                            ShaderMask(
                              shaderCallback: (r) => const RadialGradient(
                                colors: [Colors.white, Colors.white, Colors.transparent],
                                stops: [0, 0.55, 0.78],
                              ).createShader(r),
                              blendMode: BlendMode.dstIn,
                              child: Image.asset('assets/images/headphones.jpg',
                                  height: heroH, fit: BoxFit.contain, semanticLabel: 'Headphones'),
                            ),
                          ]),
                        ),
                        Column(children: [
                          Text('Your Music.\nYour Device.',
                              textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 32, height: 38 / 32)),
                          const SizedBox(height: Space.lg),
                          Text(
                            'Search music online, download available tracks directly to your device, and enjoy them offline.',
                            textAlign: TextAlign.center,
                            style: AppText.secondary.copyWith(color: AppColors.textPrimary.withValues(alpha: 0.85), height: 20 / 13),
                          ),
                          const SizedBox(height: Space.x3),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                            _Feature(LucideIcons.search, 'Search'),
                            SizedBox(width: 28),
                            _Feature(LucideIcons.download, 'Download'),
                            SizedBox(width: 28),
                            _Feature(LucideIcons.smartphone, 'Play Offline'),
                          ]),
                        ]),
                        Padding(
                          padding: const EdgeInsets.only(top: Space.x4, bottom: Space.xl),
                          child: Column(children: [
                            AppButton(label: 'Get Started', expand: true, onPressed: () => _start(context)),
                            const SizedBox(height: Space.md),
                            TextButton(
                              onPressed: () => _start(context),
                              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary, minimumSize: const Size(88, 44)),
                              child: Text('Skip', style: AppText.secondary.secondaryColor),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        child: Column(children: [
          Icon(icon, size: 26, color: AppColors.textPrimary),
          const SizedBox(height: Space.sm),
          Text(label, style: AppText.caption.secondaryColor),
        ]),
      );
}

class _WaveLinesPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final y = s.height * 0.5;
    final line = Paint()..color = AppColors.lightBlue.withValues(alpha: 0.35);
    c.drawRect(Rect.fromLTWH(-40, y - 0.5, 50, 1), line);
    c.drawRect(Rect.fromLTWH(s.width - 10, y - 0.5, 50, 1), line);
    const hs = [2.0, 3, 5, 4, 8, 6, 12, 9, 16, 11, 20, 14];
    for (var i = 0; i < hs.length; i++) {
      final p = Paint()..color = AppColors.lightBlue.withValues(alpha: 0.25 + i * 0.04);
      final h = hs[i].toDouble();
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(10 + i * 6.0, y - h, 2, h * 2), const Radius.circular(1)), p);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width - 12 - i * 6.0, y - h, 2, h * 2), const Radius.circular(1)), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
