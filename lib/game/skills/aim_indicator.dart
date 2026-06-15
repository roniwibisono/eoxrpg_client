import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../engine/combat/models.dart';
import 'skill_aim_controller.dart';

class AimIndicatorManager extends Component {
  final SkillAimController _controller;
  Component? _currentIndicator;

  AimIndicatorManager(this._controller);

  @override
  void update(double dt) {
    super.update(dt);
    _syncIndicator();
  }

  void _syncIndicator() {
    if (_controller.state != SkillAimState.aiming || _controller.activeSkill == null) {
      _removeCurrent();
      return;
    }

    final skill = _controller.activeSkill!;
    final totalDrag = _controller.aimDistance;
    final isQuickTap = totalDrag < 30.0;

    if (isQuickTap) {
      _removeCurrent();
      return;
    }

    if (_isCorrectIndicatorType(skill.shape)) {
      return;
    }

    _removeCurrent();

    Component indicator;
    switch (skill.shape) {
      case SkillShape.projectile:
        indicator = LineIndicator(controller: _controller);
      case SkillShape.melee:
        indicator = ConeIndicator(controller: _controller);
      case SkillShape.aoe:
        indicator = CircleIndicator(controller: _controller);
    }

    _currentIndicator = indicator;
    final w = findParent<World>();
    if (w != null) {
      w.add(indicator);
    }
  }

  bool _isCorrectIndicatorType(SkillShape shape) {
    return switch (shape) {
      SkillShape.projectile => _currentIndicator is LineIndicator,
      SkillShape.melee => _currentIndicator is ConeIndicator,
      SkillShape.aoe => _currentIndicator is CircleIndicator,
    };
  }

  void _removeCurrent() {
    _currentIndicator?.removeFromParent();
    _currentIndicator = null;
  }

  @override
  void onRemove() {
    _removeCurrent();
    super.onRemove();
  }
}

abstract class _BaseIndicator extends PositionComponent {
  final SkillAimController controller;

  _BaseIndicator({required this.controller})
      : super(
          priority: 200000,
          position: controller.aimWorldPos.clone(),
        );

  Color _rangeColor() {
    return controller.aimDistance <= (controller.activeSkill?.range ?? 320)
        ? const Color(0xCCFFFFFF)
        : const Color(0xCCFF4444);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(controller.aimWorldPos);
  }
}

class LineIndicator extends _BaseIndicator {
  LineIndicator({required super.controller});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final skill = controller.activeSkill;
    if (skill == null) return;

    final color = _rangeColor();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final start = Offset.zero;
    final end = Offset(skill.range, 0);

    canvas.drawLine(start, end, paint);

    final arrowSize = 12.0;
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - arrowSize, end.dy - arrowSize * 0.5)
      ..lineTo(end.dx - arrowSize, end.dy + arrowSize * 0.5)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = color);

    final currentEnd = Offset(controller.aimDistance, 0);
    if (currentEnd.dx > 0) {
      canvas.drawCircle(
        currentEnd,
        5,
        Paint()..color = const Color(0xCCFFD700),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final dir = controller.aimDirection;
    if (dir.length > 0.01) {
      angle = dir.screenAngle();
    }
  }
}

class ConeIndicator extends _BaseIndicator {
  ConeIndicator({required super.controller});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final skill = controller.activeSkill;
    if (skill == null) return;

    final range = skill.range;
    final color = _rangeColor();
    final halfArc = 1.0472;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: range), -halfArc, halfArc * 2, false)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final dir = controller.aimDirection;
    if (dir.length > 0.01) {
      angle = dir.screenAngle();
    }
  }
}

class CircleIndicator extends _BaseIndicator {
  CircleIndicator({required super.controller});

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final skill = controller.activeSkill;
    if (skill == null) return;

    final radius = skill.aoeRadius > 0 ? skill.aoeRadius : 60.0;
    final color = _rangeColor();

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()..color = const Color(0xCCFFD700),
    );
  }
}
