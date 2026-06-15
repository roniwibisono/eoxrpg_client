import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart' show EdgeInsets, TextStyle, FontWeight;

import '../../engine/entity/direction.dart';
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

class SkillButton extends PositionComponent
    with TapCallbacks, HasGameReference<EoxGame> {
  final String label;
  final String? cooldownSkillId;
  final double cooldownTotal;
  final void Function() onPressed;
  final double dx;
  final double dy;

  SkillButton({
    required this.label,
    required this.onPressed,
    required this.dx,
    required this.dy,
    this.cooldownSkillId,
    this.cooldownTotal = 0,
    double radius = 30,
  }) : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(size.x - dx, size.y - dy);
  }

  bool _pressed = false;
  bool isSelected = false;

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
        ..strokeWidth = isSelected ? 4 : 2
        ..color = isSelected
            ? const Color(0xFFFFD700)
            : const Color(0xFFB0BEC5),
    );

    if (isSelected) {
      canvas.drawCircle(
        c,
        _radius - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x88FFD700),
      );
    }

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

Vector2 directionUnitVector(Direction8 d) {
  switch (d) {
    case Direction8.down:
      return Vector2(0, 1);
    case Direction8.downLeft:
      return Vector2(-0.7071, 0.7071);
    case Direction8.left:
      return Vector2(-1, 0);
    case Direction8.upLeft:
      return Vector2(-0.7071, -0.7071);
    case Direction8.up:
      return Vector2(0, -1);
    case Direction8.upRight:
      return Vector2(0.7071, -0.7071);
    case Direction8.right:
      return Vector2(1, 0);
    case Direction8.downRight:
      return Vector2(0.7071, 0.7071);
  }
}
