import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class NodeComponent extends PositionComponent {
  final String nodeId;
  final String tier;
  final String ownerFaction;
  final double influence;
  final bool aiControlled;

  Color factionColor;

  Color? _originalColor;
  Color? _targetColor;
  double _colorTweenProgress = 0;
  static const _colorTweenDuration = 0.5;

  NodeComponent({
    required this.nodeId,
    required this.tier,
    required this.ownerFaction,
    required this.influence,
    required this.aiControlled,
    required this.factionColor,
    required Vector2 position,
  }) : super(position: position, anchor: Anchor.center);

  double get _radius {
    switch (tier) {
      case 'outer':
        return 8;
      case 'tactical':
        return 12;
      case 'core':
        return 16;
      case 'capital':
        return 20;
      default:
        return 8;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final extra = aiControlled ? 22.0 : 6.0;
    size = Vector2.all(_radius * 2 + extra);

    if (aiControlled) {
      final label = TextComponent(
        text: 'AI',
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.blueAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        anchor: Anchor.topCenter,
        position: Vector2(size.x / 2, size.y - 2),
      );
      add(label);
    }
  }

  void animateToColor(Color target) {
    if (target == factionColor) {
      _targetColor = null;
      _originalColor = null;
      return;
    }
    _originalColor = factionColor;
    _targetColor = target;
    _colorTweenProgress = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final tc = _targetColor;
    final oc = _originalColor;
    if (tc != null && oc != null) {
      _colorTweenProgress += dt / _colorTweenDuration;
      if (_colorTweenProgress >= 1.0) {
        factionColor = tc;
        _targetColor = null;
        _originalColor = null;
      } else {
        factionColor = Color.lerp(oc, tc, _colorTweenProgress)!;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);

    if (aiControlled) {
      canvas.drawCircle(
        center,
        _radius + 5,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    canvas.drawCircle(
      center,
      _radius,
      Paint()..color = factionColor,
    );

    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (influence > 0) {
      final arcRect = Rect.fromCircle(
          center: center, radius: _radius + 3);
      canvas.drawArc(
        arcRect,
        -1.5708,
        6.2832 * influence.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = factionColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  bool containsWorldPoint(Vector2 worldPoint) {
    final localCenter = absoluteCenter;
    return (worldPoint - localCenter).length <= _radius + 4;
  }
}
