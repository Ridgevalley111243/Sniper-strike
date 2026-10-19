import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Thin gradient progress bar (Figma "ProgressBar").
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, this.height = 4});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: AppColors.surfaceElevated),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.blue, AppColors.lightBlue])),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Circular download progress ring with a centered icon.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 36, this.child});
  final double value;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(value),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(2, 2, s.width - 4, s.height - 4);
    c.drawArc(r, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.surfaceElevated);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0, 1), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}

/// Waveform-style scrubber from the Now Playing design. Tap or drag to seek.
class WaveformScrubber extends StatefulWidget {
  const WaveformScrubber({super.key, required this.seed, required this.position, required this.duration, required this.onSeek});
  final int seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformScrubber> createState() => _WaveformScrubberState();
}

class _WaveformScrubberState extends State<WaveformScrubber> {
  double? _drag;

  double get _value {
    final d = widget.duration.inMilliseconds;
    return _drag ?? (d <= 0 ? 0 : widget.position.inMilliseconds / d);
  }

  void _seekTo(double x, double w) {
    final f = (x / w).clamp(0.0, 1.0);
    widget.onSeek(Duration(milliseconds: (widget.duration.inMilliseconds * f).round()));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.duration;
    return Semantics(
      slider: true,
      label: 'Seek',
      value: '${(_value * 100).round()}%',
      onIncrease: () => widget.onSeek(widget.position + const Duration(seconds: 10)),
      onDecrease: () => widget.onSeek(widget.position - const Duration(seconds: 10)),
      child: LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) => _seekTo(e.localPosition.dx, c.maxWidth),
          onHorizontalDragUpdate: (e) => setState(() => _drag = (e.localPosition.dx / c.maxWidth).clamp(0, 1)),
          onHorizontalDragEnd: (_) {
            if (_drag != null && d > Duration.zero) _seekTo(_drag! * c.maxWidth, c.maxWidth);
            setState(() => _drag = null);
          },
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(painter: _WavePainter(widget.seed, _value)),
          ),
        );
      }),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.seed, this.v);
  final int seed;
  final double v;

  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(seed);
    final n = (s.width / 5).floor();
    final bw = 2.4;
    final played = Paint()..color = AppColors.lightBlue;
    final rest = Paint()..color = AppColors.lightBlue.withValues(alpha: 0.28);
    for (var i = 0; i < n; i++) {
      final env = 0.55 + 0.45 * math.sin(i * 0.45).abs();
      final h = (6 + rnd.nextDouble() * 30 * env).clamp(4.0, s.height - 4);
      final x = i * s.width / n;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, (s.height - h) / 2, bw, h), const Radius.circular(1.2));
      c.drawRRect(r, x / s.width <= v ? played : rest);
    }
    final hx = (s.width * v).clamp(0.0, s.width - 2);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx, 2, 2, s.height - 4), const Radius.circular(1)),
        Paint()..color = AppColors.offWhite);
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.v != v || o.seed != seed;
}
