import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart' show EdgeInsets, TextStyle, FontWeight;

import '../eox_game.dart';

JoystickComponent buildJoystick() {
  return JoystickComponent(
    knob: CircleComponent(
      radius: 22,
      paint: BasicPalette.white.withAlpha(180).paint(),
    ),
    background: CircleComponent(
      radius: 52,
      paint: BasicPalette.white.withAlpha(60).paint(),
    ),
    margin: const EdgeInsets.only(left: 36, bottom: 36),
  );
}

/// Round HUD action button with a radial cooldown sweep read live from
/// the CooldownManager — the HUD observes domain state, never owns it.
class SkillButton extends PositionComponent
    with TapCallbacks, HasGameReference<EoxGame> {
  final String label;
  final String? cooldownSkillId;
  final double cooldownTotal;
  final void Function() onPressed;

  SkillButton({
    required this.label,
    required this.onPressed,
    this.cooldownSkillId,
    this.cooldownTotal = 0,
    required Vector2 position,
    double radius = 30,
  }) : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  bool _pressed = false;

  double get _radius => size.x / 2;

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    onPressed();
  }

  @override
  void onTapUp(TapUpEvent event) => _pressed = false;

  @override
  void onTapCancel(TapCancelEvent event) => _pressed = false;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = Offset(_radius, _radius);
    canvas.drawCircle(
      c,
      _radius,
      Paint()
        ..color = _pressed ? const Color(0xCC616161) : const Color(0xAA37474F),
    );
    canvas.drawCircle(
      c,
      _radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFB0BEC5),
    );

    // Cooldown sweep
    final skillId = cooldownSkillId;
    if (skillId != null && cooldownTotal > 0) {
      final frac =
          game.orchestrator.cooldownsOf('player').fraction(skillId, cooldownTotal);
      if (frac > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: _radius),
          -math.pi / 2,
          2 * math.pi * frac,
          true,
          Paint()..color = const Color(0x99000000),
        );
      }
    }

    final tp = TextPaint(
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
      ),
    );
    tp.render(canvas, label, Vector2(_radius, _radius), anchor: Anchor.center);
  }
}
