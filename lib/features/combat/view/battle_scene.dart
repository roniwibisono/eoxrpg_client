import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../../engine/combat/battle_event.dart';
import '../../../engine/combat/battle_unit.dart';
import '../bloc/combat_bloc.dart';

class BattleScene extends World with HasGameReference<FlameGame> {
  final CombatBloc bloc;

  BattleScene({required this.bloc});

  StreamSubscription<BattleEvent>? _eventSub;
  StreamSubscription<CombatState>? _stateSub;

  final Map<String, _UnitSprite> _sprites = {};
  _TurnBanner? _banner;
  _EventQueue? _eventQueue;

  static const _partyStartX = 40.0;
  static const _enemyStartX = 500.0;
  static const _unitSpacingY = 88.0;
  static const _unitSize = 64.0;

  @override
  Future<void> onLoad() async {
    _eventQueue = _EventQueue(this);
    add(_eventQueue!);

    _stateSub = bloc.stream.listen(_onState);
    _eventSub = bloc.eventStream.listen(_onBattleEvent);

    _banner = _TurnBanner();
    add(_banner!);

    _buildLayout();
    add(_Background());
  }

  void _buildLayout() {
    _sprites.clear();

    final party = bloc.partyUnits.values.where((u) => !u.isDead).toList();
    for (var i = 0; i < party.length; i++) {
      final unit = party[i];
      final sprite = _UnitSprite(
        unit: unit,
        position: Vector2(_partyStartX, 60.0 + i * _unitSpacingY),
        size: Vector2.all(_unitSize),
        color: _partyColor(i),
      );
      _sprites[unit.id] = sprite;
      add(sprite);
    }

    final enemies = bloc.enemyUnits.values.where((u) => !u.isDead).toList();
    for (var i = 0; i < enemies.length; i++) {
      final unit = enemies[i];
      final sprite = _UnitSprite(
        unit: unit,
        position: Vector2(_enemyStartX, 60.0 + i * _unitSpacingY),
        size: Vector2.all(_unitSize),
        color: _enemyColor(i),
      );
      _sprites[unit.id] = sprite;
      add(sprite);
    }
  }

  void _onState(CombatState state) {
    switch (state.phase) {
      case CombatPhase.playerTurn:
        _banner?.label = 'YOUR TURN';
        _banner?.color = const Color(0xFF4CAF50);
        _banner?.setVisible(true);
      case CombatPhase.allyTurn:
        _banner?.label = 'ALLY TURN';
        _banner?.color = const Color(0xFF42A5F5);
        _banner?.setVisible(true);
      case CombatPhase.enemyTurn:
        _banner?.label = 'ENEMY TURN';
        _banner?.color = const Color(0xFFEF5350);
        _banner?.setVisible(true);
      case CombatPhase.animating:
        _banner?.setVisible(false);
      case CombatPhase.victory:
        _banner?.label = 'VICTORY';
        _banner?.color = const Color(0xFFFFD600);
        _banner?.setVisible(true);
      case CombatPhase.defeat:
        _banner?.label = 'DEFEAT';
        _banner?.color = const Color(0xFFB71C1C);
        _banner?.setVisible(true);
      case CombatPhase.fled:
        _banner?.label = 'FLED';
        _banner?.color = const Color(0xFF78909C);
        _banner?.setVisible(true);
      case CombatPhase.initial:
        _banner?.setVisible(false);
    }
  }

  void _onBattleEvent(BattleEvent event) {
    _eventQueue?.enqueue(event);
  }

  Color _partyColor(int i) {
    const colors = [
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
    ];
    return colors[i % colors.length];
  }

  Color _enemyColor(int i) {
    const colors = [
      Color(0xFFE53935),
      Color(0xFF8E24AA),
      Color(0xFF455A64),
      Color(0xFFBF360C),
      Color(0xFF2E7D32),
    ];
    return colors[i % colors.length];
  }

  @override
  void onRemove() {
    _eventSub?.cancel();
    _stateSub?.cancel();
    super.onRemove();
  }
}

class _Background extends PositionComponent {
  _Background() : super(size: Vector2(640, 480), priority: -1000);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      size.toRect(),
      Paint()..color = const Color(0xFF1A1A2E),
    );
  }
}

class _UnitSprite extends PositionComponent {
  final BattleUnit unit;
  final Color color;
  bool _flashing = false;
  bool _dead = false;
  double _deathOpacity = 1.0;

  _UnitSprite({
    required this.unit,
    required super.position,
    required super.size,
    required this.color,
  });

  void flash() {
    _flashing = true;
    Future.delayed(const Duration(milliseconds: 200), () {
      _flashing = false;
    });
  }

  void die() {
    _dead = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_dead && _deathOpacity > 0) {
      _deathOpacity = (_deathOpacity - dt * 2.0).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = _flashing
          ? const Color(0xFFFFFFFF)
          : color.withValues(alpha: _dead ? _deathOpacity : 1.0);

    canvas.drawRect(size.toRect(), paint);

    final tp = TextPaint(
      style: const TextStyle(
        fontSize: 9,
        color: Color(0xFFFFFFFF),
        fontWeight: FontWeight.bold,
      ),
    );
    tp.render(
      canvas,
      unit.name,
      Vector2(4, size.y - 16),
    );

    final barW = size.x - 8;
    final barH = 4.0;
    final barX = 4.0;
    final barY = size.y + 4;

    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barW, barH),
      Paint()..color = const Color(0xAA000000),
    );
    final hpFrac =
        (unit.hp / unit.baseStats.maxHp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barW * hpFrac, barH),
      Paint()..color = const Color(0xFFE53935),
    );

    canvas.drawRect(
      Rect.fromLTWH(barX, barY + barH + 1, barW, barH),
      Paint()..color = const Color(0xAA000000),
    );
    final mpFrac =
        unit.baseStats.maxMp > 0
            ? (unit.mp / unit.baseStats.maxMp).clamp(0.0, 1.0)
            : 0.0;
    canvas.drawRect(
      Rect.fromLTWH(barX, barY + barH + 1, barW * mpFrac, barH),
      Paint()..color = const Color(0xFF1E88E5),
    );
  }
}

class _TurnBanner extends PositionComponent {
  String label = '';
  Color color = const Color(0xFFFFFFFF);
  bool _visible = false;

  _TurnBanner()
      : super(
          position: Vector2(320, 30),
          size: Vector2(200, 36),
          anchor: Anchor.topCenter,
          priority: 100,
        );

  void setVisible(bool v) {
    _visible = v;
  }

  @override
  void render(Canvas canvas) {
    if (!_visible || label.isEmpty) return;
    final bgRect = RRect.fromRectAndRadius(
      size.toRect().translate(-size.x / 2, 0),
      const Radius.circular(6),
    );
    canvas.drawRRect(bgRect, Paint()..color = color.withValues(alpha: 0.85));
    final tp = TextPaint(
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFFFFFFFF),
        fontWeight: FontWeight.bold,
      ),
    );
    final textX = size.x / 2 - label.length * 5.0;
    tp.render(canvas, label, Vector2(textX, 8));
  }
}

class _EventQueue extends Component {
  static const _eventDelay = Duration(milliseconds: 450);

  final BattleScene _scene;
  final List<BattleEvent> _queue = [];
  bool _processing = false;

  _EventQueue(this._scene);

  void enqueue(BattleEvent event) {
    _queue.add(event);
    if (!_processing) {
      _processNext();
    }
  }

  Future<void> _processNext() async {
    _processing = true;
    while (_queue.isNotEmpty) {
      final event = _queue.removeAt(0);
      await _handleEvent(event);
      await Future.delayed(_eventDelay);
    }
    _processing = false;
  }

  Future<void> _handleEvent(BattleEvent event) async {
    switch (event) {
      case DamageEvent():
        final caster = _scene._sprites[event.casterId];
        if (caster != null) caster.flash();
        final target = _scene._sprites[event.targetId];
        if (target != null) {
          _scene.add(_DamageText(
            text: _damageLabel(event.outcome, event.damage),
            color: _outcomeColor(event.outcome),
            position: target.position.clone()..y -= 20,
          ));
        }
      case HealEvent():
        final target = _scene._sprites[event.targetId];
        if (target != null) {
          _scene.add(_DamageText(
            text: '+${event.amount}',
            color: const Color(0xFF66BB6A),
            position: target.position.clone()..y -= 20,
          ));
        }
      case UnitDiedEvent():
        final sprite = _scene._sprites[event.unitId];
        if (sprite != null) sprite.die();
      case TurnStartEvent():
      case ActionSelectedEvent():
      case DefendEvent():
      case FleeAttemptEvent():
      case StatusAppliedEvent():
      case StatusExpiredEvent():
      case BattleEndEvent():
        break;
    }
  }

  String _damageLabel(AttackOutcome outcome, int damage) {
    switch (outcome) {
      case AttackOutcome.crit:
        return '$damage!';
      case AttackOutcome.hit:
        return '$damage';
      case AttackOutcome.miss:
        return 'MISS';
      case AttackOutcome.dodge:
        return 'DODGE';
      case AttackOutcome.absorb:
        return 'ABSORB';
    }
  }

  Color _outcomeColor(AttackOutcome outcome) {
    switch (outcome) {
      case AttackOutcome.hit:
        return const Color(0xFFFFFFFF);
      case AttackOutcome.crit:
        return const Color(0xFFFF9100);
      case AttackOutcome.miss:
        return const Color(0xFF9E9E9E);
      case AttackOutcome.dodge:
        return const Color(0xFF18FFFF);
      case AttackOutcome.absorb:
        return const Color(0xFFB388FF);
    }
  }
}

class _DamageText extends PositionComponent {
  final String text;
  final Color color;
  double _age = 0;
  static const _lifetime = 0.7;

  _DamageText({
    required this.text,
    required this.color,
    required super.position,
  }) : super(anchor: Anchor.bottomCenter, priority: 200);

  @override
  void update(double dt) {
    _age += dt;
    position.y -= 40 * dt;
    if (_age >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1.0 - _age / _lifetime).clamp(0.0, 1.0);
    final tp = TextPaint(
      style: TextStyle(
        fontSize: 14,
        color: color.withValues(alpha: alpha),
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Color(0xFF000000), blurRadius: 2),
        ],
      ),
    );
    tp.render(canvas, text, Vector2.zero());
  }
}
