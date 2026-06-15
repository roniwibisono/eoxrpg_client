import 'dart:math' as math;

/// Minimal 2D vector for the PURE DART engine layer.
/// Deliberately independent from Flame's Vector2 so the engine can run
/// server-side later (GDD §8.3) without any Flutter/Flame dependency.
class Vec2 {
  final double x;
  final double y;
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);

  double get length2 => x * x + y * y;
  double get length => math.sqrt(length2);

  Vec2 normalized() {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  double distanceTo(Vec2 o) => (this - o).length;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}
