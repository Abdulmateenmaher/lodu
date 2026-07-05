import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight CPU-only confetti — no extra packages, no platform overhead.
/// Spawns N particles and animates them downward with rotation and fade.
class ConfettiOverlay extends StatefulWidget {
  final int particleCount;
  final List<Color> colors;
  final Duration duration;

  const ConfettiOverlay({
    super.key,
    this.particleCount = 60,
    this.colors = const [
      Color(0xFFef4444),
      Color(0xFFfacc15),
      Color(0xFF22c55e),
      Color(0xFF3b82f6),
      Color(0xFFa855f7),
      Color(0xFFf59e0b),
    ],
    this.duration = const Duration(milliseconds: 2400),
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _particles = List.generate(widget.particleCount, (_) {
      return _Particle(
        color: widget.colors[_rng.nextInt(widget.colors.length)],
        dx: _rng.nextDouble() * 2 - 1, // -1..1
        dy: 0.4 + _rng.nextDouble() * 0.4, // 0.4..0.8
        size: 6 + _rng.nextDouble() * 6,
        spinSpeed: (_rng.nextDouble() * 2 - 1) * 6,
        delay: _rng.nextDouble() * 0.3,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return CustomPaint(
            painter: _ConfettiPainter(
              progress: _ctrl.value,
              particles: _particles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  final Color color;
  final double dx;
  final double dy;
  final double size;
  final double spinSpeed;
  final double delay;
  const _Particle({
    required this.color,
    required this.dx,
    required this.dy,
    required this.size,
    required this.spinSpeed,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = w / 2 + p.dx * w * 0.6 * t;
      final y = h * 0.1 + h * p.dy * t;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - t);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spinSpeed * t * 6);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 0.4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
