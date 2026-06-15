/// PURE DART combat models. No Flame/Flutter imports.
///
/// ⚠️ IMPORTANT — these are interface-level models for the Flame client.
/// The REAL stat/damage source of truth is the existing Echo of Xylos
/// CombatEngine v2 + GameConfig (GDD §5, D6). When integrating, either:
///   (a) implement [CombatEngineApi] (see combat_engine_api.dart) as a thin
///       adapter over the existing engine, or
///   (b) map these models to the existing ones in the adapter.
/// Nothing in lib/game/ depends on the reference formulas.
library;

enum SkillShape { melee, projectile, aoe }

enum AttackOutcome { hit, crit, miss, dodge }

/// Status effect definition. PLACEHOLDER semantics: only DoT and slow are
/// implemented in the reference engine; the real ~150 effect types live in
/// the existing skill system (GDD §5).
class StatusDef {
  final String id;
  final double duration; // seconds
  final double dotDamagePerSecond; // 0 = none
  final double moveSpeedMultiplier; // 1.0 = none
  const StatusDef({
    required this.id,
    required this.duration,
    this.dotDamagePerSecond = 0,
    this.moveSpeedMultiplier = 1.0,
  });
}

class ActiveStatus {
  final StatusDef def;
  double remaining;
  double _dotAccumulator = 0;
  ActiveStatus(this.def) : remaining = def.duration;

  /// Returns DoT damage accrued this tick (1s granularity).
  double tick(double dt) {
    remaining -= dt;
    if (def.dotDamagePerSecond <= 0) return 0;
    _dotAccumulator += dt;
    var dmg = 0.0;
    while (_dotAccumulator >= 1.0) {
      _dotAccumulator -= 1.0;
      dmg += def.dotDamagePerSecond;
    }
    return dmg;
  }

  bool get expired => remaining <= 0;
}

/// D9: cooldownSeconds / range values on every SkillDef shipped in this
/// project are PLACEHOLDERS derived the same way Combat v2 §7 derives them.
/// They MUST be overridden after playtest (TBD-06).
class SkillDef {
  final String id;
  final String name;
  final SkillShape shape;
  final double powerMultiplier; // vs caster atk — PLACEHOLDER scale
  final double mpCost;
  final double cooldownSeconds; // PLACEHOLDER (TBD-06)
  final double range; // px — melee arc reach / projectile max travel
  final double projectileSpeed; // px/s, projectile only
  final double aoeRadius; // px, aoe only
  final StatusDef? statusOnHit;
  final bool isBasicAttack;

  const SkillDef({
    required this.id,
    required this.name,
    required this.shape,
    required this.powerMultiplier,
    required this.mpCost,
    required this.cooldownSeconds,
    required this.range,
    this.projectileSpeed = 0,
    this.aoeRadius = 0,
    this.statusOnHit,
    this.isBasicAttack = false,
  });
}

class CombatantStats {
  final double maxHp;
  final double maxMp;
  final double atk;
  final double def;
  final double critChance; // 0..1
  final double dodgeChance; // 0..1
  final double moveSpeed; // px/s
  final double mpRegenPerSecond;
  const CombatantStats({
    required this.maxHp,
    required this.maxMp,
    required this.atk,
    required this.def,
    this.critChance = 0.05,
    this.dodgeChance = 0.05,
    this.moveSpeed = 120,
    this.mpRegenPerSecond = 1,
  });
}

class CombatantRuntime {
  final String id;
  final CombatantStats stats;
  double hp;
  double mp;

  /// Dodge i-frames (Combat v2 dodge rhythm). While true, every incoming
  /// resolveHit returns [AttackOutcome.dodge] deterministically.
  bool invulnerable = false;

  final List<ActiveStatus> statuses = [];

  CombatantRuntime({required this.id, required this.stats})
      : hp = stats.maxHp,
        mp = stats.maxMp;

  bool get dead => hp <= 0;

  double get moveSpeedMultiplier => statuses.fold(
      1.0, (m, s) => m * s.def.moveSpeedMultiplier);
}

class AttackResult {
  final String casterId;
  final String targetId;
  final String skillId;
  final AttackOutcome outcome;
  final double damage;
  final double targetHpAfter;
  final bool killed;
  final String? appliedStatusId;
  const AttackResult({
    required this.casterId,
    required this.targetId,
    required this.skillId,
    required this.outcome,
    required this.damage,
    required this.targetHpAfter,
    required this.killed,
    this.appliedStatusId,
  });
}

/// Events emitted by CombatEngineApi.tick (DoT damage, deaths, expiries).
sealed class CombatEvent {
  const CombatEvent();
}

class DotDamageEvent extends CombatEvent {
  final String targetId;
  final String statusId;
  final double damage;
  final double hpAfter;
  final bool killed;
  const DotDamageEvent({
    required this.targetId,
    required this.statusId,
    required this.damage,
    required this.hpAfter,
    required this.killed,
  });
}

class DeathEvent extends CombatEvent {
  final String entityId;
  const DeathEvent(this.entityId);
}
