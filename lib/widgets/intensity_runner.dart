import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A brief, text-free preview of how the selected running intensity feels.
class IntensityRunner extends StatefulWidget {
  const IntensityRunner({super.key, required this.percent});

  final double percent;

  @override
  State<IntensityRunner> createState() => _IntensityRunnerState();
}

class _IntensityRunnerState extends State<IntensityRunner>
    with SingleTickerProviderStateMixin {
  static const _previewSeconds = 3.2;
  late final Ticker _ticker = createTicker(_tick);
  late double _effort = _target;
  double _phase = 0.14;
  double _remaining = _previewSeconds;
  Duration _lastElapsed = Duration.zero;
  bool _reducedMotion = false;
  bool _visible = true;

  double get _target => ((widget.percent - 60) / 60).clamp(0.0, 1.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion) {
      _effort = _target;
      _phase = 0.14;
    }
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant IntensityRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent == widget.percent) return;
    _remaining = _previewSeconds;
    if (_reducedMotion) _effort = _target;
    _syncTicker();
  }

  void _syncTicker() {
    final animate = !_reducedMotion && _visible && _remaining > 0;
    if (animate && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _lastElapsed).inMicroseconds / 1000000;
    _lastElapsed = elapsed;
    if (seconds <= 0) return;
    setState(() {
      _effort += (_target - _effort) * (1 - math.exp(-seconds * 10));
      _phase = (_phase + seconds * (1.1 + 2.5 * _effort)) % 1;
      _remaining -= seconds;
      if (_remaining <= 0) {
        _effort = _target;
        _phase = 0.14;
        _ticker.stop();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: 68,
        width: double.infinity,
        child: CustomPaint(
          painter: _RunnerPainter(
            effort: _effort,
            phase: _phase,
            colors: Theme.of(context).colorScheme,
          ),
        ),
      ),
    ),
  );
}

class _RunnerPainter extends CustomPainter {
  const _RunnerPainter({
    required this.effort,
    required this.phase,
    required this.colors,
  });

  final double effort;
  final double phase;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    final scale = math.min(1.0, size.height / 68);
    final margin = math.min(42.0, size.width / 2);
    final x = margin + (size.width - margin * 2) * effort;
    final wave = math.sin(phase * math.pi * 2);
    final bob = (1 - math.cos(phase * math.pi * 4)) * (0.5 + effort);
    final ink = colors.onSurface;
    final energy = Color.lerp(
      colors.primary,
      colors.error,
      effort * effort * 0.7,
    )!;
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // A light track and moving marks make cadence readable even at small sizes.
    canvas.drawLine(
      Offset(8, 64 * scale),
      Offset(size.width - 8, 64 * scale),
      line
        ..color = colors.primary.withValues(alpha: 0.16)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 4; i++) {
      final offset = ((i / 4 + phase) % 1) * 92;
      canvas.drawLine(
        Offset(x - offset + 18, 64 * scale),
        Offset(x - offset + 23 + effort * 6, 64 * scale),
        line
          ..color = colors.primary.withValues(alpha: 0.22)
          ..strokeWidth = 2,
      );
    }

    canvas.save();
    canvas.translate(x, (36 - bob) * scale);
    canvas.scale(scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 28 + bob),
        width: 24 + effort * 10,
        height: 3,
      ),
      Paint()..color = colors.primary.withValues(alpha: 0.12),
    );
    if (effort > 0.15) {
      for (var i = 0; i < 3; i++) {
        final length = 7 + effort * (9 + i * 4);
        final drift = (phase + i / 3) % 1 * 9;
        canvas.drawLine(
          Offset(-12 - drift, -19 + i * 9),
          Offset(-12 - drift - length, -19 + i * 9),
          line
            ..color = energy.withValues(alpha: effort * (0.24 + i * 0.08))
            ..strokeWidth = 1.8,
        );
      }
    }

    final shoulder = Offset(1 + effort * 9, -17);
    final hip = Offset.zero;
    final head = Offset(shoulder.dx + 2 + effort * 2, -26);
    final swing = wave * (0.4 + effort * 0.8);

    Offset segment(Offset from, double angle, double length) =>
        from + Offset(math.sin(angle) * length, math.cos(angle) * length);

    void limb(
      Offset origin,
      double angle,
      double bend,
      double upper,
      double lower,
      Color color, {
      bool foot = false,
    }) {
      final joint = segment(origin, angle, upper);
      final end = segment(joint, angle + bend, lower);
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(joint.dx, joint.dy)
          ..lineTo(end.dx, end.dy),
        line
          ..color = color
          ..strokeWidth = 3,
      );
      if (foot) {
        canvas.drawLine(
          end + const Offset(-2, 0),
          end + const Offset(4, 0),
          line
            ..color = energy
            ..strokeWidth = 3.5,
        );
      }
    }

    // Opposing arms/legs and increasing knee lift distinguish a jog from a sprint.
    limb(
      hip,
      -swing,
      -0.4 - math.max(0, wave) * (0.9 + effort),
      13,
      12,
      ink.withValues(alpha: 0.48),
      foot: true,
    );
    limb(shoulder, swing, 1.2, 10, 10, ink.withValues(alpha: 0.48));
    canvas.drawLine(
      hip,
      shoulder,
      line
        ..color = energy
        ..strokeWidth = 7,
    );
    canvas.drawLine(
      hip + const Offset(-2, 0),
      hip + const Offset(3, 0),
      line
        ..color = ink
        ..strokeWidth = 6,
    );
    limb(
      hip,
      swing,
      -0.4 - math.max(0, -wave) * (0.9 + effort),
      13,
      12,
      ink,
      foot: true,
    );
    limb(shoulder, -swing, 1.2, 10, 10, ink);
    canvas.drawCircle(
      head,
      5.5,
      Paint()..color = colors.surfaceContainerLowest,
    );
    canvas.drawCircle(
      head,
      5.5,
      line
        ..color = ink
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(head + const Offset(2, -1), 0.8, Paint()..color = ink);
    if (effort < 0.65) {
      canvas.drawArc(
        Rect.fromCenter(
          center: head + const Offset(1, 0.5),
          width: 5,
          height: 4,
        ),
        0.1,
        math.pi * 0.8,
        false,
        line
          ..color = ink
          ..strokeWidth = 1,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: head + const Offset(2.5, 2),
          width: 2.5,
          height: 3,
        ),
        Paint()..color = ink,
      );
      canvas.drawLine(
        head + const Offset(0.5, -3),
        head + const Offset(3, -2),
        line
          ..color = ink
          ..strokeWidth = 1,
      );
      for (var i = 0; i < 2; i++) {
        final flight = (phase + i / 2) % 1;
        final drop = head + Offset(-6 - flight * 9, -3 + flight * 13);
        canvas.drawLine(
          drop,
          drop + const Offset(-1, 2),
          line
            ..color = colors.primary.withValues(alpha: (1 - flight) * effort)
            ..strokeWidth = 1.7,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RunnerPainter oldDelegate) =>
      effort != oldDelegate.effort ||
      phase != oldDelegate.phase ||
      colors != oldDelegate.colors;
}
