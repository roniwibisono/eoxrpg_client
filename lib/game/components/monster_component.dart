import 'package:flame/components.dart';

import '../../data/reference_skills.dart';
import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../../engine/entity/entity_state.dart';
import 'combat_entity_component.dart';
import 'hitbox_components.dart';
import 'player_component.dart';

enum MonsterAi { idle, chase, attack, dead }

/// Monster AI per Combat v2 §10 summary: idle → aggro → A* chase → attack
/// in range → die. A* repath every [_repathInterval]; movement is still
/// AABB-resolved so monsters cannot clip walls between waypoints.
class MonsterComponent extends CombatEntityComponent {
  final String monsterId;
  final Vector2 spawnPoint;

  // position is used in the initializer list (spawnPoint), so it cannot be
  // a super parameter.
  // ignore: use_super_parameters
  MonsterComponent({
    required this.monsterId,
    required Vector2 position,
    String? instanceId,
  })  : spawnPoint = position.clone(),
        // ignore: prefer_initializing_formals
        super(
          entityId: instanceId ?? 'mon_${monsterId}_${_seq++}',
          team: Team.enemy,
          sheetBasePath: 'monsters/$monsterId',
          // PLACEHOLDER stats — real values: monster_master.json (GDD §5)
          statsDef: const CombatantStats(
            maxHp: 46,
            maxMp: 10,
            atk: 8,
            def: 3,
            critChance: 0.05,
            dodgeChance: 0.03,
            moveSpeed: 80,
          ),
          position: position,
        );

  static int _seq = 0;

  // PLACEHOLDER tuning values (playtest-tune, D9)
  static const aggroRadius = 170.0;
  static const deaggroRadius = 360.0;
  static const _repathInterval = 0.5;
  static const _despawnAfterDeath = 1.6;

  MonsterAi ai = MonsterAi.idle;
  final List<Vector2> _waypoints = [];
  double _repathTimer = 0;
  double _deathTimer = 0;

  SkillDef get attackSkill => ReferenceSkills.slimeBite;

  @override
  void update(double dt) {
    super.update(dt);

    if (ai == MonsterAi.dead) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) {
        game.scheduleMonsterRespawn(monsterId, spawnPoint);
        removeFromParent();
      }
      return;
    }
    if (runtime.dead) return; // transition handled in onDeath

    final player = game.player;
    if (player == null || player.fsm.isDead) {
      ai = MonsterAi.idle;
      if (!fsm.isActing) changeState(EntityState.idle);
      return;
    }

    final toPlayer = player.center - center;
    final dist = toPlayer.length;

    switch (ai) {
      case MonsterAi.idle:
        if (dist <= aggroRadius) {
          ai = MonsterAi.chase;
          _repathTimer = 0;
        }
      case MonsterAi.chase:
        if (dist > deaggroRadius) {
          ai = MonsterAi.idle;
          _waypoints.clear();
          changeState(EntityState.idle);
          break;
        }
        if (dist <= attackSkill.range * 0.9) {
          ai = MonsterAi.attack;
          break;
        }
        _chase(dt, player);
      case MonsterAi.attack:
        if (dist > attackSkill.range * 1.15) {
          ai = MonsterAi.chase;
          break;
        }
        _tryAttack(player);
      case MonsterAi.dead:
        break;
    }
  }

  void _chase(double dt, PlayerComponent player) {
    _repathTimer -= dt;
    if (_repathTimer <= 0) {
      _repathTimer = _repathInterval;
      _waypoints
        ..clear()
        ..addAll(game.findPathWorld(center, player.center));
    }
    Vector2 target;
    if (_waypoints.isNotEmpty) {
      target = _waypoints.first;
      if ((target - center).length < 6) {
        _waypoints.removeAt(0);
        if (_waypoints.isEmpty) return;
        target = _waypoints.first;
      }
    } else {
      // direct pursuit fallback (path unavailable / same cell)
      target = player.center;
    }

    final dir = (target - center)..normalize();
    final face = Direction8.fromVector(dir.x, dir.y, fallback: facing);
    if (fsm.isActing || fsm.state == EntityState.hit) return;
    changeState(EntityState.walk, face: face);
    updateFacing(face);
    final delta =
        dir * runtime.stats.moveSpeed * runtime.moveSpeedMultiplier * dt;
    position.setFrom(game.moveWithCollision(this, delta));
  }

  void _tryAttack(PlayerComponent player) {
    if (fsm.isActing || fsm.state == EntityState.hit) return;
    final toPlayer = player.center - center;
    final face = Direction8.fromVector(toPlayer.x, toPlayer.y, fallback: facing);
    if (!changeState(EntityState.basicAttack, face: face)) return;
    final castId = game.orchestrator.beginCast(entityId, attackSkill);
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
        skill: attackSkill,
        casterCenter: center,
        facing: facing,
      ));
    };
  }

  @override
  void onDeath() {
    ai = MonsterAi.dead;
    _deathTimer = _despawnAfterDeath;
    // Phase 4 hook: loot / EXP event would be emitted here.
  }
}
