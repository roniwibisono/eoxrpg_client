import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';

import '../data/reference_skills.dart';
import '../engine/combat/combat_engine_api.dart';
import '../engine/combat/models.dart';
import '../engine/core/seeded_rng.dart';
import '../engine/core/vec2.dart';
import '../engine/combat/reference_combat_engine.dart';
import '../engine/world/aabb.dart';
import '../engine/world/nav_grid.dart';
import 'components/combat_entity_component.dart';
import 'components/damage_text_component.dart';
import 'components/monster_component.dart';
import 'components/overhead_opacity_component.dart';
import 'components/player_component.dart';
import '../engine/entity/entity_state.dart';
import 'game_orchestrator.dart';
import 'hud/hud_components.dart';
import 'map/map_loader.dart';
import 'skills/skill_aim_controller.dart';
import 'skills/aim_indicator.dart';

class EoxGame extends FlameGame with HasCollisionDetection {
  static const kOverheadPriority = 100000;
  static const _navCell = 16.0;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  EoxGame({CombatEngineApi? engine, this.mapName = 'dev_arena.tmx'})
      : orchestrator = GameOrchestrator(
          // ⚠️ ReferenceCombatEngine = PLACEHOLDER formulas. Swap this line
          // for the adapter over the real CombatEngine v2 (see
          // combat_engine_api.dart and INTEGRATION.md).
          engine ?? ReferenceCombatEngine(SeededRng(42)),
        );

  final GameOrchestrator orchestrator;
  final String mapName;
  final SkillAimController aimController = SkillAimController();
  AimIndicatorManager? _aimIndicatorManager;

  late LoadedMap map;
  late NavGrid navGrid;
  PlayerComponent? player;
  OverheadOpacityComponent? _overheadWrap;

  final List<CombatEntityComponent> entityComponents = [];
  final Map<String, CombatEntityComponent> _byId = {};
  StreamSubscription<CombatEvent>? _combatSub;

  // ── Lifecycle ───────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    map = await MapLoader.load(mapName);
    world.add(map.ground);
    _overheadWrap = OverheadOpacityComponent(
      child: map.overhead,
      priority: kOverheadPriority,
    );
    world.add(_overheadWrap!);

    navGrid = NavGrid.fromCollision(
      worldWidth: map.sizePx.x,
      worldHeight: map.sizePx.y,
      cellSize: _navCell,
      solids: map.collisions,
    );

    final p = PlayerComponent(position: map.playerSpawn.clone());
    player = p;
    world.add(p);

    for (final s in map.spawns) {
      final monsterId = s.monsterId;
      if (monsterId != null) {
        world.add(MonsterComponent(monsterId: monsterId, position: s.position));
      }
      // npcId spawns: Phase 4+ scope — intentionally not handled here.
    }

    camera.follow(p, maxSpeed: 600, snap: true);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, map.sizePx.x, map.sizePx.y),
      considerViewport: true,
    );

    _buildHud(p);

    _aimIndicatorManager = AimIndicatorManager(aimController);
    world.add(_aimIndicatorManager!);

    _combatSub = orchestrator.combatStream.listen(_onCombatEvent);
  }

  void _buildHud(PlayerComponent p) {
    final joystick = buildJoystick();
    p.joystick = joystick;
    camera.viewport.add(joystick);

    Vector2 corner(double dx, double dy) =>
        Vector2(size.x - dx, size.y - dy);

    camera.viewport.addAll([
      SkillButton(
        label: 'ATK',
        skill: ReferenceSkills.basicSlash,
        skillId: ReferenceSkills.basicSlash.id,
        position: corner(60, 60),
        radius: 34,
        cooldownSkillId: ReferenceSkills.basicSlash.id,
        cooldownTotal: ReferenceSkills.basicSlash.cooldownSeconds,
      ),
      SkillButton(
        label: 'FIRE',
        skill: ReferenceSkills.fireball,
        skillId: ReferenceSkills.fireball.id,
        position: corner(140, 50),
        cooldownSkillId: ReferenceSkills.fireball.id,
        cooldownTotal: ReferenceSkills.fireball.cooldownSeconds,
      ),
      SkillButton(
        label: 'NOVA',
        skill: ReferenceSkills.nova,
        skillId: ReferenceSkills.nova.id,
        position: corner(110, 120),
        cooldownSkillId: ReferenceSkills.nova.id,
        cooldownTotal: ReferenceSkills.nova.cooldownSeconds,
      ),
      SkillButton(
        label: 'DODGE',
        skill: ReferenceSkills.basicSlash,
        skillId: 'sys_dodge',
        position: corner(50, 140),
        cooldownSkillId: 'sys_dodge',
        cooldownTotal: PlayerComponent.dodgeCooldown,
        onTap: () => player?.dodge(),
      ),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    orchestrator.tick(dt);

    if (aimController.state == SkillAimState.aiming) {
      final p = player;
      if (p != null) {
        p.aiming = true;
        p.updateFacingFromVector(aimController.aimDirection);
      }
    } else {
      player?.aiming = false;
    }

    final p = player;
    final wrap = _overheadWrap;
    if (p != null && wrap != null) {
      final feet = p.center + Vector2(0, p.size.y * 0.25);
      wrap.targetOpacity = map.hasOverheadAt(feet.x, feet.y)
          ? OverheadOpacityComponent.fadedOpacity
          : 1.0;
    }
  }

  @override
  void onRemove() {
    _combatSub?.cancel();
    orchestrator.dispose();
    super.onRemove();
  }

  // ── Domain event routing ────────────────────────────────────────────
  void _onCombatEvent(CombatEvent e) {
    if (e is DotDamageEvent) {
      final target = _byId[e.targetId];
      if (target == null) return;
      world.add(
          DamageTextComponent.dot(e.damage, target.center - Vector2(0, 30)));
      if (e.killed) {
        target.changeState(EntityState.die);
        target.onDeath();
      }
    }
    // DeathEvent from direct hits is already visualised via onDamaged.
  }

  // ── World queries / helpers ─────────────────────────────────────────
  void registerEntityComponent(CombatEntityComponent c) {
    entityComponents.add(c);
    _byId[c.entityId] = c;
  }

  void unregisterEntityComponent(CombatEntityComponent c) {
    entityComponents.remove(c);
    _byId.remove(c.entityId);
  }

  bool isPointBlocked(double x, double y) {
    for (final s in map.collisions) {
      if (x >= s.left && x <= s.right && y >= s.top && y <= s.bottom) {
        return true;
      }
    }
    return false;
  }

  /// AABB-resolved movement for an entity's FEET box (D2: push-out +
  /// wall-slide, pure function in engine/world/aabb.dart). Returns the new
  /// component top-left position.
  Vector2 moveWithCollision(CombatEntityComponent e, Vector2 delta) {
    final off = e.collOffset;
    final feet = Aabb(
      e.position.x + off.x,
      e.position.y + off.y,
      CombatEntityComponent.collW,
      CombatEntityComponent.collH,
    );
    final resolved =
        resolveAabbMovement(feet, Vec2(delta.x, delta.y), map.collisions);
    return Vector2(resolved.x - off.x, resolved.y - off.y);
  }

  /// A* in world coordinates — MONSTERS ONLY (D2).
  List<Vector2> findPathWorld(Vector2 from, Vector2 to) {
    final start = navGrid.worldToCell(from.x, from.y);
    final goal = navGrid.worldToCell(to.x, to.y);
    final cells = navGrid.findPath(start, goal);
    if (cells == null) return const [];
    return cells.map((c) {
      final (x, y) = navGrid.cellCenter(c.$1, c.$2);
      return Vector2(x, y);
    }).toList();
  }

  // ── Player death / respawn ──────────────────────────────────────────
  void onPlayerDeath() {
    overlays.add('death');
  }

  void respawnPlayer() {
    overlays.remove('death');
    player?.respawn(map.playerSpawn.clone());
  }

  // ── Monster respawn (testing-friendly loop) ─────────────────────────
  static const _monsterRespawnDelay = 8.0;

  void scheduleMonsterRespawn(String monsterId, Vector2 at) {
    add(TimerComponent(
      period: _monsterRespawnDelay,
      removeOnFinish: true,
      onTick: () {
        world.add(MonsterComponent(monsterId: monsterId, position: at.clone()));
      },
    ));
  }
}
