import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../engine/combat/battle_unit.dart';
import '../bloc/combat_bloc.dart';

class BattleOverlay extends StatelessWidget {
  const BattleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CombatBloc, CombatState>(
      builder: (context, state) {
        if (state.phase == CombatPhase.initial) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            _HpMpBars(units: state.partyUnits),
            if (state.phase == CombatPhase.playerTurn)
              _CommandMenu(
                bloc: context.read<CombatBloc>(),
                activeUnitId: state.activeUnitId,
                units: state.units,
              ),
            if (state.phase == CombatPhase.victory ||
                state.phase == CombatPhase.defeat ||
                state.phase == CombatPhase.fled)
              _EndBanner(phase: state.phase),
          ],
        );
      },
    );
  }
}

class _HpMpBars extends StatelessWidget {
  final Map<String, BattleUnit> units;
  const _HpMpBars({required this.units});

  @override
  Widget build(BuildContext context) {
    final list = units.values.toList();
    return Positioned(
      left: 8,
      top: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((u) => _UnitBar(unit: u)).toList(),
      ),
    );
  }
}

class _UnitBar extends StatelessWidget {
  final BattleUnit unit;
  const _UnitBar({required this.unit});

  @override
  Widget build(BuildContext context) {
    if (unit.isDead) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unit.name,
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBar(
                value: unit.hp,
                max: unit.baseStats.maxHp,
                color: const Color(0xFFE53935),
              ),
              const SizedBox(width: 4),
              _MiniBar(
                value: unit.mp,
                max: unit.baseStats.maxMp,
                color: const Color(0xFF1E88E5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final int value;
  final int max;
  final Color color;
  const _MiniBar({
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: 80,
      height: 6,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: frac,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OverlayView { menu, targetPick, skillPick }

class _CommandMenu extends StatefulWidget {
  final CombatBloc bloc;
  final String? activeUnitId;
  final Map<String, BattleUnit> units;

  const _CommandMenu({
    required this.bloc,
    required this.activeUnitId,
    required this.units,
  });

  @override
  State<_CommandMenu> createState() => _CommandMenuState();
}

class _CommandMenuState extends State<_CommandMenu> {
  _OverlayView _view = _OverlayView.menu;

  BattleUnit? get _activeUnit =>
      widget.activeUnitId != null ? widget.units[widget.activeUnitId] : null;

  @override
  void didUpdateWidget(covariant _CommandMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeUnitId != oldWidget.activeUnitId) {
      _view = _OverlayView.menu;
    }
  }

  String? _selectedSkillId;
  String? _selectedItemId;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xDD1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_view) {
      case _OverlayView.menu:
        return _buildMenu();
      case _OverlayView.targetPick:
        return _buildTargetPicker();
      case _OverlayView.skillPick:
        return _buildSkillPicker();
    }
  }

  Widget _buildMenu() {
    final unit = _activeUnit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('COMMAND', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MenuButton(label: 'Attack', onTap: _onAttack),
            _MenuButton(label: 'Skills', onTap: _onSkills),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MenuButton(label: 'Defend', onTap: () => widget.bloc.defend()),
            _MenuButton(
              label: 'Item',
              onTap: unit != null && unit.itemCounts.isNotEmpty ? _onItem : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MenuButton(label: 'Flee', onTap: () => widget.bloc.flee()),
          ],
        ),
      ],
    );
  }

  void _onAttack() {
    _selectedSkillId = '';
    _view = _OverlayView.targetPick;
    setState(() {});
  }

  void _onSkills() {
    final unit = _activeUnit;
    if (unit == null || unit.skillIds.isEmpty) return;
    _view = _OverlayView.skillPick;
    setState(() {});
  }

  void _onItem() {
    final unit = _activeUnit;
    if (unit == null || unit.itemCounts.isEmpty) return;
    _selectedItemId = unit.itemCounts.keys.first;
    _view = _OverlayView.targetPick;
    setState(() {});
  }

  Widget _buildTargetPicker() {
    final enemies = widget.units.values
        .where((u) => u.role == UnitRole.enemy && !u.isDead)
        .toList();
    final allies = widget.units.values
        .where((u) => u.role != UnitRole.enemy && !u.isDead && u.id != widget.activeUnitId)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                _view = _OverlayView.menu;
                setState(() {});
              },
              child: const Text('< Back',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            const Spacer(),
            const Text('TARGET',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        if (enemies.isNotEmpty) ...[
          const Text('Enemies',
              style: TextStyle(color: Colors.redAccent, fontSize: 10)),
          const SizedBox(height: 4),
          ...enemies.map((e) => _TargetTile(
                unit: e,
                onTap: () => _selectTarget(e.id),
              )),
        ],
        if (allies.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('Allies',
              style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10)),
          const SizedBox(height: 4),
          ...allies.map((a) => _TargetTile(
                unit: a,
                onTap: () => _selectTarget(a.id),
              )),
        ],
      ],
    );
  }

  void _selectTarget(String targetId) {
    if (_selectedItemId != null) {
      widget.bloc.useItem(_selectedItemId!, targetId);
    } else if (_selectedSkillId != null) {
      widget.bloc.selectAttack(_selectedSkillId!, targetId);
    }
    _view = _OverlayView.menu;
    _selectedSkillId = null;
    _selectedItemId = null;
    setState(() {});
  }

  Widget _buildSkillPicker() {
    final unit = _activeUnit;
    if (unit == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                _view = _OverlayView.menu;
                setState(() {});
              },
              child: const Text('< Back',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            const Spacer(),
            const Text('SKILLS',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        ...unit.skillIds.map((skillId) {
          final onCooldown = unit.skillCooldowns.containsKey(skillId);
          return _SkillTile(
            skillId: skillId,
            mpCost: 0,
            onCooldown: onCooldown,
            onTap: onCooldown
                ? null
                : () {
                    _selectedSkillId = skillId;
                    _view = _OverlayView.targetPick;
                    setState(() {});
                  },
          );
        }),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _MenuButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 34,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white12 : Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onTap != null ? Colors.white30 : Colors.white10,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onTap != null ? Colors.white : Colors.white30,
          ),
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  final BattleUnit unit;
  final VoidCallback onTap;
  const _TargetTile({required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 30,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(
              unit.name,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            const Spacer(),
            Text(
              'HP ${unit.hp}/${unit.baseStats.maxHp}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  final String skillId;
  final int mpCost;
  final bool onCooldown;
  final VoidCallback? onTap;

  const _SkillTile({
    required this.skillId,
    required this.mpCost,
    required this.onCooldown,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 30,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white12 : Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(
              skillId,
              style: TextStyle(
                fontSize: 11,
                color: onTap != null ? Colors.white : Colors.white30,
              ),
            ),
            if (mpCost > 0) ...[
              const SizedBox(width: 4),
              Text(
                '${mpCost}MP',
                style: const TextStyle(fontSize: 9, color: Color(0xFF64B5F6)),
              ),
            ],
            const Spacer(),
            if (onCooldown)
              const Text('CD',
                  style: TextStyle(fontSize: 9, color: Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }
}

class _EndBanner extends StatelessWidget {
  final CombatPhase phase;
  const _EndBanner({required this.phase});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    switch (phase) {
      case CombatPhase.victory:
        text = 'VICTORY';
        color = const Color(0xFFFFD600);
      case CombatPhase.defeat:
        text = 'DEFEAT';
        color = const Color(0xFFB71C1C);
      case CombatPhase.fled:
        text = 'FLED';
        color = const Color(0xFF78909C);
      default:
        return const SizedBox.shrink();
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
