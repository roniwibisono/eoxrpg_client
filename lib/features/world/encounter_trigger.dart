import 'package:flame/components.dart';

import '../../core/config/app_config.dart';
import '../../core/di/injection_container.dart';
import '../../engine/world/aabb.dart';
import '../../game/components/combat_entity_component.dart';
import '../../game/eox_game.dart';

class EncounterTriggerComponent extends PositionComponent
    with HasGameReference<EoxGame> {
  final void Function(List<String> monsterIds) onEncounter;

  bool _inBattle = false;
  double _cooldown = 0;
  static const _cooldownDuration = 2.0;

  EncounterTriggerComponent({required this.onEncounter})
      : super(position: Vector2.zero(), size: Vector2.zero());

  void onBattleComplete() {
    _inBattle = false;
    _cooldown = _cooldownDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldown > 0) {
      _cooldown -= dt;
      return;
    }
    if (_inBattle) return;

    final config = sl<AppConfig>();
    if (config.legacyRealtimeCombat) return;

    final player = game.player;
    if (player == null || player.fsm.isDead) return;

    final playerAabb = Aabb(
      player.position.x + player.collOffset.x,
      player.position.y + player.collOffset.y,
      CombatEntityComponent.collW,
      CombatEntityComponent.collH,
    );

    final encountered = <String>[];
    for (final entity in game.entityComponents) {
      if (entity.team != Team.enemy) continue;
      if (entity.runtime.dead) continue;
      final monsterAabb = Aabb(
        entity.position.x + entity.collOffset.x,
        entity.position.y + entity.collOffset.y,
        CombatEntityComponent.collW,
        CombatEntityComponent.collH,
      );
      if (playerAabb.overlaps(monsterAabb)) {
        encountered.add(entity.entityId);
      }
    }

    if (encountered.isNotEmpty) {
      _inBattle = true;
      onEncounter(encountered);
    }
  }
}
