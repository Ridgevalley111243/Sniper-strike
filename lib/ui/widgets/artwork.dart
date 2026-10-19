import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';

/// Deterministic album artwork in the TRUHive palette (the "Artwork" component
/// set in Figma). The same seed always produces the same cover.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.seed, this.size = 52, this.radius, this.shadow});

  final String seed;
  final double size;
  final double? radius;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final h = fnv1a(seed);
    final style = h % 6;
    final r = radius ?? (size * 0.22).clamp(8.0, 36.0);
    final Widget art = style == 3
        ? Image.asset('assets/images/headphones.jpg', fit: BoxFit.cover, width: size, height: size,
            cacheWidth: (size * 2).round())
        : CustomPaint(painter: _ArtPainter(h, style), size: Size.square(size));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(r), boxShadow: shadow),
      child: ClipRRect(borderRadius: BorderRadius.circular(r), child: ExcludeSemantics(child: art)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.hash, this.style);
  final int hash;
  final int style;

  static const _bgs = [AppColors.navy, AppColors.lightBlue, AppColors.blue, AppColors.navy, AppColors.surfaceSecondary, AppColors.blue];

  void _blob(Canvas c, Size s, double x, double y, double r, Color col, double a) {
    final center = Offset(x * s.width, y * s.height);
    final rad = r * s.width;
    c.drawCircle(
      center,
      rad,
      Paint()
        ..shader = RadialGradient(colors: [col.withValues(alpha: a), col.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: rad)),
    );
  }

  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(hash);
    double j(double v) => v + (rnd.nextDouble() - 0.5) * 0.25;
    c.drawRect(Offset.zero & s, Paint()..color = _bgs[style]);
    switch (style) {
      case 0: // Tide
        _blob(c, s, j(0.75), j(0.2), 0.7, AppColors.blue, 0.95);
        _blob(c, s, j(0.7), j(0.7), 0.45, AppColors.lightBlue, 0.85);
        _blob(c, s, j(0.1), j(0.85), 0.5, AppColors.surfaceSecondary, 1);
      case 1: // Glacier
        _blob(c, s, j(0.15), j(0.8), 0.75, AppColors.blue, 0.9);
        _blob(c, s, j(0.85), j(0.15), 0.55, AppColors.offWhite, 0.95);
        _blob(c, s, j(0.45), j(0.95), 0.35, AppColors.navy, 0.7);
      case 2: // Pulse
        final grad = Paint()
          ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue, AppColors.navy])
              .createShader(Offset.zero & s);
        c.drawRect(Offset.zero & s, grad);
        final center = Offset(s.width * j(0.5), s.height * j(0.5));
        for (final (r, a) in [(0.38, 0.25), (0.27, 0.4), (0.16, 0.6)]) {
          c.drawCircle(center, s.width * r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s.width / 110)
            ..color = AppColors.lightBlue.withValues(alpha: a));
        }
        c.drawCircle(center, s.width * 0.055, Paint()..color = AppColors.offWhite);
      case 4: // Dusk
        _blob(c, s, j(0.2), j(0.3), 0.7, AppColors.navy, 1);
        _blob(c, s, j(0.8), j(0.55), 0.6, AppColors.lightBlue, 0.8);
        _blob(c, s, j(0.55), j(0.85), 0.28, AppColors.offWhite, 0.75);
      default: // Mist
        _blob(c, s, j(0.3), j(0.25), 0.6, AppColors.offWhite, 0.55);
        _blob(c, s, j(0.6), j(0.9), 0.75, AppColors.navy, 0.8);
        _blob(c, s, j(0.95), j(0.4), 0.35, AppColors.lightBlue, 0.5);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.hash != hash;
}
