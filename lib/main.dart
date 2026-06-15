import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/eox_game.dart';
import 'ui/overlays/death_overlay.dart';
import 'ui/overlays/hud_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TBD-01 default: landscape.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const EoxApp());
}

class EoxApp extends StatelessWidget {
  const EoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EOXRPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GameWidget<EoxGame>.controlled(
          gameFactory: EoxGame.new,
          overlayBuilderMap: {
            'hud': (context, game) => HudOverlay(game: game),
            'death': (context, game) => DeathOverlay(game: game),
          },
          initialActiveOverlays: const ['hud'],
          loadingBuilder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Game failed to load:\n$error',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
