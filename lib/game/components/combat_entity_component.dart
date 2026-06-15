import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/combat/models.dart';
import '../../engine/entity/direction.dart';
import '../../engine/entity/entity_state.dart';
import '../assets/character_sheet_loader.dart';
import '../eox_game.dart';

enum Team { player, enemy }

/// Shared base for Player & Monster (GDD §6.4: one state machine, one
/// animation contract). View-only: all combat math lives behind
/// GameOrchestrator (D8).
abstract class CombatEntityComponent
    extends SpriteAnimationGroupComponent<AnimKey>
    with HasGameReference<EoxGame> {
  final String entityId;
  final Team team;
  final String sheetBasePath;
  final CombatantStats statsDef;

  EntityStateMachine fsm = EntityStateMachine();
  Direction8 facing = Direction8.down;
  late CombatantRuntime runtime;

  /// Fired on the animation impact frame of basicAttack/castSkill
  /// (GDD §6.2: melee basic attack damages on the IMPACT FRAME via
  /// animationTicker.onFrame, not on button press).
  void Function()? onImpactFrame;

  /// Logical collision box used for AABB world-collision (feet box),
  /// smaller than the 64×64 sprite. Offset relative to component top-left.
  static const collW = 26.0;
  static const collH = 18.0;
  Vector2 get collOffset => Vector2((size.x - collW) / 2, size.y - collH - 4);

  CombatEntityComponent({
    required this.entityId,
    required this.team,
    required this.sheetBasePath,
    required this.statsDef,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(kFrameSize),
          anchor: Anchor.topLeft,
        );

  bool get showHpBar => team == Team.enemy;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    runtime = game.orchestrator.register(entityId, statsDef);
    game.registerEntityComponent(this);

    animations = await CharacterSheetLoader(game.images).load(sheetBasePath);
    current = (EntityState.idle, facing);

    // Hurtbox for hitbox/projectile contact (D8). Passive: it never
    // initiates damage itself.
    add(RectangleHitbox(
      position: Vector2(size.x / 2 - 14, size.y / 2 - 10),
      size: Vector2(28, 36),
      collisionType: CollisionType.passive,
    ));

    _wireTickers();
  }

  void _wireTickers() {
    final tickers = animationTickers;
    if (tickers == null) return;
    for (final entry in tickers.entries) {
      final (state, _) = entry.key;
      final spec = kAnimSpecs[state]!;
      if (spec.impactFrame != null) {
        entry.value.onFrame = (i) {
          if (i == spec.impactFrame && current?.$1 == state) {
            onImpactFrame?.call();
          }
        };
      }
      if (!spec.loop && state != EntityState.die) {
        entry.value.onComplete = () {
          if (current?.$1 == state) {
            fsm.notifyActionComplete();
            _applyCurrent();
          }
        };
      }
    }
  }

  /// Single entry point for state changes — keeps FSM and animation in sync.
  /// Non-looping states (attack/cast/hit/die) restart from frame 0 on entry.
  bool changeState(EntityState next, {Direction8? face}) {
    if (face != null) facing = face;
    final ok = fsm.tryTransition(next);
    if (!ok) return false;
    _applyCurrent(restart: _isRestartable(fsm.state));
    return true;
  }

  void updateFacing(Direction8 face) {
    if (facing == face) return;
    facing = face;
    _applyCurrent();
  }

  static bool _isRestartable(EntityState s) =>
      s == EntityState.basicAttack ||
      s == EntityState.castSkill ||
      s == EntityState.hit ||
      s == EntityState.die;

  void _applyCurrent({bool restart = false}) {
    final key = (fsm.state, facing);
    if (current != key) current = key;
    if (restart) animationTickers?[key]?.reset();
  }

  /// Visual reaction to an AttackResult that targeted this entity.
  void onDamaged(AttackResult result) {
    if (result.killed) {
      changeState(EntityState.die);
      onDeath();
      return;
    }
    if (result.outcome == AttackOutcome.hit ||
        result.outcome == AttackOutcome.crit) {
      changeState(EntityState.hit);
    }
  }

  /// Subclasses: cleanup / respawn / overlay logic.
  void onDeath();

  @override
  void update(double dt) {
    super.update(dt);
    // y-sort between ground (0) and overhead (kOverheadPriority).
    priority =
        (position.y + size.y).toInt().clamp(1, EoxGame.kOverheadPriority - 1);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (showHpBar && !runtime.dead) {
      const w = 36.0;
      const h = 4.0;
      final x = (size.x - w) / 2;
      const y = -2.0;
      final frac = (runtime.hp / runtime.stats.maxHp).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()..color = const Color(0xAA000000),
      );
      canvas.drawRect(
        Rect.fromLTWH(x, y, w * frac, h),
        Paint()..color = const Color(0xFFE53935),
      );
    }
  }

  @override
  void onRemove() {
    game.unregisterEntityComponent(this);
    game.orchestrator.unregister(entityId);
    super.onRemove();
  }
}
