import 'dart:math' as math;

/// D7: code is N-directional. Default 8 directions; if the art only ships
/// 4 rows, the loader maps diagonals to a cardinal direction — no code change.
///
/// ROW ORDER IN SPRITE SHEETS IS THIS ENUM ORDER (see ASSET_SPEC.md):
/// 8-dir sheet rows: down, downLeft, left, upLeft, up, upRight, right, downRight
/// 4-dir sheet rows: down, left, up, right
enum Direction8 {
  down,
  downLeft,
  left,
  upLeft,
  up,
  upRight,
  right,
  downRight;

  /// Resolve a facing direction from a movement/aim vector.
  /// Screen convention: +x = right, +y = DOWN (Flame/Flutter coordinates).
  /// Returns [fallback] when the vector is (near) zero.
  static Direction8 fromVector(double dx, double dy,
      {Direction8 fallback = Direction8.down}) {
    if (dx * dx + dy * dy < 1e-9) return fallback;
    // atan2 with screen-y. 0 rad = right, positive = downward (clockwise).
    final angle = math.atan2(dy, dx); // -pi..pi
    // 8 sectors of 45°, centered on each direction.
    final sector = ((angle + math.pi) / (math.pi / 4)).round() % 8;
    // sector 0 => angle -pi => pointing LEFT.
    const order = [
      Direction8.left,      // -180°
      Direction8.upLeft,    // -135°
      Direction8.up,        // -90°
      Direction8.upRight,   // -45°
      Direction8.right,     //   0°
      Direction8.downRight, //  45°
      Direction8.down,      //  90°
      Direction8.downLeft,  // 135°
    ];
    return order[sector];
  }

  /// D7 fallback: collapse diagonals to a cardinal direction.
  /// Rule (documented, deterministic): diagonals collapse to their
  /// HORIZONTAL component (left/right). Rationale: in top-down RO-likes,
  /// horizontal facing reads better while strafing than vertical.
  /// PLACEHOLDER decision — flip to vertical priority here if art direction
  /// disagrees; nothing else in the codebase cares.
  Direction8 to4() {
    switch (this) {
      case Direction8.downLeft:
      case Direction8.upLeft:
        return Direction8.left;
      case Direction8.downRight:
      case Direction8.upRight:
        return Direction8.right;
      default:
        return this;
    }
  }

  bool get isCardinal =>
      this == Direction8.down ||
      this == Direction8.left ||
      this == Direction8.up ||
      this == Direction8.right;

  /// Row index inside a 4-direction sheet (down, left, up, right).
  static const cardinalRowOrder = [
    Direction8.down,
    Direction8.left,
    Direction8.up,
    Direction8.right,
  ];
}
