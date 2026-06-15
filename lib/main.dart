import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'features/combat/view/battle_screen.dart';
import 'features/world/world_game.dart';
import 'ui/overlays/death_overlay.dart';
import 'ui/overlays/dialog_overlay.dart';
import 'ui/overlays/hud_overlay.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await initCore(AppConfig.dev());
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
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: GameWidget<WorldGame>.controlled(
          gameFactory: WorldGame.new,
          overlayBuilderMap: {
            'hud': (context, game) {
              game.onEncounterBattle ??= (monsterIds) {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => BattleScreen(monsterIds: monsterIds),
                  ),
                );
              };
              return HudOverlay(game: game);
            },
            'death': (context, game) => DeathOverlay(game: game),
            'dialog': (context, game) => DialogOverlay(
                  npcName: game.dialogNpcName ?? '',
                  npcType: game.dialogNpcType ?? '',
                  dialogueText: game.dialogDialogueText ?? '',
                  onClose: game.closeDialog,
                ),
          },
          initialActiveOverlays: const ['hud'],
          loadingBuilder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.amber),
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
