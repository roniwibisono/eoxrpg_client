/// Pure-Dart cooldown tracking per entity. Cooldown values are PLACEHOLDER
/// (D9 / TBD-06) — they live on SkillDef, this class only counts them down.
class CooldownManager {
  final Map<String, double> _remaining = {}; // skillId -> seconds left

  bool isReady(String skillId) => (_remaining[skillId] ?? 0) <= 0;

  double remaining(String skillId) =>
      (_remaining[skillId] ?? 0).clamp(0, double.infinity);

  /// Fraction 0..1 for HUD cooldown sweeps (0 = ready).
  double fraction(String skillId, double total) =>
      total <= 0 ? 0 : (remaining(skillId) / total).clamp(0.0, 1.0);

  void trigger(String skillId, double seconds) {
    _remaining[skillId] = seconds;
  }

  void tick(double dt) {
    for (final k in _remaining.keys.toList()) {
      final v = _remaining[k]! - dt;
      if (v <= 0) {
        _remaining.remove(k);
      } else {
        _remaining[k] = v;
      }
    }
  }
}

/// D8 / Combat v2 §5: WAJIB dedup — one cast = ONE damage application per
/// target, never one per overlapping frame. Every cast gets a unique castId;
/// hitbox components ask [register] before calling resolveHit.
class HitDedup {
  final _seen = <String>{};

  /// Returns true the FIRST time this (castId, targetId) pair is seen.
  bool register(int castId, String targetId) =>
      _seen.add('$castId:$targetId');

  /// Call when a cast's hitbox is disposed to keep the set bounded.
  void releaseCast(int castId) {
    _seen.removeWhere((k) => k.startsWith('$castId:'));
  }
}
