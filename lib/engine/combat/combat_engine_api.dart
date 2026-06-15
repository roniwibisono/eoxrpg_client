import 'models.dart';

/// ╔══════════════════════════════════════════════════════════════════════╗
/// ║ DROP-IN POINT FOR THE EXISTING CombatEngine v2 (Echo of Xylos).        ║
/// ║                                                                        ║
/// ║ Everything in lib/game/ (GameOrchestrator, hitbox components, HUD)     ║
/// ║ talks ONLY to this interface — never to ReferenceCombatEngine          ║
/// ║ directly. To integrate the real engine:                                ║
/// ║   1. Write `class XylosCombatEngineAdapter implements CombatEngineApi` ║
/// ║      delegating to DamageResolver/FormulaEvaluator/HitResolver         ║
/// ║      (UNCHANGED, per D6 / Combat v2 §14).                              ║
/// ║   2. Swap one line in main.dart.                                       ║
/// ║ Per GDD §8.3 the implementation must be deterministic and use a        ║
/// ║ seedable RNG only.                                                     ║
/// ╚══════════════════════════════════════════════════════════════════════╝
abstract class CombatEngineApi {
  /// D8: called by GameOrchestrator at HITBOX CONTACT time — never at
  /// button-press time. One call per (cast, target) thanks to HitDedup.
  AttackResult resolveHit({
    required CombatantRuntime caster,
    required CombatantRuntime target,
    required SkillDef skill,
  });

  /// Whether the caster can start this cast right now (MP etc).
  /// Cooldowns are tracked outside the engine (CooldownManager) because
  /// they are presentation-rate concerns; MP is authoritative state.
  bool canCast(CombatantRuntime caster, SkillDef skill);

  /// Deducts cast costs. Call exactly once per cast (at cast start),
  /// regardless of how many targets the hitbox later touches.
  void payCastCost(CombatantRuntime caster, SkillDef skill);

  /// Advances DoT / regen / status expiry. Death from DoT emits
  /// DotDamageEvent(killed: true) + DeathEvent.
  List<CombatEvent> tick(double dt, Iterable<CombatantRuntime> entities);
}
