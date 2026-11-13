import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short visual-only celebration for an improved VMA.
class VmaCelebrationOverlay extends StatefulWidget {
  const VmaCelebrationOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<VmaCelebrationOverlay> createState() => _VmaCelebrationOverlayState();
}

class _VmaCelebrationOverlayState extends State<VmaCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.58, curve: Curves.elasticOut),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.2, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onComplete();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color.fromARGB(28, 20, 10, 40)),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                CustomPaint(painter: _ConfettiPainter(_controller.value)),
          ),
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFF1A8), Color(0xFFFFB300)],
                    ),
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xAAFFB300),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 82,
                    color: Color(0xFF6A3100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;
  static const _colors = [
    Color(0xFFFF4081),
    Color(0xFF00D4FF),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
    Color(0xFFB388FF),
    Color(0xFFFF6E40),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = math.min(size.width, size.height);
    for (var i = 0; i < 42; i++) {
      final seed = (i * 47 % 101) / 100;
      final angle = i * math.pi * (3 - math.sqrt(5));
      final radius = shortest * (0.18 + seed * 0.4) * progress;
      final position = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius + progress * progress * 72,
      );
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(
          alpha: (1 - progress).clamp(0, 1).toDouble(),
        );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + seed * 5,
            height: 9 + seed * 9,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
