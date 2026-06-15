import 'package:flutter_test/flutter_test.dart';

import 'package:eoxrpg_client/engine/combat/cooldown_and_dedup.dart';
import 'package:eoxrpg_client/engine/combat/models.dart';
import 'package:eoxrpg_client/engine/combat/reference_combat_engine.dart';
import 'package:eoxrpg_client/engine/core/seeded_rng.dart';
import 'package:eoxrpg_client/engine/core/vec2.dart';
import 'package:eoxrpg_client/engine/entity/direction.dart';
import 'package:eoxrpg_client/engine/entity/entity_state.dart';
import 'package:eoxrpg_client/engine/world/aabb.dart';
import 'package:eoxrpg_client/engine/world/nav_grid.dart';

void main() {
  group('Direction8 (D7)', () {
    test('fromVector resolves all 8 sectors (screen coords, +y down)', () {
      expect(Direction8.fromVector(1, 0), Direction8.right);
      expect(Direction8.fromVector(-1, 0), Direction8.left);
      expect(Direction8.fromVector(0, 1), Direction8.down);
      expect(Direction8.fromVector(0, -1), Direction8.up);
      expect(Direction8.fromVector(1, 1), Direction8.downRight);
      expect(Direction8.fromVector(-1, 1), Direction8.downLeft);
      expect(Direction8.fromVector(1, -1), Direction8.upRight);
      expect(Direction8.fromVector(-1, -1), Direction8.upLeft);
    });

    test('zero vector returns fallback', () {
      expect(Direction8.fromVector(0, 0, fallback: Direction8.left),
          Direction8.left);
    });

    test('to4 collapses diagonals to horizontal (documented rule)', () {
      expect(Direction8.downLeft.to4(), Direction8.left);
      expect(Direction8.upLeft.to4(), Direction8.left);
      expect(Direction8.downRight.to4(), Direction8.right);
      expect(Direction8.upRight.to4(), Direction8.right);
      expect(Direction8.down.to4(), Direction8.down);
      expect(Direction8.up.to4(), Direction8.up);
    });
  });

  group('EntityStateMachine (GDD §6.4)', () {
    test('die locks permanently', () {
      final m = EntityStateMachine();
      expect(m.tryTransition(EntityState.die), isTrue);
      expect(m.tryTransition(EntityState.idle), isFalse);
      expect(m.tryTransition(EntityState.hit), isFalse);
      expect(m.tryTransition(EntityState.basicAttack), isFalse);
      expect(m.state, EntityState.die);
    });

    test('movement cannot cancel attack/cast', () {
      final m = EntityStateMachine();
      m.tryTransition(EntityState.basicAttack);
      expect(m.tryTransition(EntityState.walk), isFalse);
      expect(m.tryTransition(EntityState.run), isFalse);
      expect(m.tryTransition(EntityState.idle), isFalse);
      expect(m.state, EntityState.basicAttack);
    });

    test('hit interrupts attack but not die', () {
      final m = EntityStateMachine();
      m.tryTransition(EntityState.castSkill);
      expect(m.tryTransition(EntityState.hit), isTrue);
      expect(m.state, EntityState.hit);
      m.tryTransition(EntityState.die);
      expect(m.tryTransition(EntityState.hit), isFalse);
    });

    test('notifyActionComplete releases the action lock', () {
      final m = EntityStateMachine();
      m.tryTransition(EntityState.basicAttack);
      m.notifyActionComplete();
      expect(m.state, EntityState.idle);
      expect(m.tryTransition(EntityState.walk), isTrue);
    });
  });

  group('AABB resolve (D2: push-out + wall-slide)', () {
    const wall = Aabb(100, 0, 20, 200);

    test('horizontal movement is blocked at the wall face', () {
      const mover = Aabb(50, 50, 20, 20);
      final p = resolveAabbMovement(mover, const Vec2(100, 0), [wall]);
      expect(p.x, 80); // 100 - width 20
      expect(p.y, 50);
    });

    test('wall-slide: blocked X keeps free Y movement', () {
      const mover = Aabb(70, 50, 20, 20);
      final p = resolveAabbMovement(mover, const Vec2(40, 30), [wall]);
      expect(p.x, 80);
      expect(p.y, 80); // Y unaffected
    });

    test('no tunneling through a thin wall at a huge delta', () {
      const mover = Aabb(0, 50, 20, 20);
      final p = resolveAabbMovement(mover, const Vec2(500, 0), [wall]);
      expect(p.x, 80);
    });

    test('free movement is unchanged', () {
      const mover = Aabb(0, 0, 20, 20);
      final p = resolveAabbMovement(mover, const Vec2(30, 40), [wall]);
      expect(p.x, 30);
      expect(p.y, 40);
    });
  });

  group('NavGrid A* (monster-only, GDD §7)', () {
    NavGrid grid() => NavGrid.fromCollision(
          worldWidth: 320,
          worldHeight: 320,
          cellSize: 32,
          // vertical wall x=128..160, y=0..256 leaves a gap at the bottom
          solids: const [Aabb(128, 0, 32, 256)],
        );

    test('path routes around the wall through the gap', () {
      final path = grid().findPath((1, 1), (8, 1));
      expect(path, isNotNull);
      expect(path!.last, (8, 1));
      // must pass below the wall (row >= 8)
      expect(path.any((c) => c.$2 >= 8), isTrue);
    });

    test('fully sealed goal returns null', () {
      final g = NavGrid.fromCollision(
        worldWidth: 320,
        worldHeight: 320,
        cellSize: 32,
        solids: const [Aabb(128, 0, 32, 320)], // full-height wall
      );
      expect(g.findPath((1, 1), (8, 1)), isNull);
    });

    test('no corner cutting through diagonal gaps', () {
      // two blocks meeting at a corner: (1,1) and (2,2) cells blocked
      final g = NavGrid.fromCollision(
        worldWidth: 128,
        worldHeight: 128,
        cellSize: 32,
        solids: const [Aabb(32, 32, 32, 32), Aabb(64, 64, 32, 32)],
      );
      final path = g.findPath((1, 2), (2, 1));
      expect(path, isNotNull);
      // direct diagonal (1,2)->(2,1) would cut between the two blocks;
      // a legal path must take more than one step.
      expect(path!.length, greaterThan(1));
    });
  });

  group('CooldownManager & HitDedup (D8/D9)', () {
    test('cooldown counts down to ready', () {
      final cd = CooldownManager();
      cd.trigger('s1', 2.0);
      expect(cd.isReady('s1'), isFalse);
      cd.tick(1.0);
      expect(cd.remaining('s1'), closeTo(1.0, 1e-9));
      cd.tick(1.01);
      expect(cd.isReady('s1'), isTrue);
    });

    test('one cast = one damage per target; new cast hits again', () {
      final dd = HitDedup();
      expect(dd.register(1, 'mob_a'), isTrue);
      expect(dd.register(1, 'mob_a'), isFalse); // frame-overlap repeat
      expect(dd.register(1, 'mob_b'), isTrue); // same cast, other target
      expect(dd.register(2, 'mob_a'), isTrue); // new cast
      dd.releaseCast(1);
      expect(dd.register(1, 'mob_a'), isTrue); // released, id can recycle
    });
  });

  group('ReferenceCombatEngine (PLACEHOLDER formulas, deterministic)', () {
    const atkStats = CombatantStats(maxHp: 100, maxMp: 50, atk: 20, def: 5);
    const defStats = CombatantStats(
        maxHp: 100, maxMp: 10, atk: 5, def: 4, dodgeChance: 0);
    const skill = SkillDef(
      id: 's',
      name: 's',
      shape: SkillShape.melee,
      powerMultiplier: 1.0,
      mpCost: 5,
      cooldownSeconds: 1,
      range: 40,
    );

    test('same seed → identical resolution sequence (GDD §8.3)', () {
      List<double> run() {
        final e = ReferenceCombatEngine(SeededRng(123));
        final a = CombatantRuntime(id: 'a', stats: atkStats);
        final b = CombatantRuntime(id: 'b', stats: defStats);
        return List.generate(
            10, (_) => e.resolveHit(caster: a, target: b, skill: skill).damage);
      }

      expect(run(), run());
    });

    test('mp cost is paid once per cast via payCastCost', () {
      final e = ReferenceCombatEngine(SeededRng(1));
      final a = CombatantRuntime(id: 'a', stats: atkStats);
      expect(e.canCast(a, skill), isTrue);
      e.payCastCost(a, skill);
      expect(a.mp, atkStats.maxMp - skill.mpCost);
    });

    test('invulnerable target always dodges (i-frames)', () {
      final e = ReferenceCombatEngine(SeededRng(7));
      final a = CombatantRuntime(id: 'a', stats: atkStats);
      final b = CombatantRuntime(id: 'b', stats: defStats)
        ..invulnerable = true;
      for (var i = 0; i < 20; i++) {
        final r = e.resolveHit(caster: a, target: b, skill: skill);
        expect(r.outcome, AttackOutcome.dodge);
        expect(r.damage, 0);
      }
      expect(b.hp, defStats.maxHp);
    });

    test('lethal hit reports killed and clamps hp at 0', () {
      final e = ReferenceCombatEngine(SeededRng(5));
      final a = CombatantRuntime(
          id: 'a',
          stats: const CombatantStats(
              maxHp: 100, maxMp: 50, atk: 10000, def: 0, critChance: 0));
      final b = CombatantRuntime(id: 'b', stats: defStats);
      AttackResult r;
      do {
        r = e.resolveHit(caster: a, target: b, skill: skill);
      } while (r.outcome == AttackOutcome.miss);
      expect(r.killed, isTrue);
      expect(b.hp, 0);
      // hitting a corpse is a no-damage miss
      final r2 = e.resolveHit(caster: a, target: b, skill: skill);
      expect(r2.damage, 0);
    });

    test('DoT ticks at 1s granularity and can kill via tick()', () {
      final e = ReferenceCombatEngine(SeededRng(2));
      final b = CombatantRuntime(
          id: 'b',
          stats: const CombatantStats(
              maxHp: 5, maxMp: 0, atk: 1, def: 0, mpRegenPerSecond: 0));
      b.statuses.add(ActiveStatus(const StatusDef(
          id: 'burn', duration: 10, dotDamagePerSecond: 3)));
      var events = e.tick(0.5, [b]);
      expect(events, isEmpty); // below 1s accumulation
      events = e.tick(0.6, [b]);
      expect(events.whereType<DotDamageEvent>().length, 1);
      expect(b.hp, 2);
      events = e.tick(1.0, [b]);
      final dot = events.whereType<DotDamageEvent>().single;
      expect(dot.killed, isTrue);
      expect(events.whereType<DeathEvent>().length, 1);
      expect(b.dead, isTrue);
    });

    test('status expires and is removed', () {
      final e = ReferenceCombatEngine(SeededRng(3));
      final b = CombatantRuntime(id: 'b', stats: defStats);
      b.statuses.add(ActiveStatus(
          const StatusDef(id: 'slow', duration: 1, moveSpeedMultiplier: 0.5)));
      expect(b.moveSpeedMultiplier, 0.5);
      e.tick(1.1, [b]);
      expect(b.statuses, isEmpty);
      expect(b.moveSpeedMultiplier, 1.0);
    });
  });
}
