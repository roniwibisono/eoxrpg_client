import 'dart:math' as math;

import '../core/vec2.dart';

/// D2 / GDD §7: player movement = continuous joystick + per-frame AABB
/// resolution against the Tiled `Collision` object layer. PURE function,
/// fully unit-testable, no Flame types.
class Aabb {
  final double x, y, w, h; // x,y = top-left
  const Aabb(this.x, this.y, this.w, this.h);

  double get left => x;
  double get top => y;
  double get right => x + w;
  double get bottom => y + h;

  bool overlaps(Aabb o) =>
      left < o.right && right > o.left && top < o.bottom && bottom > o.top;

  Aabb movedTo(double nx, double ny) => Aabb(nx, ny, w, h);

  @override
  String toString() => 'Aabb($x,$y,$w,$h)';
}

/// Resolves [delta] movement of [mover] against [solids].
///
/// Axis-separated resolution: move X, push out; move Y, push out.
/// This is what produces natural WALL-SLIDE (the free axis keeps moving
/// while the blocked axis is clamped).
///
/// Sub-stepping: if |delta| on an axis exceeds half the mover size, the move
/// is split into steps to prevent tunneling at low frame rates.
Vec2 resolveAabbMovement(Aabb mover, Vec2 delta, Iterable<Aabb> solids) {
  var px = mover.x;
  var py = mover.y;

  final stepsX = mover.w > 0 ? (delta.x.abs() / (mover.w / 2)).ceil() : 1;
  final stepsY = mover.h > 0 ? (delta.y.abs() / (mover.h / 2)).ceil() : 1;
  final steps = math.max(1, math.min(64, math.max(stepsX, stepsY)));

  final sx = delta.x / steps;
  final sy = delta.y / steps;

  for (var i = 0; i < steps; i++) {
    // X axis
    px += sx;
    var box = mover.movedTo(px, py);
    for (final s in solids) {
      if (!box.overlaps(s)) continue;
      px = sx > 0 ? s.left - mover.w : s.right;
      box = mover.movedTo(px, py);
    }
    // Y axis
    py += sy;
    box = mover.movedTo(px, py);
    for (final s in solids) {
      if (!box.overlaps(s)) continue;
      py = sy > 0 ? s.top - mover.h : s.bottom;
      box = mover.movedTo(px, py);
    }
  }
  return Vec2(px, py);
}
