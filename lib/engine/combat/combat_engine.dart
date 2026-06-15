import '../core/seeded_rng.dart';
import 'battle_event.dart';
import 'battle_unit.dart';
import 'turn_queue.dart';

class CombatEngine {
  final SeededRng _rng;
  final Map<String, BattleUnit> _units = {};
  final TurnQueue _turnQueue;
  final Map<String, BattleStatusDef> _statusDefs;
  final Map<String, BattleSkill> _skills;
  final double _defReductionRatio;
  final double _defendMultiplier;
  final double _fleeBase;
  final double _fleeSpeedWeight;
  final double _fleeMin;
  final double _fleeMax;

  final List<BattleEvent> _pendingEvents = [];

  bool _ended = false;
  String? _activeUnitId;
  bool _fled = false;

  CombatEngine({
    required SeededRng rng,
    required this._statusDefs,
    required this._skills,
    this._defReductionRatio = 0.4,
    this._defendMultiplier = 1.5,
    this._fleeBase = 0.4,
    this._fleeSpeedWeight = 0.02,
    this._fleeMin = 0.1,
    this._fleeMax = 0.9,
  })  : _rng = rng,
        _turnQueue = TurnQueue(rng);

  SeededRng get rng => _rng;
  List<BattleEvent> get pendingEvents => List.unmodifiable(_pendingEvents);
  Map<String, BattleUnit> get units => Map.unmodifiable(_units);
  bool get isOver => _ended;
  bool get hasFled => _fled;
  int get round => _turnQueue.round;
  String? get activeUnitId => _activeUnitId;
  BattleUnit? unit(String id) => _units[id];

  void clearEvents() => _pendingEvents.clear();

  void addUnit(BattleUnit unit) {
    _units[unit.id] = unit;
  }

  void removeUnit(String id) {
    _units.remove(id);
  }

  void startBattle() {
    _ended = false;
    _fled = false;
    _buildTurnQueue();
  }

  void _buildTurnQueue() {
    _activeUnitId = null;
    final alive = {
      for (final e in _units.entries)
        if (!e.value.isDead) e.key: e.value.spd,
    };
    _turnQueue.buildQueue(alive);
    _startNextTurn();
  }

  void _startNextTurn() {
    while (_turnQueue.current() != null) {
      final id = _turnQueue.current()!;
      final unit = _units[id];
      if (unit != null && !unit.isDead) {
        _activeUnitId = id;
        unit.isDefending = false;
        _pendingEvents.add(TurnStartEvent(id, _turnQueue.round));
        return;
      }
      _turnQueue.advance();
    }
    _buildTurnQueue();
    if (_turnQueue.isEmpty) {
      _endBattle(_checkResult() ?? BattleResult.defeat);
    }
  }

  void performBasicAttack(String casterId, String targetId) {
    performAttack(casterId, targetId, '');
  }

  void performAttack(String casterId, String targetId, String skillId) {
    if (_ended) return;
    final caster = _units[casterId];
    final target = _units[targetId];
    if (caster == null || target == null || caster.isDead || target.isDead) return;

    final skill = skillId.isNotEmpty ? _skills[skillId] : null;
    final mpCost = skill?.mpCost ?? 0;
    if (caster.mp < mpCost) return;

    if (caster.skillsBlocked && !(skill?.isBasicAttack ?? false)) return;

    caster.mp -= mpCost;
    final isBasic = skill?.isBasicAttack ?? (skillId.isEmpty);
    final mult = skill?.mult ?? 1.0;

    final outcome = _rollOutcome(caster, target);
    final actionType = isBasic ? BattleActionType.attack : BattleActionType.skill;
    _pendingEvents.add(ActionSelectedEvent(casterId, actionType, skillId.isNotEmpty ? skillId : null));

    if (outcome == AttackOutcome.dodge) {
      _pendingEvents.add(DamageEvent(
        casterId: casterId, targetId: targetId, skillId: skillId.isNotEmpty ? skillId : null,
        outcome: AttackOutcome.dodge, damage: 0,
      ));
    } else if (outcome == AttackOutcome.miss) {
      _pendingEvents.add(DamageEvent(
        casterId: casterId, targetId: targetId, skillId: skillId.isNotEmpty ? skillId : null,
        outcome: AttackOutcome.miss, damage: 0,
      ));
    } else {
      final absorb = target.totalAbsorb;
      final effectiveDef = target.isDefending
          ? (target.def * _defendMultiplier).round()
          : target.def;
      var rawDamage = caster.atk * mult - effectiveDef * _defReductionRatio;
      rawDamage = rawDamage.clamp(1, 99999);

      final isCrit = outcome == AttackOutcome.crit;
      if (isCrit) {
        rawDamage *= 1.5;
      }

      final damage = rawDamage.round();
      final attackOutcome = isCrit ? AttackOutcome.crit : AttackOutcome.hit;

      if (absorb > 0) {
        final absorbed = (damage * 0.5).round().clamp(0, absorb);
        final finalDamage = damage - absorbed;
        if (finalDamage <= 0) {
          _pendingEvents.add(DamageEvent(
            casterId: casterId, targetId: targetId, skillId: skillId.isNotEmpty ? skillId : null,
            outcome: AttackOutcome.absorb, damage: 0,
          ));
          target.hp = (target.hp - absorbed).clamp(0, target.baseStats.maxHp);
          if (target.hp <= 0) _onUnitDeath(target);
          _advanceTurn();
          return;
        }
        target.hp = (target.hp - finalDamage).clamp(0, target.baseStats.maxHp);
        _pendingEvents.add(DamageEvent(
          casterId: casterId, targetId: targetId, skillId: skillId.isNotEmpty ? skillId : null,
          outcome: attackOutcome, damage: finalDamage,
        ));
      } else {
        target.hp = (target.hp - damage).clamp(0, target.baseStats.maxHp);
        _pendingEvents.add(DamageEvent(
          casterId: casterId, targetId: targetId, skillId: skillId.isNotEmpty ? skillId : null,
          outcome: attackOutcome, damage: damage,
        ));
      }

      if (skill?.statusOnHit != null) {
        final statusDef = _statusDefs[skill!.statusOnHit];
        if (statusDef != null && outcome != AttackOutcome.dodge && outcome != AttackOutcome.miss) {
          target.applyStatus(statusDef);
          _pendingEvents.add(StatusAppliedEvent(targetId, statusDef.id));
        }
      }

      if (target.hp <= 0) _onUnitDeath(target);
    }
    _advanceTurn();
  }

  AttackOutcome _rollOutcome(BattleUnit caster, BattleUnit target) {
    final dodgeRoll = _rng.nextDouble();
    if (dodgeRoll < target.dodgeChance) return AttackOutcome.dodge;
    final hitRoll = _rng.nextDouble();
    if (hitRoll < caster.critChance) return AttackOutcome.crit;
    if (hitRoll >= 0.95 + target.dodgeChance) return AttackOutcome.miss;
    return AttackOutcome.hit;
  }

  void performDefend(String unitId) {
    if (_ended) return;
    final unit = _units[unitId];
    if (unit == null || unit.isDead) return;
    unit.isDefending = true;
    _pendingEvents.add(ActionSelectedEvent(unitId, BattleActionType.defend, null));
    _pendingEvents.add(DefendEvent(unitId));
    _advanceTurn();
  }

  void performFlee(String unitId, {bool isBoss = false}) {
    if (_ended) return;
    final unit = _units[unitId];
    if (unit == null || unit.isDead) return;
    if (isBoss) {
      _pendingEvents.add(FleeAttemptEvent(unitId, false));
      _advanceTurn();
      return;
    }
    final party = _units.values.where((u) => u.role != UnitRole.enemy && !u.isDead).toList();
    final enemies = _units.values.where((u) => u.role == UnitRole.enemy && !u.isDead).toList();
    final avgSpdParty = party.isEmpty ? 0 : party.map((u) => u.spd).reduce((a, b) => a + b) ~/ party.length;
    final avgSpdEnemy = enemies.isEmpty ? 0 : enemies.map((u) => u.spd).reduce((a, b) => a + b) ~/ enemies.length;
    final chance = (_fleeBase + (avgSpdParty - avgSpdEnemy) * _fleeSpeedWeight).clamp(_fleeMin, _fleeMax);
    final success = _rng.nextDouble() < chance;
    _pendingEvents.add(FleeAttemptEvent(unitId, success));
    if (success) {
      _fled = true;
      _endBattle(BattleResult.fled);
    } else {
      _advanceTurn();
    }
  }

  void performItem(String unitId, String itemId, String targetId) {
    if (_ended) return;
    final unit = _units[unitId];
    final target = _units[targetId];
    if (unit == null || target == null || unit.isDead || target.isDead) return;
    final count = unit.itemCounts[itemId] ?? 0;
    if (count <= 0) return;
    unit.itemCounts[itemId] = count - 1;
    _pendingEvents.add(ActionSelectedEvent(unitId, BattleActionType.item, itemId));
    _advanceTurn();
  }

  void _onUnitDeath(BattleUnit unit) {
    unit.isDead = true;
    unit.clearStatuses();
    _pendingEvents.add(UnitDiedEvent(unit.id));
    _checkBattleEnd();
  }

  void _checkBattleEnd() {
    final result = _checkResult();
    if (result != null) {
      _endBattle(result);
    }
  }

  BattleResult? _checkResult() {
    final partyAlive = _units.values.any((u) => u.role != UnitRole.enemy && !u.isDead);
    final enemiesAlive = _units.values.any((u) => u.role == UnitRole.enemy && !u.isDead);
    if (!partyAlive) return BattleResult.defeat;
    if (!enemiesAlive) return BattleResult.victory;
    return null;
  }

  void _endBattle(BattleResult result) {
    if (_ended) return;
    _ended = true;
    _activeUnitId = null;
    _pendingEvents.add(BattleEndEvent(result));
  }

  void tickEndOfTurn() {
    if (_ended) return;
    final unit = _activeUnitId != null ? _units[_activeUnitId] : null;
    if (unit != null) {
      unit.tickStatuses();
      unit.decrementCooldowns();
      if (unit.hp <= 0) _onUnitDeath(unit);
    }
    _checkBattleEnd();
  }

  void _advanceTurn() {
    if (_ended) return;
    tickEndOfTurn();
    if (_ended) return;
    _turnQueue.advance();
    _startNextTurn();
  }
}
