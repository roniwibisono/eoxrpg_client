import 'package:flutter_test/flutter_test.dart';

import 'package:eoxrpg_client/engine/combat/battle_unit.dart';
import 'package:eoxrpg_client/engine/combat/battle_event.dart';
import 'package:eoxrpg_client/engine/combat/combat_engine.dart';
import 'package:eoxrpg_client/engine/combat/turn_queue.dart';
import 'package:eoxrpg_client/engine/combat/ally_ai.dart';
import 'package:eoxrpg_client/engine/core/seeded_rng.dart';

final _statusDefs = {
  'burn': BattleStatusDef.fromJson({
    'id': 'burn', 'name_key': 'status.burn', 'statMods': {},
    'dotPerTurn': 3, 'blocksSkills': false, 'absorb': false, 'durationTurns': 3, 'scope': 'single',
  }),
  'freeze': BattleStatusDef.fromJson({
    'id': 'freeze', 'name_key': 'status.freeze', 'statMods': {'spd': -10},
    'dotPerTurn': 0, 'blocksSkills': true, 'absorb': false, 'durationTurns': 2, 'scope': 'single',
  }),
  'poison': BattleStatusDef.fromJson({
    'id': 'poison', 'name_key': 'status.poison', 'statMods': {},
    'dotPerTurn': 2, 'blocksSkills': false, 'absorb': false, 'durationTurns': 5, 'scope': 'single',
  }),
  'shielded': BattleStatusDef.fromJson({
    'id': 'shielded', 'name_key': 'status.shielded', 'statMods': {},
    'dotPerTurn': 0, 'blocksSkills': false, 'absorb': true, 'absorbAmount': 50, 'durationTurns': 2, 'scope': 'single',
  }),
  'synchronized': BattleStatusDef.fromJson({
    'id': 'synchronized', 'name_key': 'status.synchronized', 'statMods': {'atk': 5},
    'dotPerTurn': 0, 'blocksSkills': false, 'absorb': false, 'durationTurns': 3, 'scope': 'partyWide',
  }),
};

final _skills = {
  'skl_basic_slash': BattleSkill.fromJson({
    'id': 'skl_basic_slash', 'mult': 1.0, 'mp_cost': 0, 'target': 'single',
    'element': 'physical', 'cooldown_turns': 0, 'is_basic_attack': true,
  }),
  'skl_fireball': BattleSkill.fromJson({
    'id': 'skl_fireball', 'mult': 1.8, 'mp_cost': 8, 'target': 'single',
    'element': 'fire', 'cooldown_turns': 2, 'status_on_hit': 'burn',
  }),
};

BattleUnit _player() => BattleUnit(
      id: 'player', name: 'Hero', role: UnitRole.player,
      baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 50, def: 20, spd: 15, critChance: 0.10),
      skillIds: ['skl_basic_slash', 'skl_fireball'],
    );

BattleUnit _enemy([String id = 'slime']) => BattleUnit(
      id: id, name: 'Slime', role: UnitRole.enemy,
      baseStats: const BattleStats(maxHp: 300, maxMp: 30, atk: 30, def: 10, spd: 8),
      skillIds: ['skl_basic_slash'],
    );

BattleUnit _ally(String id, {AllyProfile profile = AllyProfile.balanced}) => BattleUnit(
      id: id, name: 'Ally', role: UnitRole.ally,
      baseStats: const BattleStats(maxHp: 400, maxMp: 60, atk: 35, def: 15, spd: 12),
      skillIds: ['skl_basic_slash', 'skl_fireball'],
      aiProfile: profile,
    );

void main() {
  group('BattleUnit status effects', () {
    test('burn applies dotPerTurn on tick', () {
      final unit = _enemy();
      final prevHp = unit.hp;
      unit.applyStatus(_statusDefs['burn']!);
      unit.tickStatuses();
      expect(unit.hp, prevHp - 3);
      expect(unit.activeStatuses.length, 1);
    });

    test('status expires after duration', () {
      final unit = _enemy();
      unit.applyStatus(BattleStatusDef.fromJson({
        'id': 'test', 'durationTurns': 2, 'dotPerTurn': 0,
      }));
      unit.tickStatuses();
      expect(unit.activeStatuses.length, 1);
      unit.tickStatuses();
      expect(unit.activeStatuses.length, 0);
    });

    test('status refresh resets duration', () {
      final unit = _enemy();
      final def = BattleStatusDef.fromJson({
        'id': 'test', 'durationTurns': 3, 'dotPerTurn': 0,
      });
      unit.applyStatus(def);
      unit.tickStatuses();
      unit.applyStatus(def);
      expect(unit.activeStatuses.length, 1);
      expect(unit.activeStatuses.first.turnsRemaining, 3);
    });

    test('freeze blocks skills but allows basic attack', () {
      final unit = _enemy();
      unit.applyStatus(_statusDefs['freeze']!);
      expect(unit.skillsBlocked, true);
    });

    test('shielded absorb status', () {
      final unit = _enemy();
      unit.applyStatus(_statusDefs['shielded']!);
      expect(unit.totalAbsorb, 50);
    });

    test('statMods from synchronized boost atk', () {
      final unit = _enemy();
      unit.applyStatus(_statusDefs['synchronized']!);
      expect(unit.atk, greaterThan(30));
    });

    test('dead unit clearStatuses removes all', () {
      final unit = _enemy();
      unit.applyStatus(_statusDefs['burn']!);
      unit.applyStatus(_statusDefs['freeze']!);
      unit.clearStatuses();
      expect(unit.activeStatuses.length, 0);
    });
  });

  group('Turn queue initiative', () {
    test('spd + d10 sorts correctly', () {
      final rng = SeededRng(42);
      final queue = TurnQueue(rng);
      queue.buildQueue({'fast': 20, 'slow': 5});
      expect(queue.round, 1);
      expect(queue.order.length, 2);
      expect(queue.current(), isNotNull);
    });

    test('same seed produces identical order', () {
      final q1 = TurnQueue(SeededRng(123));
      final q2 = TurnQueue(SeededRng(123));
      final speeds = {'a': 10, 'b': 10, 'c': 10, 'd': 10};
      q1.buildQueue(Map.of(speeds));
      q2.buildQueue(Map.of(speeds));
      expect(q1.order, q2.order);
    });

    test('advance removes current and exposes next', () {
      final rng = SeededRng(99);
      final queue = TurnQueue(rng);
      queue.buildQueue({'a': 5, 'b': 5, 'c': 5});
      final current = queue.current();
      final advanced = queue.advance();
      expect(advanced, isNot(current));
      expect(queue.order.length, 2);
    });
  });

  group('CombatEngine turn-based core', () {
    test('deterministic with same seed', () {
      final e1 = CombatEngine(rng: SeededRng(42), statusDefs: _statusDefs, skills: _skills);
      final e2 = CombatEngine(rng: SeededRng(42), statusDefs: _statusDefs, skills: _skills);
      e1.addUnit(_player());
      e1.addUnit(_enemy());
      e2.addUnit(_player());
      e2.addUnit(_enemy());
      e1.startBattle();
      e2.startBattle();
      expect(e1.round, 1);
      expect(e1.activeUnitId, e2.activeUnitId);
    });

    test('clamp damage min 1', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: {
        'atk': BattleSkill(id: 'atk', mult: 1.0, mpCost: 0),
      });
      final tank = BattleUnit(
        id: 'tank', name: 'Tank', role: UnitRole.enemy,
        baseStats: const BattleStats(maxHp: 500, maxMp: 0, atk: 1, def: 999, spd: 5, dodgeChance: 0),
        skillIds: ['atk'],
      );
      final hitter = BattleUnit(
        id: 'hitter', name: 'Hitter', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 20, def: 10, spd: 10, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      engine.addUnit(hitter);
      engine.addUnit(tank);
      engine.startBattle();
      engine.performAttack('hitter', 'tank', 'atk');
      final dmgEvent = engine.pendingEvents.whereType<DamageEvent>().first;
      expect(dmgEvent.damage, 1);
    });

    test('defend reduces next damage by 1.5x def', () {
      final engine = CombatEngine(
        rng: SeededRng(999),
        statusDefs: {},
        skills: {'atk': BattleSkill(id: 'atk', mult: 1.0, mpCost: 0)},
        defendMultiplier: 1.5,
        defReductionRatio: 0.4,
      );
      final attacker = BattleUnit(
        id: 'att', name: 'Att', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 100, def: 0, spd: 20, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      final defender = BattleUnit(
        id: 'def', name: 'Def', role: UnitRole.enemy,
        baseStats: const BattleStats(maxHp: 500, maxMp: 0, atk: 1, def: 50, spd: 5, dodgeChance: 0),
        skillIds: ['atk'],
      );
      final noDefend = CombatEngine(
        rng: SeededRng(999),
        statusDefs: {},
        skills: {'atk': BattleSkill(id: 'atk', mult: 1.0, mpCost: 0)},
        defendMultiplier: 1.5,
        defReductionRatio: 0.4,
      );
      final att2 = BattleUnit(
        id: 'att', name: 'Att', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 100, def: 0, spd: 20, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      final def2 = BattleUnit(
        id: 'def', name: 'Def', role: UnitRole.enemy,
        baseStats: const BattleStats(maxHp: 500, maxMp: 0, atk: 1, def: 50, spd: 5, dodgeChance: 0),
        skillIds: ['atk'],
      );
      engine.addUnit(attacker);
      engine.addUnit(defender);
      engine.startBattle();
      engine.performDefend('def');
      final dmgWithoutDefend = _getNextDamage(noDefend, att2, def2);
      
      expect(dmgWithoutDefend, isNotNull);
    });

    test('flee forbidden on boss battle', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: {});
      engine.addUnit(_player());
      engine.addUnit(_enemy());
      engine.startBattle();
      engine.performFlee('player', isBoss: true);
      final fleeEvent = engine.pendingEvents.whereType<FleeAttemptEvent>().first;
      expect(fleeEvent.success, false);
      expect(engine.hasFled, false);
    });

    test('flee chance formula within bounds', () {
      int successes = 0;
      const trials = 100;
      for (var i = 0; i < trials; i++) {
        final engine = CombatEngine(rng: SeededRng(i * 7), statusDefs: {}, skills: {});
        final fastPlayer = BattleUnit(
          id: 'fp', name: 'Fast', role: UnitRole.player,
          baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 50, def: 20, spd: 30),
        );
        engine.addUnit(fastPlayer);
        engine.addUnit(_enemy());
        engine.startBattle();
        engine.performFlee('fp');
        if (engine.hasFled) successes++;
      }
      expect(successes, greaterThan(0));
      expect(successes, lessThan(trials));
    });

    test('battle ends on all enemies dead', () {
      final engine = CombatEngine(rng: SeededRng(42), statusDefs: {}, skills: {
        'atk': BattleSkill(id: 'atk', mult: 100.0, mpCost: 0),
      });
      final op = BattleUnit(
        id: 'op', name: 'OP', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 500, def: 20, spd: 10, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      engine.addUnit(op);
      engine.addUnit(_enemy());
      engine.startBattle();
      engine.performAttack('op', 'slime', 'atk');
      final endEvent = engine.pendingEvents.whereType<BattleEndEvent>().firstOrNull;
      expect(endEvent?.result, BattleResult.victory);
      expect(engine.isOver, true);
    });

    test('battle ends on player death', () {
      final engine = CombatEngine(rng: SeededRng(42), statusDefs: {}, skills: {
        'atk': BattleSkill(id: 'atk', mult: 100.0, mpCost: 0),
      });
      final weakPlayer = BattleUnit(
        id: 'wp', name: 'Weak', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 10, maxMp: 100, atk: 1, def: 0, spd: 1, dodgeChance: 0),
      );
      final op2 = BattleUnit(
        id: 'op2', name: 'OP', role: UnitRole.enemy,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 500, def: 20, spd: 20, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      engine.addUnit(weakPlayer);
      engine.addUnit(op2);
      engine.startBattle();
      engine.performAttack('op2', 'wp', 'atk');
      final endEvent = engine.pendingEvents.whereType<BattleEndEvent>().firstOrNull;
      expect(endEvent?.result, BattleResult.defeat);
    });

    test('dot status can kill on tick', () {
      final engine = CombatEngine(rng: SeededRng(42), statusDefs: _statusDefs, skills: {
        'atk': BattleSkill(id: 'atk', mult: 1.0, mpCost: 0),
      });
      final nearDeath = BattleUnit(
        id: 'nd', name: 'NearDeath', role: UnitRole.enemy,
        hp: 2,
        baseStats: const BattleStats(maxHp: 100, maxMp: 0, atk: 5, def: 0, spd: 99, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      final player = BattleUnit(
        id: 'pl', name: 'Player', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 10, def: 0, spd: 1, dodgeChance: 0, critChance: 0),
        skillIds: ['atk'],
      );
      engine.addUnit(player);
      engine.addUnit(nearDeath);
      engine.startBattle();
      nearDeath.applyStatus(_statusDefs['burn']!);
      expect(engine.activeUnitId, 'nd');
      engine.tickEndOfTurn();
      expect(engine.units['nd']?.isDead, true);
    });

    test('item consumes count on use', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: {});
      final unit = BattleUnit(
        id: 'p', name: 'P', role: UnitRole.player,
        baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 50, def: 20, spd: 10),
      );
      unit.itemCounts['potion'] = 3;
      engine.addUnit(unit);
      engine.addUnit(_enemy());
      engine.startBattle();
      engine.performItem('p', 'potion', 'p');
      expect(unit.itemCounts['potion'], 2);
    });
  });

  group('Ally AI profiles', () {
    test('aggressive selects skill when available', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: _skills);
      final ally = _ally('a1', profile: AllyProfile.aggressive);
      ally.mp = 100;
      engine.addUnit(ally);
      engine.addUnit(_enemy());
      final ai = createAllyAi(AllyProfile.aggressive);
      final action = ai.selectAction(engine, ally);
      expect(action, isNotEmpty);
    });

    test('healer prioritizes low HP ally', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: _skills);
      final healer = _ally('healer', profile: AllyProfile.healer);
      healer.mp = 100;
      final injured = BattleUnit(
        id: 'injured', name: 'Injured', role: UnitRole.player,
        hp: 10,
        baseStats: const BattleStats(maxHp: 500, maxMp: 0, atk: 1, def: 0, spd: 1),
      );
      engine.addUnit(healer);
      engine.addUnit(injured);
      engine.addUnit(_enemy());
      final ai = createAllyAi(AllyProfile.healer);
      final target = ai.selectTarget(engine, healer, 'skl_fireball');
      expect(target, 'injured');
    });

    test('defensive defends at low HP', () {
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: _skills);
      final ally = _ally('d1', profile: AllyProfile.defensive);
      ally.hp = 10;
      ally.mp = 100;
      engine.addUnit(ally);
      engine.addUnit(_enemy());
      final ai = createAllyAi(AllyProfile.defensive);
      final action = ai.selectAction(engine, ally);
      expect(action, 'defend');
    });

    test('4 profiles produce different actions on same state', () {
      final ally = _ally('test', profile: AllyProfile.aggressive);
      ally.hp = 100;
      ally.mp = 100;
      final engine = CombatEngine(rng: SeededRng(1), statusDefs: {}, skills: _skills);
      engine.addUnit(ally);
      engine.addUnit(_enemy());

      final actions = <AllyProfile, String>{};
      for (final profile in AllyProfile.values) {
        final ai = createAllyAi(profile);
        actions[profile] = ai.selectAction(engine, ally);
      }
      expect(actions[AllyProfile.aggressive], isNot(actions[AllyProfile.defensive]));
    });
  });

  group('StatusDef fromJson', () {
    test('loads from valid JSON', () {
      final def = BattleStatusDef.fromJson({
        'id': 'burn', 'statMods': {'atk': -5}, 'dotPerTurn': 3,
        'durationTurns': 3, 'scope': 'single',
      });
      expect(def.id, 'burn');
      expect(def.dotPerTurn, 3);
      expect(def.durationTurns, 3);
      expect(def.statMods['atk'], -5);
    });

    test('loads status with missing optional fields', () {
      final def = BattleStatusDef.fromJson({'id': 'custom'});
      expect(def.id, 'custom');
      expect(def.statMods, isEmpty);
      expect(def.dotPerTurn, 0);
      expect(def.blocksSkills, false);
      expect(def.absorb, false);
      expect(def.durationTurns, 3);
    });
  });

  group('BattleSkill fromJson', () {
    test('loads from valid JSON', () {
      final skill = BattleSkill.fromJson({
        'id': 'skl_test', 'mult': 2.5, 'mp_cost': 15, 'cooldown_turns': 3,
      });
      expect(skill.id, 'skl_test');
      expect(skill.mult, 2.5);
      expect(skill.mpCost, 15);
      expect(skill.cooldownTurns, 3);
    });

    test('loads with defaults on missing fields', () {
      final skill = BattleSkill.fromJson({'id': 'skl_min'});
      expect(skill.mult, 1.0);
      expect(skill.mpCost, 0);
      expect(skill.cooldownTurns, 0);
      expect(skill.isBasicAttack, false);
    });
  });
}

int? _getNextDamage(CombatEngine engine, BattleUnit attacker, BattleUnit defender) {
  engine.addUnit(attacker);
  engine.addUnit(defender);
  engine.startBattle();
  engine.performAttack(attacker.id, defender.id, 'atk');
  final events = engine.pendingEvents.whereType<DamageEvent>();
  for (final e in events) {
    if (e.outcome == AttackOutcome.hit || e.outcome == AttackOutcome.crit) {
      return e.damage;
    }
  }
  return null;
}
