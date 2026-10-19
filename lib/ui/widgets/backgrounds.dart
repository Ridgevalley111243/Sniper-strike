import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The liquid marble texture from the Splash design (assets/images/marble.jpg).
class MarbleBackground extends StatelessWidget {
  const MarbleBackground({super.key, this.veil = 0, this.child});

  /// 0..1 navy veil drawn over the marble so content stays readable.
  final double veil;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        image: DecorationImage(image: AssetImage('assets/images/marble.jpg'), fit: BoxFit.cover),
      ),
      child: veil <= 0
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navy.withValues(alpha: veil * 0.75),
                    const Color(0xFF0F2440).withValues(alpha: veil * 0.92),
                    AppColors.navy.withValues(alpha: (veil * 1.1).clamp(0, 1)),
                  ],
                ),
              ),
              child: child,
            ),
    );
  }
}

/// Calm navy background with a soft marble glow — the default in-app canvas.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        gradient: RadialGradient(
          center: Alignment(0.85, -1.05),
          radius: 1.1,
          colors: [Color(0xFF2B5277), Color(0xFF14304F), AppColors.navy],
          stops: [0, 0.38, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-1.2, 0.9),
            radius: 0.9,
            colors: [Color(0x99173454), Color(0x000A1931)],
          ),
        ),
        child: child,
      ),
    );
  }
}
