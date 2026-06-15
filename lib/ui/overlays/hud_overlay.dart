import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/eox_game.dart';

/// GDD §6.1: "FLUTTER OVERLAY: HP/MP bar ... dengar stream".
/// Listens to attack/combat streams for instant reaction and refreshes on a
/// coarse timer for regen ticks (MP regen has no discrete event).
class HudOverlay extends StatefulWidget {
  final EoxGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  StreamSubscription? _attackSub;
  StreamSubscription? _combatSub;
  Timer? _regenTimer;

  @override
  void initState() {
    super.initState();
    _attackSub =
        widget.game.orchestrator.attackStream.listen((_) => _refresh());
    _combatSub =
        widget.game.orchestrator.combatStream.listen((_) => _refresh());
    _regenTimer = Timer.periodic(
        const Duration(milliseconds: 250), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _attackSub?.cancel();
    _combatSub?.cancel();
    _regenTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rt = widget.game.orchestrator.entity('player');
    if (rt == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(
                label: 'HP',
                value: rt.hp,
                max: rt.stats.maxHp,
                color: const Color(0xFFE53935),
              ),
              const SizedBox(height: 4),
              _Bar(
                label: 'MP',
                value: rt.mp,
                max: rt.stats.maxMp,
                color: const Color(0xFF1E88E5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Stack(
          children: [
            Container(
              width: 160,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 160 * frac,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Text(
          '${value.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}
