/// GDD §6.4 — shared combat-entity state machine (player & monster).
/// Transition rules (from Combat v2 boundary):
///   * `die` locks: once dead, no transition out, ever.
///   * `hit` interrupts anything EXCEPT `die`.
///   * `basicAttack` / `castSkill` are NOT cancelled by movement requests
///     (idle/walk/run are rejected until the action completes).
///   * Anything else is free-form.
enum EntityState { idle, walk, run, basicAttack, castSkill, hit, die }

class EntityStateMachine {
  EntityState _state;
  EntityStateMachine([this._state = EntityState.idle]);

  EntityState get state => _state;
  bool get isDead => _state == EntityState.die;
  bool get isActing =>
      _state == EntityState.basicAttack || _state == EntityState.castSkill;

  static const _movement = {EntityState.idle, EntityState.walk, EntityState.run};

  /// Attempts a transition. Returns true when the state actually changed
  /// (or was re-entered legally), false when the rule set rejected it.
  bool tryTransition(EntityState next) {
    if (_state == EntityState.die) return false; // die locks (no resurrection here)
    if (next == EntityState.die) {
      _state = next;
      return true;
    }
    if (next == EntityState.hit) {
      _state = next; // hit interrupts everything except die
      return true;
    }
    if (isActing && _movement.contains(next)) {
      return false; // movement cannot cancel an attack/cast
    }
    if (_state == EntityState.hit && isActingState(next)) {
      // starting a new action straight out of hit-stagger is allowed
      _state = next;
      return true;
    }
    _state = next;
    return true;
  }

  /// Components call this when a non-looping animation (attack/cast/hit)
  /// finished, releasing the lock back to idle.
  void notifyActionComplete() {
    if (_state == EntityState.die) return;
    if (isActing || _state == EntityState.hit) {
      _state = EntityState.idle;
    }
  }

  static bool isActingState(EntityState s) =>
      s == EntityState.basicAttack || s == EntityState.castSkill;
}
