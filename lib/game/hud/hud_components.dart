import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart' show EdgeInsets, TextStyle, FontWeight;

import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../components/player_component.dart';
import '../eox_game.dart';
import '../skills/skill_aim_controller.dart';

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
    with DragCallbacks, HasGameReference<EoxGame> {
  final String label;
  final String? cooldownSkillId;
  final double cooldownTotal;
  final SkillDef skill;
  final String skillId;
  final void Function()? onTap;

  SkillButton({
    required this.label,
    required this.skill,
    required this.skillId,
    this.cooldownSkillId,
    this.cooldownTotal = 0,
    this.onTap,
    required Vector2 position,
    double radius = 30,
  }) : super(
          position: position,
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
        );

  bool _pressed = false;
  double get _radius => size.x / 2;
  double _totalDrag = 0;

  Vector2 _worldPos() {
    final player = game.player;
    if (player != null) return player.center;
    return Vector2.zero();
  }

  bool get _canCast {
    if (cooldownSkillId != null && cooldownTotal > 0) {
      if (!game.orchestrator.cooldownsOf('player').isReady(cooldownSkillId!)) {
        return false;
      }
    }
    if (onTap != null) return true;
    final e = game.orchestrator.entity('player');
    if (e == null || e.mp < skill.mpCost) return false;
    return true;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!_canCast) return;
    _pressed = true;
    _totalDrag = 0;

    game.aimController.beginAim(
      skill: skill,
      skillId: skillId,
      originScreen: event.devicePosition,
      playerWorldPos: _worldPos(),
    );
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _totalDrag += event.localDelta.length;
    game.aimController.updateAim(event.deviceEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _pressed = false;

    if (game.aimController.state != SkillAimState.aiming) return;

    final isQuickTap = _totalDrag < 30.0;
    final player = game.player;
    if (player == null) {
      game.aimController.cancelAim();
      game.aimController.reset();
      return;
    }

    if (onTap != null) {
      onTap!();
      game.aimController.endAim();
      game.aimController.reset();
      return;
    }

    if (skill.shape == SkillShape.aoe) {
      if (isQuickTap) {
        player.castNova();
      } else {
        player.castAoeAt(game.aimController.aimWorldPos);
      }
    } else if (isQuickTap) {
      final dir = directionUnitVector(player.facing);
      _fireInDirection(player, dir);
    } else {
      final dir = game.aimController.aimDirection;
      _fireInDirection(player, dir);
    }

    game.aimController.endAim();
    game.aimController.reset();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _pressed = false;
    game.aimController.cancelAim();
    game.aimController.reset();
  }

  void _fireInDirection(PlayerComponent player, Vector2 dir) {
    switch (skill.shape) {
      case SkillShape.melee:
        player.basicAttackTo(dir);
      case SkillShape.projectile:
        player.castProjectileTo(dir);
      case SkillShape.aoe:
        player.castAoeAt(player.center + dir * 60);
    }
  }

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

    final sid = cooldownSkillId;
    if (sid != null && cooldownTotal > 0) {
      final frac =
          game.orchestrator.cooldownsOf('player').fraction(sid, cooldownTotal);
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
