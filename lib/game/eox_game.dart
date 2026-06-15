import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';

import '../data/reference_skills.dart';
import '../engine/combat/combat_engine_api.dart';
import '../engine/combat/models.dart';
import '../engine/core/seeded_rng.dart';
import '../engine/core/vec2.dart';
import '../engine/combat/reference_combat_engine.dart';
import '../engine/entity/entity_state.dart';
import '../engine/world/aabb.dart';
import '../engine/world/nav_grid.dart';
import 'components/combat_entity_component.dart';
import 'components/damage_text_component.dart';
import 'components/monster_component.dart';
import 'components/overhead_opacity_component.dart';
import 'components/player_component.dart';
import 'game_orchestrator.dart';
import 'hud/hud_components.dart';
import 'map/map_loader.dart';

class EoxGame extends FlameGame with HasCollisionDetection {
  static const kOverheadPriority = 100000;
  static const _navCell = 16.0;

  @override
  Color backgroundColor() => const Color(0xFF1A1A2E);

  EoxGame({CombatEngineApi? engine, this.mapName = 'dev_arena.tmx'})
      : orchestrator = GameOrchestrator(
          engine ?? ReferenceCombatEngine(SeededRng(42)),
        );

  final GameOrchestrator orchestrator;
  final String mapName;

  late LoadedMap map;
  late NavGrid navGrid;
  PlayerComponent? player;
  OverheadOpacityComponent? _overheadWrap;

  final List<CombatEntityComponent> entityComponents = [];
  final Map<String, CombatEntityComponent> _byId = {};
  StreamSubscription<CombatEvent>? _combatSub;
  final List<SkillButton> _hudButtons = [];

  SkillDef? selectedSkill;
  String? selectedSkillId;
  _RangeCircle? _rangeCircle;

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
    }

    camera.follow(p, maxSpeed: 600, snap: true);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, map.sizePx.x, map.sizePx.y),
      considerViewport: true,
    );

    _buildHud(p);
    _addViewportTapHandler();
    _combatSub = orchestrator.combatStream.listen(_onCombatEvent);
  }

  void _addViewportTapHandler() {
    camera.viewport.add(_ViewportTapHandler());
  }

  void selectSkill(SkillDef skill, String skillId) {
    selectedSkill = skill;
    selectedSkillId = skillId;
  }

  void fireSelectedSkill(Vector2 worldTarget) {
    final p = player;
    if (p == null || selectedSkill == null) return;

    switch (selectedSkill!.shape) {
      case SkillShape.melee:
        final dir = (worldTarget - p.center).normalized();
        p.basicAttackTo(dir);
      case SkillShape.projectile:
        final dir = (worldTarget - p.center).normalized();
        p.castProjectileTo(dir);
      case SkillShape.aoe:
        p.castNova();
    }

    _clearSelection();
    selectedSkill = null;
    selectedSkillId = null;
  }

  void _buildHud(PlayerComponent p) {
    final joystick = buildJoystick();
    p.joystick = joystick;
    camera.viewport.add(joystick);

    _hudButtons.clear();

    _hudButtons.add(SkillButton(
      label: 'ATK', dx: 60, dy: 60, radius: 34,
      cooldownSkillId: ReferenceSkills.basicSlash.id,
      cooldownTotal: ReferenceSkills.basicSlash.cooldownSeconds,
      onPressed: () => _tapSkill(ReferenceSkills.basicSlash),
    ));
    _hudButtons.add(SkillButton(
      label: 'FIRE', dx: 140, dy: 50,
      cooldownSkillId: ReferenceSkills.fireball.id,
      cooldownTotal: ReferenceSkills.fireball.cooldownSeconds,
      onPressed: () => _tapSkill(ReferenceSkills.fireball),
    ));
    _hudButtons.add(SkillButton(
      label: 'NOVA', dx: 110, dy: 120,
      cooldownSkillId: ReferenceSkills.nova.id,
      cooldownTotal: ReferenceSkills.nova.cooldownSeconds,
      onPressed: () => _tapSkill(ReferenceSkills.nova),
    ));
    _hudButtons.add(SkillButton(
      label: 'DODGE', dx: 50, dy: 140,
      cooldownSkillId: 'sys_dodge',
      cooldownTotal: PlayerComponent.dodgeCooldown,
      onPressed: () {
        _clearSelection();
        selectedSkill = null;
        player?.dodge();
      },
    ));

    camera.viewport.addAll(_hudButtons);
    _repositionHud();
  }

  void _tapSkill(SkillDef skill) {
    if (selectedSkill?.id == skill.id) {
      _clearSelection();
      final p = player;
      if (p != null) {
        switch (skill.shape) {
          case SkillShape.melee: p.basicAttack();
          case SkillShape.projectile: p.castFireball();
          case SkillShape.aoe: p.castNova();
        }
      }
      return;
    }
    _clearSelection();
    selectSkill(skill, skill.id);
    for (final btn in _hudButtons) {
      if (btn.cooldownSkillId == skill.id) {
        btn.isSelected = true;
      }
    }
    _showRangeCircle(skill.range > 0 ? skill.range : skill.aoeRadius > 0 ? skill.aoeRadius : 320);
  }

  void _showRangeCircle(double radius) {
    _rangeCircle?.removeFromParent();
    _rangeCircle = _RangeCircle(radius: radius);
    world.add(_rangeCircle!);
  }

  void _clearSelection() {
    for (final btn in _hudButtons) {
      btn.isSelected = false;
    }
    _rangeCircle?.removeFromParent();
    _rangeCircle = null;
  }

  void _repositionHud() {
    if (size.x <= 0 || size.y <= 0) return;
    for (final btn in _hudButtons) {
      btn.position = Vector2(size.x - btn.dx, size.y - btn.dy);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _repositionHud();
  }

  @override
  void update(double dt) {
    super.update(dt);
    orchestrator.tick(dt);

    _rangeCircle?.follow(player?.center ?? Vector2.zero());

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

  void _onCombatEvent(CombatEvent e) {
    if (e is DotDamageEvent) {
      final target = _byId[e.targetId];
      if (target == null) return;
      world.add(DamageTextComponent.dot(e.damage, target.center - Vector2(0, 30)));
      if (e.killed) {
        target.changeState(EntityState.die);
        target.onDeath();
      }
    }
  }

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
      if (x >= s.left && x <= s.right && y >= s.top && y <= s.bottom) return true;
    }
    return false;
  }

  Vector2 moveWithCollision(CombatEntityComponent e, Vector2 delta) {
    final off = e.collOffset;
    final feet = Aabb(e.position.x + off.x, e.position.y + off.y,
        CombatEntityComponent.collW, CombatEntityComponent.collH);
    final resolved = resolveAabbMovement(feet, Vec2(delta.x, delta.y), map.collisions);
    return Vector2(resolved.x - off.x, resolved.y - off.y);
  }

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

  void onPlayerDeath() => overlays.add('death');

  void respawnPlayer() {
    overlays.remove('death');
    player?.respawn(map.playerSpawn.clone());
  }

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

class _ViewportTapHandler extends PositionComponent
    with TapCallbacks, HasGameReference<EoxGame> {
  _ViewportTapHandler()
      : super(size: Vector2.all(4000), position: Vector2.zero(), priority: -50000);

  @override
  void render(Canvas canvas) {}

  @override
  void onTapDown(TapDownEvent event) {
    final eox = game;
    if (eox.selectedSkill == null) return;

    final p = eox.player;
    if (p == null) return;

    final viewportPos = event.localPosition;
    final camCenter = eox.camera.viewfinder.position;
    final center = eox.size / 2;
    final worldPos = viewportPos + camCenter - center;

    final dist = worldPos.distanceTo(p.center);
    final range = eox.selectedSkill!.range > 0 ? eox.selectedSkill!.range : 320.0;
    if (dist > range) return;

    eox.fireSelectedSkill(worldPos);
  }
}

class _RangeCircle extends PositionComponent {
  final double radius;

  _RangeCircle({required this.radius})
      : super(
          size: Vector2.all(radius * 2),
          anchor: Anchor.center,
          priority: 30000,
        );

  void follow(Vector2 target) {
    position.setFrom(target);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final r = size.x / 2;
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..color = const Color(0x22FF4444)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..color = const Color(0x88FF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
