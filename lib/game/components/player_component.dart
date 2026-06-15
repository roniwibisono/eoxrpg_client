import 'package:flame/components.dart';

import '../../data/reference_skills.dart';
import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../../engine/entity/entity_state.dart';
import 'combat_entity_component.dart';
import 'hitbox_components.dart';

/// Player: continuous joystick + per-frame AABB resolve (D2). Never A*.
class PlayerComponent extends CombatEntityComponent {
  PlayerComponent({required super.position})
      : super(
          entityId: 'player',
          team: Team.player,
          sheetBasePath: 'characters/human',
          // PLACEHOLDER stats — real values come from GameConfig/CDN (GDD §5)
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

  static const _runThreshold = 0.85; // joystick intensity → run
  static const dodgeCooldown = 1.2; // PLACEHOLDER
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
      // movement cannot cancel attack/cast (GDD §6.4) — but we keep the
      // requested facing for the next action.
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

  // ── Actions (HUD buttons) ────────────────────────────────────────────
  void basicAttack() {
    if (fsm.isDead || isDodging) return;
    final skill = ReferenceSkills.basicSlash;
    if (!changeState(EntityState.basicAttack)) return;
    final castId = game.orchestrator.beginCast(entityId, skill);
    if (castId == null) {
      fsm.notifyActionComplete();
      changeState(EntityState.idle);
      return;
    }
    // Damage on IMPACT FRAME (GDD §6.2), not on press.
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

  void castFireball() => _castReleaseSkill(ReferenceSkills.fireball);

  void _castReleaseSkill(SkillDef skill) {
    if (fsm.isDead || isDodging) return;
    // Check BEFORE locking the animation so a failed cast doesn't freeze us.
    if (!game.orchestrator.cooldownsOf(entityId).isReady(skill.id)) return;
    final e = game.orchestrator.entity(entityId);
    if (e == null || e.mp < skill.mpCost) return;
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
        directionUnit: directionUnitVector(facing),
      ));
    };
  }

  void castNova() {
    final skill = ReferenceSkills.nova;
    if (fsm.isDead || isDodging) return;
    if (!game.orchestrator.cooldownsOf(entityId).isReady(skill.id)) return;
    final e = game.orchestrator.entity(entityId);
    if (e == null || e.mp < skill.mpCost) return;
    if (!changeState(EntityState.castSkill)) return;
    final castId = game.orchestrator.beginCast(entityId, skill);
    if (castId == null) {
      fsm.notifyActionComplete();
      changeState(EntityState.idle);
      return;
    }
    // AoE spawns at CAST START; its own active window models "hitbox aktif
    // frame 3–5" of the cast animation (Combat v2 §5.1).
    game.world.add(AoeExplosionComponent(
      castId: castId,
      casterId: entityId,
      casterTeam: team,
      skill: skill,
      centerPos: center,
    ));
  }

  void dodge() {
    if (fsm.isDead || isDodging || fsm.isActing) return;
    final cd = game.orchestrator.cooldownsOf(entityId);
    if (!cd.isReady(_dodgeSkillId)) return;
    cd.trigger(_dodgeSkillId, dodgeCooldown);
    _dodgeTimer = _dodgeDuration;
    runtime.invulnerable = true; // Combat v2 dodge i-frames
    final j = joystick;
    final rel = j == null ? Vector2.zero() : j.relativeDelta;
    _dodgeDir = rel.length > 0.05
        ? rel.normalized()
        : directionUnitVector(facing);
    changeState(EntityState.run);
  }

  @override
  void onDeath() {
    runtime.invulnerable = false;
    _dodgeTimer = 0;
    game.onPlayerDeath();
  }

  /// Respawn = fresh runtime + fresh FSM (die-lock is permanent by design,
  /// so respawning replaces the machine instead of bypassing the rule).
  void respawn(Vector2 at) {
    game.orchestrator.unregister(entityId);
    runtime = game.orchestrator.register(entityId, statsDef);
    fsm = EntityStateMachine();
    position.setFrom(at);
    facing = Direction8.down;
    changeState(EntityState.idle);
  }
}
