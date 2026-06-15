import 'battle_unit.dart';
import 'combat_engine.dart';

abstract class AllyAi {
  String selectAction(CombatEngine engine, BattleUnit self);
  String? selectTarget(CombatEngine engine, BattleUnit self, String action);
}

class AggressiveAi extends AllyAi {
  @override
  String selectAction(CombatEngine engine, BattleUnit self) {
    final skills = self.skillIds.where((s) => self.skillCooldowns[s] == null);
    if (skills.isNotEmpty && self.mp > 0) return skills.first;
    return 'basic_attack';
  }

  @override
  String? selectTarget(CombatEngine engine, BattleUnit self, String action) {
    return _lowestHpEnemy(engine);
  }

  String? _lowestHpEnemy(CombatEngine engine) {
    BattleUnit? target;
    for (final u in engine.units.values) {
      if (u.role == UnitRole.enemy && !u.isDead) {
        if (target == null || u.hp < target.hp) target = u;
      }
    }
    return target?.id;
  }
}

class BalancedAi extends AllyAi {
  static const double _healThreshold = 0.45;

  @override
  String selectAction(CombatEngine engine, BattleUnit self) {
    final skills = self.skillIds.where((s) => self.skillCooldowns[s] == null);
    if (skills.isNotEmpty && self.mp > 0) {
      if (self.hp < self.baseStats.maxHp * _healThreshold) return 'defend';
      return skills.first;
    }
    if (self.hp < self.baseStats.maxHp * _healThreshold) return 'defend';
    return 'basic_attack';
  }

  @override
  String? selectTarget(CombatEngine engine, BattleUnit self, String action) {
    BattleUnit? target;
    for (final u in engine.units.values) {
      if (u.role == UnitRole.enemy && !u.isDead) {
        if (target == null || u.hp < target.hp) target = u;
      }
    }
    return target?.id;
  }
}

class DefensiveAi extends AllyAi {
  @override
  String selectAction(CombatEngine engine, BattleUnit self) {
    if (self.hp < self.baseStats.maxHp * 0.5) return 'defend';
    if (self.mp > 0) {
      final skills = self.skillIds.where((s) => self.skillCooldowns[s] == null);
      if (skills.isNotEmpty) return skills.first;
    }
    return 'basic_attack';
  }

  @override
  String? selectTarget(CombatEngine engine, BattleUnit self, String action) {
    BattleUnit? target;
    for (final u in engine.units.values) {
      if (u.role == UnitRole.enemy && !u.isDead) {
        if (target == null || u.atk > target.atk) target = u;
      }
    }
    return target?.id;
  }
}

class HealerAi extends AllyAi {
  static const double _healThreshold = 0.45;

  @override
  String selectAction(CombatEngine engine, BattleUnit self) {
    final allyNeedsHeal = engine.units.values.any(
      (u) => u.role != UnitRole.enemy && !u.isDead && u.hp < u.baseStats.maxHp * _healThreshold,
    );
    if (allyNeedsHeal && self.mp > 0) {
      final skills = self.skillIds.where((s) => self.skillCooldowns[s] == null);
      if (skills.isNotEmpty) return skills.first;
    }
    if (self.hp < self.baseStats.maxHp * _healThreshold) return 'defend';
    return 'basic_attack';
  }

  @override
  String? selectTarget(CombatEngine engine, BattleUnit self, String action) {
    if (action != 'basic_attack' && action != 'defend') {
      BattleUnit? ally;
      for (final u in engine.units.values) {
        if (u.role != UnitRole.enemy && !u.isDead && u.id != self.id) {
          if (ally == null || u.hp < ally.hp) ally = u;
        }
      }
      if (ally != null && ally.hp < ally.baseStats.maxHp * _healThreshold) return ally.id;
    }
    BattleUnit? target;
    for (final u in engine.units.values) {
      if (u.role == UnitRole.enemy && !u.isDead) {
        if (target == null || u.hp < target.hp) target = u;
      }
    }
    return target?.id;
  }
}

AllyAi createAllyAi(AllyProfile profile) {
  return switch (profile) {
    AllyProfile.aggressive => AggressiveAi(),
    AllyProfile.balanced => BalancedAi(),
    AllyProfile.defensive => DefensiveAi(),
    AllyProfile.healer => HealerAi(),
  };
}
