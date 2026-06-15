import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../engine/entity/direction.dart';
import '../../engine/entity/entity_state.dart';

/// Animation spec per state — single source of truth shared by the asset
/// generator (tool/generate_assets.py mirrors this) and the loader.
/// See ASSET_SPEC.md. Frame size is fixed 64×64.
class AnimSpec {
  final int frames;
  final double stepTime;
  final bool loop;

  /// Frame index where the gameplay event fires (melee hitbox spawn /
  /// projectile release), via animationTicker.onFrame (GDD §6.2).
  final int? impactFrame;

  const AnimSpec(this.frames, this.stepTime,
      {this.loop = true, this.impactFrame});
}

const kFrameSize = 64.0;

const Map<EntityState, AnimSpec> kAnimSpecs = {
  EntityState.idle: AnimSpec(4, 0.18),
  EntityState.walk: AnimSpec(6, 0.10),
  EntityState.run: AnimSpec(6, 0.08),
  EntityState.basicAttack: AnimSpec(6, 0.07, loop: false, impactFrame: 3),
  EntityState.castSkill: AnimSpec(6, 0.09, loop: false, impactFrame: 4),
  EntityState.hit: AnimSpec(3, 0.08, loop: false),
  EntityState.die: AnimSpec(6, 0.12, loop: false),
};

const Map<EntityState, String> kStateFileNames = {
  EntityState.idle: 'idle.png',
  EntityState.walk: 'walk.png',
  EntityState.run: 'run.png',
  EntityState.basicAttack: 'basic_attack.png',
  EntityState.castSkill: 'cast_skill.png',
  EntityState.hit: 'hit.png',
  EntityState.die: 'die.png',
};

/// Optional states fall back when a sheet is missing (e.g. a monster that
/// ships no run/cast art).
const Map<EntityState, EntityState> kStateFallbacks = {
  EntityState.run: EntityState.walk,
  EntityState.castSkill: EntityState.basicAttack,
};

typedef AnimKey = (EntityState, Direction8);

/// Loads a character/monster sheet set from `<basePath>/<state>.png`.
///
/// D7 auto-detection: sheet height 8×64 → 8-direction art; height 4×64 →
/// 4-direction art, and the four diagonal [Direction8] keys are mapped onto
/// the cardinal animations via [Direction8.to4]. Code never changes.
class CharacterSheetLoader {
  final Images images;
  CharacterSheetLoader(this.images);

  Future<Map<AnimKey, SpriteAnimation>> load(String basePath) async {
    final result = <AnimKey, SpriteAnimation>{};
    final loadedStates = <EntityState, Map<Direction8, SpriteAnimation>>{};

    for (final state in EntityState.values) {
      final file = '$basePath/${kStateFileNames[state]!}';
      final spec = kAnimSpecs[state]!;
      try {
        final image = await images.load(file);
        final dirCount = (image.height / kFrameSize).round();
        if (dirCount != 8 && dirCount != 4) {
          throw StateError(
              '$file: height ${image.height} is neither 4 nor 8 rows of '
              '$kFrameSize px (ASSET_SPEC.md violation)');
        }
        final sheet = SpriteSheet(
          image: image,
          srcSize: Vector2.all(kFrameSize),
        );
        final perDir = <Direction8, SpriteAnimation>{};
        if (dirCount == 8) {
          for (final dir in Direction8.values) {
            perDir[dir] = sheet.createAnimation(
              row: dir.index,
              stepTime: spec.stepTime,
              loop: spec.loop,
              to: spec.frames,
            );
          }
        } else {
          // 4-direction art: rows are down,left,up,right (ASSET_SPEC.md).
          final cardinal = <Direction8, SpriteAnimation>{};
          for (var row = 0; row < 4; row++) {
            cardinal[Direction8.cardinalRowOrder[row]] = sheet.createAnimation(
              row: row,
              stepTime: spec.stepTime,
              loop: spec.loop,
              to: spec.frames,
            );
          }
          for (final dir in Direction8.values) {
            perDir[dir] = cardinal[dir.to4()]!;
          }
        }
        loadedStates[state] = perDir;
      } catch (_) {
        // sheet missing — resolved via fallback pass below
      }
    }

    for (final state in EntityState.values) {
      var source = loadedStates[state];
      source ??= loadedStates[kStateFallbacks[state]];
      if (source == null) {
        throw StateError(
            'Sheet set "$basePath" is missing required state "$state" and '
            'no fallback is available (ASSET_SPEC.md)');
      }
      for (final dir in Direction8.values) {
        result[(state, dir)] = source[dir]!;
      }
    }
    return result;
  }
}
