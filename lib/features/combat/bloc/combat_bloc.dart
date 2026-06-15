import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../engine/combat/ally_ai.dart';
import '../../../engine/combat/battle_event.dart';
import '../../../engine/combat/battle_unit.dart';
import '../../../engine/combat/combat_engine.dart';

enum CombatPhase {
  initial,
  playerTurn,
  allyTurn,
  enemyTurn,
  animating,
  victory,
  defeat,
  fled,
}

class CombatState extends Equatable {
  final CombatPhase phase;
  final Map<String, BattleUnit> units;
  final String? activeUnitId;
  final int round;

  const CombatState({
    required this.phase,
    required this.units,
    this.activeUnitId,
    this.round = 1,
  });

  factory CombatState.initial() => const CombatState(
        phase: CombatPhase.initial,
        units: {},
      );

  Map<String, BattleUnit> get partyUnits => Map.fromEntries(
        units.entries.where((e) => e.value.role != UnitRole.enemy));

  Map<String, BattleUnit> get enemyUnits => Map.fromEntries(
        units.entries.where((e) => e.value.role == UnitRole.enemy));

  @override
  List<Object?> get props => [phase, units, activeUnitId, round];
}

sealed class CombatBlocEvent extends Equatable {
  const CombatBlocEvent();
}

class StartCombat extends CombatBlocEvent {
  @override
  List<Object?> get props => [];
}

class SelectAttack extends CombatBlocEvent {
  final String skillId;
  final String targetId;
  const SelectAttack(this.skillId, this.targetId);
  @override
  List<Object?> get props => [skillId, targetId];
}

class SelectDefend extends CombatBlocEvent {
  const SelectDefend();
  @override
  List<Object?> get props => [];
}

class SelectFlee extends CombatBlocEvent {
  const SelectFlee();
  @override
  List<Object?> get props => [];
}

class SelectUseItem extends CombatBlocEvent {
  final String itemId;
  final String targetId;
  const SelectUseItem(this.itemId, this.targetId);
  @override
  List<Object?> get props => [itemId, targetId];
}

class CombatBloc extends Bloc<CombatBlocEvent, CombatState> {
  final CombatEngine _engine;
  final _eventController = StreamController<BattleEvent>.broadcast();

  Stream<BattleEvent> get eventStream => _eventController.stream;

  Map<String, BattleUnit> get partyUnits {
    final result = <String, BattleUnit>{};
    for (final e in _engine.units.entries) {
      if (e.value.role != UnitRole.enemy) {
        result[e.key] = e.value;
      }
    }
    return result;
  }

  Map<String, BattleUnit> get enemyUnits {
    final result = <String, BattleUnit>{};
    for (final e in _engine.units.entries) {
      if (e.value.role == UnitRole.enemy) {
        result[e.key] = e.value;
      }
    }
    return result;
  }

  CombatBloc(CombatEngine engine)
      : _engine = engine,
        super(CombatState.initial()) {
    on<StartCombat>(_onStartCombat);
    on<SelectAttack>(_onSelectAttack);
    on<SelectDefend>(_onSelectDefend);
    on<SelectFlee>(_onSelectFlee);
    on<SelectUseItem>(_onSelectUseItem);
  }

  void addUnit(BattleUnit unit) {
    _engine.addUnit(unit);
  }

  void selectAttack(String skillId, String targetId) =>
      add(SelectAttack(skillId, targetId));

  void defend() => add(const SelectDefend());

  void flee() => add(const SelectFlee());

  void useItem(String itemId, String targetId) =>
      add(SelectUseItem(itemId, targetId));

  void _onStartCombat(StartCombat event, Emitter<CombatState> emit) {
    _engine.startBattle();
    _drainEngineEvents(emit);
    _burstAutoPlayAndEmitPlayerTurn(emit);
  }

  void _onSelectAttack(SelectAttack event, Emitter<CombatState> emit) {
    if (_engine.isOver || _engine.activeUnitId == null) return;
    _engine.performAttack(
      _engine.activeUnitId!,
      event.targetId,
      event.skillId,
    );
    _drainEngineEvents(emit);
    _burstAutoPlayAndEmitPlayerTurn(emit);
  }

  void _onSelectDefend(SelectDefend event, Emitter<CombatState> emit) {
    if (_engine.isOver || _engine.activeUnitId == null) return;
    _engine.performDefend(_engine.activeUnitId!);
    _drainEngineEvents(emit);
    _burstAutoPlayAndEmitPlayerTurn(emit);
  }

  void _onSelectFlee(SelectFlee event, Emitter<CombatState> emit) {
    if (_engine.isOver || _engine.activeUnitId == null) return;
    _engine.performFlee(_engine.activeUnitId!);
    _drainEngineEvents(emit);
    if (_engine.isOver) {
      emit(CombatState(phase: CombatPhase.fled, units: _engine.units));
      return;
    }
    _burstAutoPlayAndEmitPlayerTurn(emit);
  }

  void _onSelectUseItem(SelectUseItem event, Emitter<CombatState> emit) {
    if (_engine.isOver || _engine.activeUnitId == null) return;
    _engine.performItem(
      _engine.activeUnitId!,
      event.itemId,
      event.targetId,
    );
    _drainEngineEvents(emit);
    _burstAutoPlayAndEmitPlayerTurn(emit);
  }

  void _drainEngineEvents(Emitter<CombatState> emit) {
    final events = List<BattleEvent>.from(_engine.pendingEvents);
    _engine.clearEvents();
    for (final e in events) {
      _eventController.add(e);
    }
  }

  void _burstAutoPlayAndEmitPlayerTurn(Emitter<CombatState> emit) {
    while (true) {
      if (_engine.isOver) {
        if (_engine.hasFled) {
          emit(CombatState(phase: CombatPhase.fled, units: _engine.units));
        } else {
          final partyAlive = _engine.units.values.any(
              (u) => u.role != UnitRole.enemy && !u.isDead);
          emit(CombatState(
            phase: partyAlive ? CombatPhase.victory : CombatPhase.defeat,
            units: _engine.units,
          ));
        }
        return;
      }

      final activeId = _engine.activeUnitId;
      if (activeId == null) return;
      final activeUnit = _engine.unit(activeId);
      if (activeUnit == null || activeUnit.isDead) return;

      if (activeUnit.role == UnitRole.player) {
        emit(CombatState(
          phase: CombatPhase.playerTurn,
          units: _engine.units,
          activeUnitId: activeId,
          round: _engine.round,
        ));
        return;
      }

      final isAlly = activeUnit.role == UnitRole.ally;
      emit(CombatState(
        phase: isAlly ? CombatPhase.allyTurn : CombatPhase.enemyTurn,
        units: _engine.units,
        activeUnitId: activeId,
        round: _engine.round,
      ));

      if (isAlly) {
        _autoPlayAlly(activeUnit);
      } else {
        _autoPlayEnemy(activeUnit);
      }

      _drainEngineEvents(emit);
    }
  }

  void _autoPlayAlly(BattleUnit unit) {
    if (unit.aiProfile == null) return;
    final ai = createAllyAi(unit.aiProfile!);
    final action = ai.selectAction(_engine, unit);
    final targetId = ai.selectTarget(_engine, unit, action);

    if (action == 'defend') {
      _engine.performDefend(unit.id);
    } else if (targetId != null) {
      if (action == 'basic_attack') {
        _engine.performBasicAttack(unit.id, targetId);
      } else {
        _engine.performAttack(unit.id, targetId, action);
      }
    }
  }

  void _autoPlayEnemy(BattleUnit unit) {
    String? targetId;
    int lowestHp = 999999;
    for (final u in _engine.units.values) {
      if (u.role != UnitRole.enemy && !u.isDead && u.hp < lowestHp) {
        lowestHp = u.hp;
        targetId = u.id;
      }
    }
    if (targetId != null) {
      _engine.performBasicAttack(unit.id, targetId);
    }
  }

  @override
  Future<void> close() {
    _eventController.close();
    return super.close();
  }
}
