import '../core/seeded_rng.dart';
import 'combat_engine_api.dart';
import 'models.dart';

/// ⚠️ REFERENCE IMPLEMENTATION — PLACEHOLDER FORMULAS.
///
/// GDD §5 forbids inventing balance numbers: the source of truth is the
/// existing Echo of Xylos CombatEngine + GameConfig. This class exists ONLY
/// so the Flame client is runnable end-to-end before the real engine is
/// adapted. Every formula below is intentionally simple and clearly wrong
/// for production balance. DO NOT TUNE THESE — replace the engine.
class ReferenceCombatEngine implements CombatEngineApi {
  final SeededRng rng;
  ReferenceCombatEngine(this.rng);

  // PLACEHOLDER constants
  static const _critMultiplier = 1.5;
  static const _baseHitChance = 0.95;
  static const _variance = 0.10; // ±10%

  @override
  bool canCast(CombatantRuntime caster, SkillDef skill) =>
      !caster.dead && caster.mp >= skill.mpCost;

  @override
  void payCastCost(CombatantRuntime caster, SkillDef skill) {
    caster.mp = (caster.mp - skill.mpCost).clamp(0, caster.stats.maxMp);
  }

  @override
  AttackResult resolveHit({
    required CombatantRuntime caster,
    required CombatantRuntime target,
    required SkillDef skill,
  }) {
    if (target.dead) {
      return AttackResult(
        casterId: caster.id,
        targetId: target.id,
        skillId: skill.id,
        outcome: AttackOutcome.miss,
        damage: 0,
        targetHpAfter: target.hp,
        killed: false,
      );
    }

    // Dodge i-frames win over everything (Combat v2 dodge rhythm).
    if (target.invulnerable) {
      return AttackResult(
        casterId: caster.id,
        targetId: target.id,
        skillId: skill.id,
        outcome: AttackOutcome.dodge,
        damage: 0,
        targetHpAfter: target.hp,
        killed: false,
      );
    }

    // PLACEHOLDER hit/dodge roll
    if (!rng.chance(_baseHitChance)) {
      return AttackResult(
        casterId: caster.id,
        targetId: target.id,
        skillId: skill.id,
        outcome: AttackOutcome.miss,
        damage: 0,
        targetHpAfter: target.hp,
        killed: false,
      );
    }
    if (rng.chance(target.stats.dodgeChance)) {
      return AttackResult(
        casterId: caster.id,
        targetId: target.id,
        skillId: skill.id,
        outcome: AttackOutcome.dodge,
        damage: 0,
        targetHpAfter: target.hp,
        killed: false,
      );
    }

    // PLACEHOLDER damage formula:
    // dmg = max(1, atk*power - def*0.5) * variance, crit ×1.5
    final isCrit = rng.chance(caster.stats.critChance);
    var dmg = caster.stats.atk * skill.powerMultiplier -
        target.stats.def * 0.5;
    if (dmg < 1) dmg = 1;
    dmg *= rng.range(1 - _variance, 1 + _variance);
    if (isCrit) dmg *= _critMultiplier;
    dmg = dmg.roundToDouble();

    target.hp = (target.hp - dmg).clamp(0, target.stats.maxHp);

    String? appliedStatus;
    if (skill.statusOnHit != null && !target.dead) {
      target.statuses.add(ActiveStatus(skill.statusOnHit!));
      appliedStatus = skill.statusOnHit!.id;
    }

    return AttackResult(
      casterId: caster.id,
      targetId: target.id,
      skillId: skill.id,
      outcome: isCrit ? AttackOutcome.crit : AttackOutcome.hit,
      damage: dmg,
      targetHpAfter: target.hp,
      killed: target.dead,
      appliedStatusId: appliedStatus,
    );
  }

  @override
  List<CombatEvent> tick(double dt, Iterable<CombatantRuntime> entities) {
    final events = <CombatEvent>[];
    for (final e in entities) {
      if (e.dead) continue;

      // MP regen — PLACEHOLDER rate from stats.
      e.mp = (e.mp + e.stats.mpRegenPerSecond * dt).clamp(0, e.stats.maxMp);

      // Statuses (DoT / expiry).
      for (final s in List.of(e.statuses)) {
        final dot = s.tick(dt);
        if (dot > 0) {
          e.hp = (e.hp - dot).clamp(0, e.stats.maxHp);
          events.add(DotDamageEvent(
            targetId: e.id,
            statusId: s.def.id,
            damage: dot,
            hpAfter: e.hp,
            killed: e.dead,
          ));
          if (e.dead) {
            events.add(DeathEvent(e.id));
            break;
          }
        }
        if (s.expired) e.statuses.remove(s);
      }
    }
    return events;
  }
}
