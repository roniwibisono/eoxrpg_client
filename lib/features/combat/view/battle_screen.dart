import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../engine/combat/battle_event.dart';
import '../../../engine/combat/battle_unit.dart';
import '../../../engine/combat/combat_engine.dart';
import '../../../engine/core/seeded_rng.dart';
import '../bloc/combat_bloc.dart';
import 'battle_overlay.dart';
import 'battle_scene.dart';

class BattleScreen extends StatefulWidget {
  final List<String> monsterIds;

  const BattleScreen({super.key, required this.monsterIds});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final CombatEngine _engine;
  late final CombatBloc _bloc;

  @override
  void initState() {
    super.initState();
    _engine = _createEngine();
    _bloc = CombatBloc(_engine);
    _bloc.add(StartCombat());
  }

  CombatEngine _createEngine() {
    final engine = CombatEngine(
      rng: SeededRng(DateTime.now().millisecondsSinceEpoch),
      statusDefs: {},
      skills: {},
    );

    engine.addUnit(BattleUnit(
      id: 'player',
      name: 'Hero',
      role: UnitRole.player,
      baseStats: const BattleStats(maxHp: 500, maxMp: 100, atk: 50, def: 20, spd: 15, critChance: 0.10),
      skillIds: ['skl_basic_slash', 'skl_fireball'],
    ));

    engine.addUnit(BattleUnit(
      id: 'ally1',
      name: 'Guardian',
      role: UnitRole.ally,
      baseStats: const BattleStats(maxHp: 400, maxMp: 60, atk: 35, def: 15, spd: 12),
      skillIds: ['skl_basic_slash'],
      aiProfile: AllyProfile.balanced,
    ));

    engine.addUnit(BattleUnit(
      id: 'ally2',
      name: 'Healer',
      role: UnitRole.ally,
      baseStats: const BattleStats(maxHp: 300, maxMp: 90, atk: 20, def: 10, spd: 14),
      skillIds: ['skl_basic_slash'],
      aiProfile: AllyProfile.healer,
    ));

    int idx = 0;
    for (final mId in widget.monsterIds) {
      engine.addUnit(BattleUnit(
        id: 'enemy_$mId${idx > 0 ? '_$idx' : ''}',
        name: mId.replaceAll('_', ' '),
        role: UnitRole.enemy,
        baseStats: const BattleStats(maxHp: 300, maxMp: 30, atk: 30, def: 10, spd: 8),
        skillIds: ['skl_basic_slash'],
      ));
      idx++;
    }

    return engine;
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _onBattleEnd(BattleResult result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: _BattleContent(onBattleEnd: _onBattleEnd),
    );
  }
}

class _BattleContent extends StatelessWidget {
  final void Function(BattleResult) onBattleEnd;

  const _BattleContent({required this.onBattleEnd});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CombatBloc, CombatState>(
      listener: (context, state) {
        if (state.phase == CombatPhase.victory) {
          onBattleEnd(BattleResult.victory);
        } else if (state.phase == CombatPhase.defeat) {
          onBattleEnd(BattleResult.defeat);
        } else if (state.phase == CombatPhase.fled) {
          onBattleEnd(BattleResult.fled);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            GameWidget<FlameGame>.controlled(
              gameFactory: () {
                final bloc = context.read<CombatBloc>();
                final game = FlameGame();
                game.world.add(BattleScene(bloc: bloc));
                return game;
              },
            ),
            const BattleOverlay(),
          ],
        ),
      ),
    );
  }
}
