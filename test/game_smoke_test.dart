import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eoxrpg_client/data/reference_skills.dart';
import 'package:eoxrpg_client/game/components/monster_component.dart';
import 'package:eoxrpg_client/game/eox_game.dart';

/// Boots the REAL game (real .tmx, real sheets, real collision setup) inside
/// flutter test. This is the closest to "no runtime error" we can verify
/// without a device: asset paths, Tiled parsing, sheet geometry, component
/// mounting, and the orchestrator pipeline all execute for real.
///
/// IMPORTANT TEST-INFRA NOTE: everything runs inside a SINGLE
/// tester.runAsync per test. Component onLoad loads images via real async
/// futures, which never complete in the fake-async zone; and a second
/// runAsync call in the same test was observed to deadlock.
void main() {
  Future<EoxGame> boot(WidgetTester tester) async {
    final game = EoxGame();
    await tester.pumpWidget(GameWidget(game: game));
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!game.isLoaded && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue, reason: 'game failed to load in time');
    return game;
  }

  Future<void> pumpFrames(WidgetTester tester, int frames) async {
    for (var i = 0; i < frames; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  testWidgets('game boots: map + player + monsters mounted', (tester) async {
    await tester.runAsync(() async {
      final game = await boot(tester);
      await pumpFrames(tester, 10);

      expect(game.player, isNotNull);
      expect(game.player!.isMounted, isTrue);
      expect(game.entityComponents.whereType<MonsterComponent>().length, 4,
          reason: '4 monster spawns in dev_arena.tmx');
      expect(game.map.collisions.length, greaterThanOrEqualTo(8));
      expect(game.map.playerSpawn.x, greaterThan(0));

      // NavGrid produces a usable monster path on the real map.
      final mon = game.entityComponents.whereType<MonsterComponent>().first;
      final path = game.findPathWorld(mon.center, game.player!.center);
      expect(path, isNotEmpty,
          reason: 'monster must be able to path to the player spawn');

      // ── Combat pipeline: orchestrator → engine → stream → cooldown ──
      final results = <String>[];
      final sub = game.orchestrator.attackStream
          .listen((r) => results.add(r.outcome.name));

      final castId =
          game.orchestrator.beginCast('player', ReferenceSkills.basicSlash);
      expect(castId, isNotNull);
      final r = game.orchestrator.onHitboxHit(
        castId: castId!,
        casterId: 'player',
        targetId: mon.entityId,
        skill: ReferenceSkills.basicSlash,
      );
      expect(r, isNotNull);

      // dedup: same cast on the same target must NOT resolve twice (D8)
      final r2 = game.orchestrator.onHitboxHit(
        castId: castId,
        casterId: 'player',
        targetId: mon.entityId,
        skill: ReferenceSkills.basicSlash,
      );
      expect(r2, isNull);

      await pumpFrames(tester, 2);
      expect(results.length, 1);
      await sub.cancel();

      // cooldown is live on the player after the cast
      expect(
        game.orchestrator
            .cooldownsOf('player')
            .isReady(ReferenceSkills.basicSlash.id),
        isFalse,
      );

      // canopy transparency mask matches the generated map (cluster at
      // tiles x 19..23, y 13..17)
      expect(game.map.hasOverheadAt(20 * 32.0, 14 * 32.0), isTrue);
      expect(game.map.hasOverheadAt(2 * 32.0, 2 * 32.0), isFalse);
    });
  });

  testWidgets('lethal sequence kills the monster and registry cleans up',
      (tester) async {
    await tester.runAsync(() async {
      final game = await boot(tester);
      await pumpFrames(tester, 10);

      final mon = game.entityComponents.whereType<MonsterComponent>().first;
      final monId = mon.entityId;

      // hammer with separate casts until dead; advance orchestrator time to
      // clear the cooldown gate between casts.
      var guard = 0;
      while (!(game.orchestrator.entity(monId)?.dead ?? true) && guard < 200) {
        guard++;
        var castId =
            game.orchestrator.beginCast('player', ReferenceSkills.basicSlash);
        if (castId == null) {
          game.orchestrator.tick(1.0);
          castId = game.orchestrator
              .beginCast('player', ReferenceSkills.basicSlash);
        }
        if (castId == null) continue;
        final r = game.orchestrator.onHitboxHit(
          castId: castId,
          casterId: 'player',
          targetId: monId,
          skill: ReferenceSkills.basicSlash,
        );
        if (r != null && r.killed) {
          // in-game the hitbox component does exactly this on contact
          mon.onDamaged(r);
        }
      }
      expect(game.orchestrator.entity(monId)?.dead, isTrue);

      // after the despawn timer the component is gone and unregistered.
      await pumpFrames(tester, 80);
      expect(
        game.entityComponents.any((c) => c.entityId == monId),
        isFalse,
        reason: 'dead monster component must be removed',
      );
      expect(game.orchestrator.entity(monId), isNull,
          reason: 'orchestrator must unregister removed entities');
    });
  });
}
