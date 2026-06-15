import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';

import '../../engine/world/aabb.dart';

/// One monster/NPC spawn point from the `Spawns` object layer (GDD §7:
/// custom property monsterId / npcId → spawn dinamis by ID).
class SpawnPoint {
  final String? monsterId;
  final String? npcId;
  final Vector2 position;
  const SpawnPoint({this.monsterId, this.npcId, required this.position});
}

class LoadedMap {
  /// Renders every layer EXCEPT Overhead (priority 0).
  final TiledComponent ground;

  /// Renders ONLY Overhead (added above entities). Same .tmx parsed twice —
  /// deliberate trade-off: flame_tiled builds its renderable-layer list once
  /// at load from layers visible at that moment, so a single component can't
  /// put one layer above dynamically-sorted entities. Cost: dev map parses
  /// in a few ms; revisit if region maps get huge.
  final TiledComponent overhead;

  final List<Aabb> collisions;
  final Vector2 playerSpawn;
  final List<SpawnPoint> spawns;
  final Vector2 sizePx;
  final double tileSize;

  /// Overhead tile presence grid for canopy transparency (GDD §7 layer 5).
  final List<List<bool>> overheadMask;

  const LoadedMap({
    required this.ground,
    required this.overhead,
    required this.collisions,
    required this.playerSpawn,
    required this.spawns,
    required this.sizePx,
    required this.tileSize,
    required this.overheadMask,
  });

  bool hasOverheadAt(double worldX, double worldY) {
    final c = worldX ~/ tileSize;
    final r = worldY ~/ tileSize;
    if (r < 0 || r >= overheadMask.length) return false;
    if (c < 0 || c >= overheadMask[r].length) return false;
    return overheadMask[r][c];
  }
}

class MapLoader {
  static const groundLayers = ['Ground', 'Decor_Back'];
  static const overheadLayer = 'Overhead';
  static const collisionLayer = 'Collision';
  static const spawnsLayer = 'Spawns';

  /// Loads `<assets/tiles/>name.tmx`. Throws StateError with a precise
  /// message when a required layer (GDD §7) is missing — fail loud, not
  /// silently broken.
  static Future<LoadedMap> load(String name, {Images? images}) async {
    // Tileset images live NEXT TO the .tmx/.tsx in assets/tiles/ (single
    // source of truth for both the Tiled editor and flame_tiled). This
    // deviates from GDD §9 (images/tilesets/) deliberately: flame_tiled
    // resolves the tsx <image source> against the Images prefix, and
    // keeping everything in assets/tiles/ avoids '../' keys that the
    // AssetBundle cannot normalise. Proposed GDD §9 errata.
    final tileImages = images ?? Images(prefix: 'assets/tiles/');
    final ground = await TiledComponent.load(
      name,
      Vector2.all(32),
      images: tileImages,
      priority: 0,
    );
    final overhead = await TiledComponent.load(
      name,
      Vector2.all(32),
      images: tileImages,
    );

    final map = ground.tileMap.map;
    final tileSize = map.tileWidth.toDouble();
    final sizePx = Vector2(
      (map.width * map.tileWidth).toDouble(),
      (map.height * map.tileHeight).toDouble(),
    );

    // Required layers — validate before anything else.
    // NOTE: tiled 0.11 layerByName THROWS on a missing layer; use an
    // explicit scan so we control the error message.
    Layer? findLayer(String name) {
      for (final l in map.layers) {
        if (l.name == name) return l;
      }
      return null;
    }

    for (final required in [
      ...groundLayers,
      collisionLayer,
      spawnsLayer,
      overheadLayer,
    ]) {
      if (findLayer(required) == null) {
        throw StateError(
            'Map "$name" is missing required layer "$required" (GDD §7).');
      }
    }

    // Split visibility: ground hides Overhead; overhead hides everything else.
    for (var i = 0; i < map.layers.length; i++) {
      final layerName = map.layers[i].name;
      ground.tileMap
          .setLayerVisibility(i, visible: layerName != overheadLayer);
      overhead.tileMap
          .setLayerVisibility(i, visible: layerName == overheadLayer);
    }

    // Collision: OBJECT layer of rectangles (GDD §7 — not a tile layer).
    final collisions = <Aabb>[];
    final collGroup = findLayer(collisionLayer);
    if (collGroup is ObjectGroup) {
      for (final obj in collGroup.objects) {
        collisions.add(Aabb(obj.x, obj.y, obj.width, obj.height));
      }
    } else {
      throw StateError(
          '"$collisionLayer" must be an OBJECT layer of rectangles (GDD §7), '
          'found ${collGroup.runtimeType}.');
    }

    // Spawns: object layer with custom properties.
    Vector2? playerSpawn;
    final spawns = <SpawnPoint>[];
    final spawnGroup = findLayer(spawnsLayer);
    if (spawnGroup is ObjectGroup) {
      for (final obj in spawnGroup.objects) {
        final monsterId = obj.properties.getValue<String>('monsterId');
        final npcId = obj.properties.getValue<String>('npcId');
        if (obj.name == 'player_spawn') {
          playerSpawn = Vector2(obj.x, obj.y);
        } else if (monsterId != null || npcId != null) {
          spawns.add(SpawnPoint(
            monsterId: monsterId,
            npcId: npcId,
            position: Vector2(obj.x, obj.y),
          ));
        }
      }
    }
    if (playerSpawn == null) {
      throw StateError(
          'Map "$name": no object named "player_spawn" in "$spawnsLayer".');
    }

    // Overhead mask for canopy transparency.
    final ohLayer = findLayer(overheadLayer);
    final mask = List.generate(
        map.height, (_) => List<bool>.filled(map.width, false));
    if (ohLayer is TileLayer && ohLayer.tileData != null) {
      final data = ohLayer.tileData!;
      for (var r = 0; r < data.length && r < map.height; r++) {
        for (var c = 0; c < data[r].length && c < map.width; c++) {
          mask[r][c] = data[r][c].tile != 0;
        }
      }
    }

    return LoadedMap(
      ground: ground,
      overhead: overhead,
      collisions: collisions,
      playerSpawn: playerSpawn,
      spawns: spawns,
      sizePx: sizePx,
      tileSize: tileSize,
      overheadMask: mask,
    );
  }
}
