import 'package:flutter/material.dart';

import '../../game/eox_game.dart';

/// Shown when the player dies. Death penalty severity = TBD-08 (open);
/// this MVP applies none — respawn is free at player_spawn.
class DeathOverlay extends StatelessWidget {
  final EoxGame game;
  const DeathOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YOU DIED',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE53935),
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: game.respawnPlayer,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Respawn'),
            ),
          ],
        ),
      ),
    );
  }
}
