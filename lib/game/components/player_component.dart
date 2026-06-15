import 'package:flame/components.dart';

import '../../data/reference_skills.dart';
import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../../engine/entity/entity_state.dart';
import 'combat_entity_component.dart';
import 'hitbox_components.dart';

class PlayerComponent extends CombatEntityComponent {
  PlayerComponent({required super.position})
      : super(
          entityId: 'player',
          team: Team.player,
          sheetBasePath: 'characters/human',
          statsDef: const CombatantStats(
            maxHp: 120,
            maxMp: 60,
            atk: 14,
            def: 6,
            critChance: 0.15,
            dodgeChance: 0.05,
            moveSpeed: 140,
            mpRegenPerSecond: 2.5,
          ),
        );

  JoystickComponent? joystick;
  bool aiming = false;

  static const _runThreshold = 0.85;
  static const dodgeCooldown = 1.2;
  static const _dodgeDuration = 0.25;
  static const _dodgeSpeed = 380.0;
  static const _dodgeSkillId = 'sys_dodge';

  double _dodgeTimer = 0;
  Vector2 _dodgeDir = Vector2.zero();

  bool get isDodging => _dodgeTimer > 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (fsm.isDead) return;

    if (_dodgeTimer > 0) {
      _dodgeTimer -= dt;
      final delta = _dodgeDir * _dodgeSpeed * dt;
      position.setFrom(game.moveWithCollision(this, delta));
      if (_dodgeTimer <= 0) {
        runtime.invulnerable = false;
      }
      return;
    }

    if (aiming) return;

    final j = joystick;
    if (j == null) return;
    final rel = j.relativeDelta;
    final intensity = rel.length;

    if (intensity < 0.05) {
      if (!fsm.isActing && fsm.state != EntityState.hit) {
        changeState(EntityState.idle);
      }
      return;
    }

    final face = Direction8.fromVector(rel.x, rel.y, fallback: facing);
    if (fsm.isActing || fsm.state == EntityState.hit) {
      return;
    }

    final running = intensity >= _runThreshold;
    changeState(running ? EntityState.run : EntityState.walk, face: face);
    updateFacing(face);

    final speed = runtime.stats.moveSpeed *
        (running ? 1.0 : 0.65) *
        runtime.moveSpeedMultiplier;
    final delta = Vector2(rel.x, rel.y).normalized() * speed * dt * intensity.clamp(0.4, 1.0);
    position.setFrom(game.moveWithCollision(this, delta));
  }

  void basicAttack() {
    basicAttackTo(directionUnitVector(facing));
  }

  void basicAttackTo(Vector2 dir) {
    if (fsm.isDead || isDodging) return;
    final skill = ReferenceSkills.basicSlash;
    updateFacingFromVector(dir);
    if (!changeState(EntityState.basicAttack)) return;
    final castId = game.orchestrator.beginCast(entityId, skill);
    if (castId == null) {
      fsm.notifyActionComplete();
      changeState(EntityState.idle);
      return;
    }
    onImpactFrame = () {
      onImpactFrame = null;
      game.world.add(ArcHitboxComponent(
        castId: castId,
        casterId: entityId,
        casterTeam: team,
        skill: skill,
        casterCenter: center,
        facing: facing,
      ));
    };
  }

  void castFireball() {
    castProjectileTo(directionUnitVector(facing));
  }

  void castProjectileTo(Vector2 dir) {
    final skill = ReferenceSkills.fireball;
    if (fsm.isDead || isDodging) return;
    if (!game.orchestrator.cooldownsOf(entityId).isReady(skill.id)) return;
    final e = game.orchestrator.entity(entityId);
    if (e == null || e.mp < skill.mpCost) return;
    updateFacingFromVector(dir);
    if (!changeState(EntityState.castSkill)) return;
    final castId = game.orchestrator.beginCast(entityId, skill);
    if (castId == null) {
      fsm.notifyActionComplete();
      changeState(EntityState.idle);
      return;
    }
    onImpactFrame = () {
      onImpactFrame = null;
      game.world.add(ProjectileComponent(
        castId: castId,
        casterId: entityId,
        casterTeam: team,
        skill: skill,
        origin: center,
        directionUnit: dir.normalized(),
      ));
    };
  }

  void castNova() {
    castAoeAt(center);
  }

  void castAoeAt(Vector2 targetPos) {
    final skill = ReferenceSkills.nova;
    if (fsm.isDead || isDodging) return;
    if (!game.orchestrator.cooldownsOf(entityId).isReady(skill.id)) return;
    final e = game.orchestrator.entity(entityId);
    if (e == null || e.mp < skill.mpCost) return;
    if (targetPos != center) {
      updateFacingFromVector((targetPos - center).normalized());
    }
    if (!changeState(EntityState.castSkill)) return;
    final castId = game.orchestrator.beginCast(entityId, skill);
    if (castId == null) {
      fsm.notifyActionComplete();
      changeState(EntityState.idle);
      return;
    }
    game.world.add(AoeExplosionComponent(
      castId: castId,
      casterId: entityId,
      casterTeam: team,
      skill: skill,
      centerPos: targetPos,
    ));
  }

  void dodge() {
    if (fsm.isDead || isDodging || fsm.isActing) return;
    final cd = game.orchestrator.cooldownsOf(entityId);
    if (!cd.isReady(_dodgeSkillId)) return;
    cd.trigger(_dodgeSkillId, dodgeCooldown);
    _dodgeTimer = _dodgeDuration;
    runtime.invulnerable = true;
    final j = joystick;
    final rel = j == null ? Vector2.zero() : j.relativeDelta;
    _dodgeDir = rel.length > 0.05
        ? rel.normalized()
        : directionUnitVector(facing);
    changeState(EntityState.run);
  }

  void updateFacingFromVector(Vector2 dir) {
    facing = Direction8.fromVector(dir.x, dir.y, fallback: facing);
  }

  @override
  void onDeath() {
    runtime.invulnerable = false;
    _dodgeTimer = 0;
    game.onPlayerDeath();
  }

  void respawn(Vector2 at) {
    game.orchestrator.unregister(entityId);
    runtime = game.orchestrator.register(entityId, statsDef);
    fsm = EntityStateMachine();
    position.setFrom(at);
    facing = Direction8.down;
    changeState(EntityState.idle);
  }
}
