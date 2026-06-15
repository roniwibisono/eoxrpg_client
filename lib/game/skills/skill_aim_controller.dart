import 'package:flame/components.dart';

import '../../engine/combat/models.dart';

enum SkillAimState { idle, aiming, fired, cancelled }

class SkillAimController {
  SkillAimState state = SkillAimState.idle;
  SkillDef? activeSkill;
  String? activeSkillId;

  Vector2 _aimOriginScreen = Vector2.zero();
  Vector2 _playerWorldPos = Vector2.zero();
  Vector2 _aimDirection = Vector2.zero();
  double _aimDistance = 0;

  static const double _tapDeadzone = 30.0;
  static const double _cancelDeadzone = 20.0;

  Vector2 get aimDirection => _aimDirection;
  double get aimDistance => _aimDistance;
  Vector2 get aimWorldPos => _playerWorldPos + _aimDirection * _aimDistance;
  bool get isQuickTap {
    return _aimDistance < _tapDeadzone;
  }

  void beginAim({
    required SkillDef skill,
    required String skillId,
    required Vector2 originScreen,
    required Vector2 playerWorldPos,
  }) {
    if (state == SkillAimState.aiming) return;
    activeSkill = skill;
    activeSkillId = skillId;
    _aimOriginScreen = originScreen.clone();
    _playerWorldPos = playerWorldPos.clone();
    _aimDirection = Vector2(1, 0);
    _aimDistance = 0;
    state = SkillAimState.aiming;
  }

  void updateAim(Vector2 dragScreenPos) {
    if (state != SkillAimState.aiming) return;
    final delta = dragScreenPos - _aimOriginScreen;
    final dist = delta.length;

    if (dist < _cancelDeadzone * 0.4) {
      _aimDirection = Vector2(1, 0);
      _aimDistance = 0;
      return;
    }

    _aimDirection = delta.normalized();
    _aimDistance = (activeSkill?.range ?? 320).clamp(0, activeSkill?.range ?? 320);
    if (dist > _cancelDeadzone) {
      _aimDistance = dist.clamp(0, activeSkill?.range ?? 320);
    }
  }

  void endAim() {
    if (state != SkillAimState.aiming) return;
    state = SkillAimState.fired;
  }

  void cancelAim() {
    state = SkillAimState.cancelled;
  }

  void reset() {
    state = SkillAimState.idle;
    activeSkill = null;
    activeSkillId = null;
    _aimDirection = Vector2.zero();
    _aimDistance = 0;
  }
}
