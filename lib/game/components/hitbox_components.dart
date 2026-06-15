import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../eox_game.dart';
import 'combat_entity_component.dart';
import 'damage_text_component.dart';

/// Shared contact logic (D8): a hitbox NEVER computes damage — it reports
/// contact to GameOrchestrator.onHitboxHit, which dedups and resolves.
mixin _HitReporter on Component, HasGameReference<EoxGame> {
  int get castId;
  String get casterId;
  Team get casterTeam;
  SkillDef get skill;

  void reportContact(CombatEntityComponent target) {
    if (target.team == casterTeam || target.entityId == casterId) return;
    final result = game.orchestrator.onHitboxHit(
      castId: castId,
      casterId: casterId,
      targetId: target.entityId,
      skill: skill,
    );
    if (result == null) return; // dedup or dead target
    game.world.add(DamageTextComponent.fromResult(
        result, target.center - Vector2(0, 30)));
    target.onDamaged(result);
  }
}

/// Melee arc hitbox: active ~0.15s in front of the caster
/// (Combat v2 §5.1 "arc/melee hitbox aktif ~0.15s").
class ArcHitboxComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<EoxGame>, _HitReporter {
  @override
  final int castId;
  @override
  final String casterId;
  @override
  final Team casterTeam;
  @override
  final SkillDef skill;

  static const activeDuration = 0.15;
  double _age = 0;

  ArcHitboxComponent({
    required this.castId,
    required this.casterId,
    required this.casterTeam,
    required this.skill,
    required Vector2 casterCenter,
    required Direction8 facing,
  }) : super(
          size: Vector2(skill.range, skill.range),
          anchor: Anchor.center,
          priority: EoxGame.kOverheadPriority,
        ) {
    final dir = _unitVector(facing);
    position = casterCenter + dir * (skill.range * 0.6);
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is CombatEntityComponent) reportContact(other);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= activeDuration) {
      game.orchestrator.releaseCast(castId);
      removeFromParent();
    }
  }
}

/// Projectile: travels until it hits an enemy, a wall (Collision layer),
/// or exceeds skill.range (Combat v2 §5.1 "projectile onCollide").
class ProjectileComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<EoxGame>, _HitReporter {
  @override
  final int castId;
  @override
  final String casterId;
  @override
  final Team casterTeam;
  @override
  final SkillDef skill;

  final Vector2 _velocity;
  double _travelled = 0;
  bool _spent = false;

  ProjectileComponent({
    required this.castId,
    required this.casterId,
    required this.casterTeam,
    required this.skill,
    required Vector2 origin,
    required Vector2 directionUnit,
  })  : _velocity = directionUnit * skill.projectileSpeed,
        super(
          position: origin.clone(),
          size: Vector2.all(14),
          anchor: Anchor.center,
          priority: EoxGame.kOverheadPriority,
        );

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(collisionType: CollisionType.active));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (_spent) return;
    if (other is CombatEntityComponent &&
        other.team != casterTeam &&
        !other.runtime.dead) {
      reportContact(other);
      _despawn();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_spent) return;
    final step = _velocity * dt;
    position += step;
    _travelled += step.length;

    // Wall check vs the Tiled Collision layer rectangles.
    if (game.isPointBlocked(position.x, position.y)) {
      _despawn();
      return;
    }
    if (_travelled >= skill.range) _despawn();
  }

  void _despawn() {
    if (_spent) return;
    _spent = true;
    game.orchestrator.releaseCast(castId);
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = const Color(0xFFFF7043),
    );
  }
}

/// Self-centered AoE: hitbox active during frames ~3–5 of the cast
/// (Combat v2 §5.1: "AoE hitbox aktif frame 3–5"). Implemented as a delayed
/// activation window; contact uses radius distance vs entity centers, which
/// is equivalent to a circular hitbox for a static explosion and avoids a
/// one-frame collision-detection registration race for short-lived shapes.
class AoeExplosionComponent extends PositionComponent
    with HasGameReference<EoxGame>, _HitReporter {
  @override
  final int castId;
  @override
  final String casterId;
  @override
  final Team casterTeam;
  @override
  final SkillDef skill;

  /// Active window in seconds, mirroring frames 3–5 at the castSkill
  /// stepTime (0.09s): [0.27 .. 0.45].
  static const activeFrom = 0.27;
  static const activeUntil = 0.45;

  double _age = 0;

  AoeExplosionComponent({
    required this.castId,
    required this.casterId,
    required this.casterTeam,
    required this.skill,
    required Vector2 centerPos,
  }) : super(
          position: centerPos.clone(),
          size: Vector2.all(skill.aoeRadius * 2),
          anchor: Anchor.center,
          priority: EoxGame.kOverheadPriority,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= activeFrom && _age <= activeUntil) {
      for (final target in game.entityComponents) {
        if (target.team == casterTeam || target.runtime.dead) continue;
        final d = (target.center - position).length;
        if (d <= skill.aoeRadius) {
          reportContact(target); // dedup makes repeats per-frame safe
        }
      }
    }
    if (_age > activeUntil + 0.15) {
      game.orchestrator.releaseCast(castId);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = (_age / activeUntil).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      skill.aoeRadius * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF80D8FF).withValues(alpha: 1.0 - t),
    );
  }
}

Vector2 _unitVector(Direction8 d) {
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

/// Public helper for components that need a facing unit vector.
Vector2 directionUnitVector(Direction8 d) => _unitVector(d);
