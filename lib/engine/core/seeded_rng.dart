import 'dart:math' as math;

/// GDD §8.3 action item: CombatEngine must be deterministic with a SEEDABLE
/// RNG so the exact same resolution can run server-side later.
/// Never read a global unseeded Random inside the engine.
class SeededRng {
  final math.Random _r;
  final int seed;
  SeededRng(this.seed) : _r = math.Random(seed);

  double nextDouble() => _r.nextDouble();

  /// Uniform double in [min, max).
  double range(double min, double max) => min + _r.nextDouble() * (max - min);

  bool chance(double p) => _r.nextDouble() < p;
}
