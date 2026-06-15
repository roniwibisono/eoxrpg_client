import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import '../../game/components/monster_component.dart';
import '../../game/eox_game.dart';
import '../../game/npc_component.dart';
import 'encounter_trigger.dart';

class WorldGame extends EoxGame {
  final List<NpcComponent> npcs = [];
  EncounterTriggerComponent? _encounterTrigger;

  String? dialogNpcId;
  String? dialogNpcName;
  String? dialogNpcType;
  String? dialogDialogueText;

  void Function(List<String> monsterIds)? onEncounterBattle;

  WorldGame({super.mapName, super.engine, this.onEncounterBattle});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      await _loadNpcs();
    } catch (e) {
      // NPC loading is non-critical
    }

    try {
      _registerEncounterTrigger();
    } catch (e) {
      // encounter trigger is non-critical
    }
  }

  Future<void> _loadNpcs() async {
    final String jsonString;
    try {
      jsonString = await rootBundle.loadString('assets/data/nexus_city.json');
    } catch (_) {
      return;
    }
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final npcList = data['npcs'] as List<dynamic>? ?? [];

    for (final npcData in npcList) {
      try {
        final npc = npcData as Map<String, dynamic>;
        final npcType = _parseNpcType(npc['type'] as String? ?? '');
        if (npcType == null) continue;
        final pos = npc['position'] as Map<String, dynamic>?;
        if (pos == null) continue;
        final x = (pos['x'] as num?)?.toDouble() ?? 0;
        final y = (pos['y'] as num?)?.toDouble() ?? 0;
        final component = NpcComponent(
          npcId: npc['npc_id'] as String? ?? '',
          npcType: npcType,
          displayName: npc['name'] as String? ?? '',
          position: Vector2(x, y),
          onTap: _onNpcTapped,
        );
        npcs.add(component);
        world.add(component);
      } catch (_) {}
    }
  }

  NpcType? _parseNpcType(String type) {
    switch (type) {
      case 'merchant':
        return NpcType.merchant;
      case 'blacksmith':
        return NpcType.blacksmith;
      case 'innkeeper':
        return NpcType.innkeeper;
      case 'ama_banker':
        return NpcType.ama_banker;
      case 'quest_giver':
        return NpcType.quest_giver;
      case 'lore_keeper':
        return NpcType.lore_keeper;
      case 'custodian_envoy':
        return NpcType.custodian_envoy;
      case 'black_market':
        return NpcType.black_market;
      case 'faction_relations':
        return NpcType.faction_relations;
      case 'medic':
        return NpcType.medic;
      default:
        return null;
    }
  }

  void _registerEncounterTrigger() {
    _encounterTrigger = EncounterTriggerComponent(
      onEncounter: _onEncounterDetected,
    );
    world.add(_encounterTrigger!);
  }

  void _onEncounterDetected(List<String> entityIds) {
    final monsterTypeIds = <String>[];
    final matched = <MonsterComponent>[];
    for (final e in entityComponents) {
      if (e is MonsterComponent && entityIds.contains(e.entityId) && !e.runtime.dead) {
        monsterTypeIds.add(e.monsterId);
        matched.add(e);
      }
    }

    for (final monster in matched) {
      final sp = monster.spawnPoint;
      final mId = monster.monsterId;
      monster.removeFromParent();
      scheduleMonsterRespawn(mId, sp);
    }
    _encounterTrigger?.onBattleComplete();

    if (onEncounterBattle != null && monsterTypeIds.isNotEmpty) {
      onEncounterBattle!(monsterTypeIds);
    }
  }

  void _onNpcTapped(String npcId, String npcType) {
    NpcComponent? found;
    for (final n in npcs) {
      if (n.npcId == npcId) {
        found = n;
        break;
      }
    }
    if (found == null) return;
    final npc = found;
    dialogNpcId = npc.npcId;
    dialogNpcName = npc.displayName;
    dialogNpcType = npc.npcType.name;
    dialogDialogueText = 'dlg.nexus.${npc.npcType.name}';
    overlays.add('dialog');
  }

  void closeDialog() {
    overlays.remove('dialog');
    dialogNpcId = null;
    dialogNpcName = null;
    dialogNpcType = null;
    dialogDialogueText = null;
  }
}
