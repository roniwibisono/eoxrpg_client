import 'dart:collection';

import 'aabb.dart';

/// GDD §7 / D2: A* is for MONSTER CHASE ONLY. The player is never pathed.
/// Grid is built from the Tiled `Collision` object layer: a cell is blocked
/// when it intersects any collision rectangle.
class NavGrid {
  final int cols, rows;
  final double cellSize;
  final List<bool> _blocked; // row-major

  NavGrid._(this.cols, this.rows, this.cellSize, this._blocked);

  factory NavGrid.fromCollision({
    required double worldWidth,
    required double worldHeight,
    required double cellSize,
    required Iterable<Aabb> solids,
  }) {
    final cols = (worldWidth / cellSize).ceil();
    final rows = (worldHeight / cellSize).ceil();
    final blocked = List<bool>.filled(cols * rows, false);
    for (final s in solids) {
      final c0 = (s.left / cellSize).floor().clamp(0, cols - 1);
      final c1 = ((s.right - 0.001) / cellSize).floor().clamp(0, cols - 1);
      final r0 = (s.top / cellSize).floor().clamp(0, rows - 1);
      final r1 = ((s.bottom - 0.001) / cellSize).floor().clamp(0, rows - 1);
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          blocked[r * cols + c] = true;
        }
      }
    }
    return NavGrid._(cols, rows, cellSize, blocked);
  }

  bool isBlocked(int c, int r) {
    if (c < 0 || r < 0 || c >= cols || r >= rows) return true;
    return _blocked[r * cols + c];
  }

  (int, int) worldToCell(double x, double y) =>
      ((x / cellSize).floor(), (y / cellSize).floor());

  /// Cell center in world coordinates.
  (double, double) cellCenter(int c, int r) =>
      (c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);

  /// 8-directional A*, NO corner cutting (a diagonal step requires both
  /// adjacent cardinals to be free). Returns a list of (col,row) cells from
  /// start (exclusive) to goal (inclusive), or null when unreachable.
  List<(int, int)>? findPath((int, int) start, (int, int) goal,
      {int maxExpansions = 4000}) {
    if (isBlocked(goal.$1, goal.$2) || isBlocked(start.$1, start.$2)) {
      return null;
    }
    if (start == goal) return const [];

    int idx(int c, int r) => r * cols + c;

    final open = SplayTreeMap<double, List<int>>();
    final gScore = <int, double>{idx(start.$1, start.$2): 0};
    final cameFrom = <int, int>{};
    final closed = <int>{};

    void push(double f, int node) =>
        open.putIfAbsent(f, () => <int>[]).add(node);

    double heuristic(int c, int r) {
      final dc = (c - goal.$1).abs();
      final dr = (r - goal.$2).abs();
      // octile distance
      final mn = dc < dr ? dc : dr;
      final mx = dc < dr ? dr : dc;
      return mx - mn + mn * 1.41421356;
    }

    push(heuristic(start.$1, start.$2), idx(start.$1, start.$2));
    var expansions = 0;

    while (open.isNotEmpty && expansions < maxExpansions) {
      final firstKey = open.firstKey()!;
      final bucket = open[firstKey]!;
      final current = bucket.removeLast();
      if (bucket.isEmpty) open.remove(firstKey);
      if (closed.contains(current)) continue;
      closed.add(current);
      expansions++;

      final cc = current % cols;
      final cr = current ~/ cols;
      if (cc == goal.$1 && cr == goal.$2) {
        // reconstruct
        final path = <(int, int)>[];
        var n = current;
        while (cameFrom.containsKey(n)) {
          path.add((n % cols, n ~/ cols));
          n = cameFrom[n]!;
        }
        return path.reversed.toList();
      }

      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dc == 0 && dr == 0) continue;
          final nc = cc + dc;
          final nr = cr + dr;
          if (isBlocked(nc, nr)) continue;
          if (dc != 0 && dr != 0) {
            // no corner cutting
            if (isBlocked(cc + dc, cr) || isBlocked(cc, cr + dr)) continue;
          }
          final ni = idx(nc, nr);
          if (closed.contains(ni)) continue;
          final cost = (dc != 0 && dr != 0) ? 1.41421356 : 1.0;
          final tentative = gScore[current]! + cost;
          if (tentative < (gScore[ni] ?? double.infinity)) {
            gScore[ni] = tentative;
            cameFrom[ni] = current;
            push(tentative + heuristic(nc, nr), ni);
          }
        }
      }
    }
    return null;
  }
}
