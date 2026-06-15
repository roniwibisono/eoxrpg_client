import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/combat/models.dart';
import '../eox_game.dart';

/// Floating combat text. Color per outcome (Combat v2 §6.3):
/// hit=white, crit=orange+larger, miss=grey "MISS", dodge=cyan "DODGE",
/// DoT=purple. Rises and fades over [lifetime].
class DamageTextComponent extends TextComponent {
  static const lifetime = 0.8;
  double _age = 0;

  DamageTextComponent.fromResult(AttackResult r, Vector2 worldPos)
      : this._(_textFor(r), _colorFor(r.outcome),
            r.outcome == AttackOutcome.crit ? 18.0 : 14.0, worldPos);

  DamageTextComponent.dot(double damage, Vector2 worldPos)
      : this._(damage.toStringAsFixed(0), const Color(0xFFB388FF), 13.0,
            worldPos);

  DamageTextComponent._(
      String text, Color color, double fontSize, Vector2 worldPos)
      : super(
          text: text,
          position: worldPos,
          anchor: Anchor.bottomCenter,
          priority: EoxGame.kOverheadPriority + 1,
          textRenderer: TextPaint(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: color,
              shadows: const [
                Shadow(color: Color(0xFF000000), blurRadius: 2),
              ],
            ),
          ),
        );

  static String _textFor(AttackResult r) {
    switch (r.outcome) {
      case AttackOutcome.miss:
        return 'MISS';
      case AttackOutcome.dodge:
        return 'DODGE';
      case AttackOutcome.crit:
        return '${r.damage.toStringAsFixed(0)}!';
      case AttackOutcome.hit:
        return r.damage.toStringAsFixed(0);
    }
  }

  static Color _colorFor(AttackOutcome o) {
    switch (o) {
      case AttackOutcome.hit:
        return const Color(0xFFFFFFFF);
      case AttackOutcome.crit:
        return const Color(0xFFFF9100);
      case AttackOutcome.miss:
        return const Color(0xFF9E9E9E);
      case AttackOutcome.dodge:
        return const Color(0xFF18FFFF);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= 34 * dt;
    if (_age >= lifetime) {
      removeFromParent();
      return;
    }
    final t = (_age / lifetime).clamp(0.0, 1.0);
    final style = (textRenderer as TextPaint).style;
    textRenderer = TextPaint(
      style: style.copyWith(
        color: style.color!.withValues(alpha: 1.0 - t * t),
      ),
    );
  }
}
