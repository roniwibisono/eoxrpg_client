enum BattleActionType { attack, skill, item, defend, flee }

enum UnitRole { player, ally, enemy }

enum AllyProfile { aggressive, balanced, defensive, healer }

class BattleStats {
  final int maxHp;
  final int maxMp;
  final int atk;
  final int def;
  final int spd;
  final double critChance;
  final double dodgeChance;
  final String element;

  const BattleStats({
    required this.maxHp,
    required this.maxMp,
    required this.atk,
    required this.def,
    required this.spd,
    this.critChance = 0.05,
    this.dodgeChance = 0.05,
    this.element = 'physical',
  });
}

class BattleUnit {
  final String id;
  final String name;
  final UnitRole role;
  final BattleStats baseStats;
  final List<String> skillIds;
  final String? element;
  final AllyProfile? aiProfile;

  int hp;
  int mp;
  bool isDefending;
  bool isDead;
  List<ActiveBattleStatus> activeStatuses;
  Map<String, int> skillCooldowns;
  Map<String, int> itemCounts;

  BattleUnit({
    required this.id,
    required this.name,
    required this.role,
    required this.baseStats,
    this.skillIds = const [],
    this.element,
    this.aiProfile,
    int? hp,
    int? mp,
  })  : hp = hp ?? baseStats.maxHp,
        mp = mp ?? baseStats.maxMp,
        isDefending = false,
        isDead = false,
        activeStatuses = [],
        skillCooldowns = {},
        itemCounts = {};

  int get atk => _modifiedStat(baseStats.atk, 'atk');
  int get def => _modifiedStat(baseStats.def, 'def');
  int get spd => _modifiedStat(baseStats.spd, 'spd');
  double get critChance => baseStats.critChance;
  double get dodgeChance => baseStats.dodgeChance;

  int _modifiedStat(int base, String statKey) {
    double mod = 1.0;
    for (final s in activeStatuses) {
      final mods = s.def.statMods;
      if (mods.containsKey(statKey)) {
        mod += mods[statKey]! / 100.0;
      }
    }
    return (base * mod).round().clamp(0, 9999);
  }

  bool get skillsBlocked =>
      activeStatuses.any((s) => s.def.blocksSkills);

  int get totalAbsorb =>
      activeStatuses.where((s) => s.def.absorb).fold<int>(0, (sum, s) => sum + s.def.absorbAmount);

  void applyStatus(BattleStatusDef def) {
    for (final s in activeStatuses) {
      if (s.def.id == def.id) {
        s.turnsRemaining = def.durationTurns;
        return;
      }
    }
    activeStatuses.add(ActiveBattleStatus(def: def, turnsRemaining: def.durationTurns));
  }

  void tickStatuses() {
    for (final s in activeStatuses.toList()) {
      if (s.def.dotPerTurn > 0) {
        final damage = s.def.dotPerTurn;
        hp = (hp - damage).clamp(0, baseStats.maxHp);
      }
      s.turnsRemaining--;
      if (s.turnsRemaining <= 0) {
        activeStatuses.remove(s);
      }
    }
  }

  void clearStatuses() {
    activeStatuses.clear();
  }

  void decrementCooldowns() {
    for (final key in skillCooldowns.keys.toList()) {
      skillCooldowns[key] = (skillCooldowns[key] ?? 1) - 1;
      if (skillCooldowns[key]! <= 0) {
        skillCooldowns.remove(key);
      }
    }
  }
}

class BattleStatusDef {
  final String id;
  final String nameKey;
  final Map<String, int> statMods;
  final int dotPerTurn;
  final bool blocksSkills;
  final bool absorb;
  final int absorbAmount;
  final int durationTurns;
  final String scope;

  const BattleStatusDef({
    required this.id,
    this.nameKey = '',
    this.statMods = const {},
    this.dotPerTurn = 0,
    this.blocksSkills = false,
    this.absorb = false,
    this.absorbAmount = 0,
    this.durationTurns = 3,
    this.scope = 'single',
  });

  factory BattleStatusDef.fromJson(Map<String, dynamic> json) {
    return BattleStatusDef(
      id: json['id'] as String,
      nameKey: json['name_key'] as String? ?? '',
      statMods: _parseMods(json['statMods']),
      dotPerTurn: (json['dotPerTurn'] as num?)?.toInt() ?? 0,
      blocksSkills: json['blocksSkills'] as bool? ?? false,
      absorb: json['absorb'] as bool? ?? false,
      absorbAmount: (json['absorbAmount'] as num?)?.toInt() ?? 0,
      durationTurns: (json['durationTurns'] as num?)?.toInt() ?? 3,
      scope: json['scope'] as String? ?? 'single',
    );
  }

  static Map<String, int> _parseMods(dynamic mods) {
    if (mods is! Map) return {};
    final result = <String, int>{};
    for (final entry in mods.entries) {
      result[entry.key.toString()] = (entry.value as num).toInt();
    }
    return result;
  }
}

class ActiveBattleStatus {
  final BattleStatusDef def;
  int turnsRemaining;

  ActiveBattleStatus({required this.def, required this.turnsRemaining});
}

class BattleSkill {
  final String id;
  final String nameKey;
  final bool isBasicAttack;
  final double mult;
  final int mpCost;
  final String target;
  final String element;
  final int cooldownTurns;
  final String? statusOnHit;

  const BattleSkill({
    required this.id,
    this.nameKey = '',
    this.isBasicAttack = false,
    this.mult = 1.0,
    this.mpCost = 0,
    this.target = 'single',
    this.element = 'physical',
    this.cooldownTurns = 0,
    this.statusOnHit,
  });

  factory BattleSkill.fromJson(Map<String, dynamic> json) {
    return BattleSkill(
      id: json['id'] as String,
      nameKey: json['name_key'] as String? ?? '',
      isBasicAttack: json['is_basic_attack'] as bool? ?? false,
      mult: (json['mult'] as num?)?.toDouble() ?? 1.0,
      mpCost: (json['mp_cost'] as num?)?.toInt() ?? 0,
      target: json['target'] as String? ?? 'single',
      element: json['element'] as String? ?? 'physical',
      cooldownTurns: (json['cooldown_turns'] as num?)?.toInt() ?? 0,
      statusOnHit: json['status_on_hit'] as String?,
    );
  }
}
