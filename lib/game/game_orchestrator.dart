import 'dart:async';

import '../engine/combat/combat_engine_api.dart';
import '../engine/combat/cooldown_and_dedup.dart';
import '../engine/combat/models.dart';

/// GDD §6.1 — the ONLY bridge between Flame (view) and the combat domain.
///
/// Non-negotiable principle (D8): Flame components NEVER compute damage.
/// When a hitbox/projectile touches a target it calls [onHitboxHit]; the
/// orchestrator deduplicates, calls CombatEngineApi.resolveHit, then
/// broadcasts the AttackResult on [combatStream] for:
///   * Flame components (damage text, hit/die animations)
///   * the Flutter overlay (HP/MP bars)
/// PvE-online later = swap this class's resolveHit call for a server call.
class GameOrchestrator {
  final CombatEngineApi engine;
  GameOrchestrator(this.engine);

  final Map<String, CombatantRuntime> _entities = {};
  final Map<String, CooldownManager> _cooldowns = {};
  final HitDedup _dedup = HitDedup();

  final _combatController = StreamController<CombatEvent>.broadcast();
  final _attackController = StreamController<AttackResult>.broadcast();

  Stream<CombatEvent> get combatStream => _combatController.stream;
  Stream<AttackResult> get attackStream => _attackController.stream;

  int _castCounter = 0;

  // ── Entity registry ──────────────────────────────────────────────────
  CombatantRuntime register(String id, CombatantStats stats) {
    final rt = CombatantRuntime(id: id, stats: stats);
    _entities[id] = rt;
    _cooldowns[id] = CooldownManager();
    return rt;
  }

  void unregister(String id) {
    _entities.remove(id);
    _cooldowns.remove(id);
  }

  CombatantRuntime? entity(String id) => _entities[id];
  CooldownManager cooldownsOf(String id) =>
      _cooldowns.putIfAbsent(id, CooldownManager.new);

  // ── Casting ──────────────────────────────────────────────────────────
  /// Returns a castId (>0) when the cast is allowed and costs were paid,
  /// or null when MP/cooldown/death rejects it. The COST is paid here, at
  /// cast time; DAMAGE happens later at hitbox contact (D8).
  int? beginCast(String casterId, SkillDef skill) {
    final caster = _entities[casterId];
    if (caster == null || caster.dead) return null;
    final cd = cooldownsOf(casterId);
    if (!cd.isReady(skill.id)) return null;
    if (!engine.canCast(caster, skill)) return null;
    engine.payCastCost(caster, skill);
    cd.trigger(skill.id, skill.cooldownSeconds);
    return ++_castCounter;
  }

  /// D8 entry point: hitbox/projectile contact. Dedup guarantees one
  /// damage application per (cast, target).
  AttackResult? onHitboxHit({
    required int castId,
    required String casterId,
    required String targetId,
    required SkillDef skill,
  }) {
    final caster = _entities[casterId];
    final target = _entities[targetId];
    if (caster == null || target == null) return null;
    if (target.dead) return null;
    if (!_dedup.register(castId, targetId)) return null;

    final result = engine.resolveHit(
      caster: caster,
      target: target,
      skill: skill,
    );
    _attackController.add(result);
    if (result.killed) {
      _combatController.add(DeathEvent(targetId));
    }
    return result;
  }

  void releaseCast(int castId) => _dedup.releaseCast(castId);

  // ── Frame tick ───────────────────────────────────────────────────────
  void tick(double dt) {
    for (final cd in _cooldowns.values) {
      cd.tick(dt);
    }
    final events = engine.tick(dt, _entities.values);
    for (final e in events) {
      _combatController.add(e);
    }
  }

  void dispose() {
    _combatController.close();
    _attackController.close();
  }
}
