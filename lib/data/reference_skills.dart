import '../engine/combat/models.dart';

/// ⚠️ PLACEHOLDER SKILLS — these exist only to exercise the three hitbox
/// shapes (melee arc, projectile, AoE) end-to-end. Real skills come from the
/// 622-skill `skill_list.json` on the CDN; D9 applies to every number here.
class ReferenceSkills {
  static const basicSlash = SkillDef(
    id: 'ref_basic_slash',
    name: 'Slash',
    shape: SkillShape.melee,
    powerMultiplier: 1.0,
    mpCost: 0,
    cooldownSeconds: 0.45, // PLACEHOLDER (TBD-06)
    range: 42,
    isBasicAttack: true,
  );

  static const fireball = SkillDef(
    id: 'ref_fireball',
    name: 'Fireball',
    shape: SkillShape.projectile,
    powerMultiplier: 1.6,
    mpCost: 8,
    cooldownSeconds: 2.0, // PLACEHOLDER (TBD-06)
    range: 320,
    projectileSpeed: 380,
    statusOnHit: StatusDef(
      id: 'ref_burn',
      duration: 3,
      dotDamagePerSecond: 3, // PLACEHOLDER
    ),
  );

  static const nova = SkillDef(
    id: 'ref_nova',
    name: 'Nova',
    shape: SkillShape.aoe,
    powerMultiplier: 1.2,
    mpCost: 14,
    cooldownSeconds: 5.0, // PLACEHOLDER (TBD-06)
    range: 0, // self-centered
    aoeRadius: 90,
  );

  /// Monster contact attack.
  static const slimeBite = SkillDef(
    id: 'ref_slime_bite',
    name: 'Bite',
    shape: SkillShape.melee,
    powerMultiplier: 1.0,
    mpCost: 0,
    cooldownSeconds: 1.2, // PLACEHOLDER
    range: 30,
    isBasicAttack: true,
  );
}
