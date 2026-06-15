import 'battle_unit.dart';

sealed class BattleEvent {
  const BattleEvent();
}

class TurnStartEvent extends BattleEvent {
  final String unitId;
  final int round;
  const TurnStartEvent(this.unitId, this.round);
}

class ActionSelectedEvent extends BattleEvent {
  final String casterId;
  final BattleActionType actionType;
  final String? skillId;
  const ActionSelectedEvent(this.casterId, this.actionType, this.skillId);
}

class DamageEvent extends BattleEvent {
  final String casterId;
  final String targetId;
  final String? skillId;
  final AttackOutcome outcome;
  final int damage;
  final String? statusApplied;
  const DamageEvent({
    required this.casterId,
    required this.targetId,
    this.skillId,
    required this.outcome,
    required this.damage,
    this.statusApplied,
  });
}

class HealEvent extends BattleEvent {
  final String casterId;
  final String targetId;
  final int amount;
  const HealEvent(this.casterId, this.targetId, this.amount);
}

class DefendEvent extends BattleEvent {
  final String unitId;
  const DefendEvent(this.unitId);
}

class FleeAttemptEvent extends BattleEvent {
  final String unitId;
  final bool success;
  const FleeAttemptEvent(this.unitId, this.success);
}

class StatusAppliedEvent extends BattleEvent {
  final String unitId;
  final String statusId;
  const StatusAppliedEvent(this.unitId, this.statusId);
}

class StatusExpiredEvent extends BattleEvent {
  final String unitId;
  final String statusId;
  const StatusExpiredEvent(this.unitId, this.statusId);
}

class UnitDiedEvent extends BattleEvent {
  final String unitId;
  const UnitDiedEvent(this.unitId);
}

class BattleEndEvent extends BattleEvent {
  final BattleResult result;
  const BattleEndEvent(this.result);
}

enum AttackOutcome { hit, crit, miss, dodge, absorb }

enum BattleResult { victory, defeat, fled }
