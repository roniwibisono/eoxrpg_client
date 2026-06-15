// ignore_for_file: constant_identifier_names

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

enum NpcType {
  merchant,
  blacksmith,
  innkeeper,
  ama_banker,
  quest_giver,
  lore_keeper,
  custodian_envoy,
  black_market,
  faction_relations,
  medic,
}

class NpcComponent extends PositionComponent with TapCallbacks {
  final String npcId;
  final NpcType npcType;
  final String displayName;
  final void Function(String npcId, String npcType)? onTap;

  NpcComponent({
    required this.npcId,
    required this.npcType,
    required this.displayName,
    required Vector2 position,
    this.onTap,
  }) : super(
          position: position,
          size: Vector2.all(32),
          anchor: Anchor.topLeft,
        );

  @override
  void onTapUp(TapUpEvent event) {
    onTap?.call(npcId, npcType.name);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final color = _colorForType(npcType);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      Paint()..color = color,
    );
    final letter = npcType.name[0].toUpperCase();
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2),
    );
  }

  Color _colorForType(NpcType type) {
    switch (type) {
      case NpcType.merchant:
        return const Color(0xFFFFD700);
      case NpcType.blacksmith:
        return const Color(0xFF808080);
      case NpcType.innkeeper:
        return const Color(0xFF8B4513);
      case NpcType.ama_banker:
        return const Color(0xFF4169E1);
      case NpcType.quest_giver:
        return const Color(0xFF32CD32);
      case NpcType.lore_keeper:
        return const Color(0xFF9370DB);
      case NpcType.custodian_envoy:
        return const Color(0xFF00CED1);
      case NpcType.black_market:
        return const Color(0xFF2F4F4F);
      case NpcType.faction_relations:
        return const Color(0xFF228B22);
      case NpcType.medic:
        return const Color(0xFFFF6347);
    }
  }
}
