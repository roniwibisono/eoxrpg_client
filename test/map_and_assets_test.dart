import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiled/tiled.dart';
import 'package:xml/xml.dart';

/// Validates dev_arena.tmx against the GDD §7 layer contract and the dummy
/// sprite sheets against ASSET_SPEC.md — pure file checks, no Flame.
void main() {
  group('dev_arena.tmx (GDD §7 contract)', () {
    late TiledMap map;

    setUpAll(() {
      final xml = File('assets/tiles/dev_arena.tmx').readAsStringSync();
      map = TileMapParser.parseTmx(xml, tsxList: [_FileTsx('dev_tileset.tsx')]);
    });

    test('the five required layers exist in render order', () {
      final names = map.layers.map((l) => l.name).toList();
      expect(names,
          ['Ground', 'Decor_Back', 'Collision', 'Spawns', 'Overhead']);
    });

    test('Collision is an OBJECT layer with >0 rectangles', () {
      final layer =
          map.layers.firstWhere((l) => l.name == 'Collision') as ObjectGroup;
      expect(layer.objects, isNotEmpty);
      for (final o in layer.objects) {
        expect(o.width, greaterThan(0),
            reason: 'collision object ${o.id} must be a rectangle');
        expect(o.height, greaterThan(0));
      }
    });

    test('Spawns contains player_spawn and monsterId properties', () {
      final layer =
          map.layers.firstWhere((l) => l.name == 'Spawns') as ObjectGroup;
      expect(layer.objects.where((o) => o.name == 'player_spawn').length, 1);
      final monsters = layer.objects
          .where((o) => o.properties.getValue<String>('monsterId') != null)
          .toList();
      expect(monsters.length, 4);
      for (final m in monsters) {
        expect(m.properties.getValue<String>('monsterId'), 'slime_test');
      }
      expect(
          layer.objects
              .where((o) => o.properties.getValue<String>('npcId') != null)
              .length,
          1);
    });

    test('Overhead tile layer has canopy tiles (transparency testable)', () {
      final layer =
          map.layers.firstWhere((l) => l.name == 'Overhead') as TileLayer;
      final count = layer.tileData!
          .expand((row) => row)
          .where((gid) => gid.tile != 0)
          .length;
      expect(count, greaterThan(0));
    });
  });

  group('Sprite sheets follow ASSET_SPEC.md', () {
    const states = {
      'idle': 4,
      'walk': 6,
      'run': 6,
      'basic_attack': 6,
      'cast_skill': 6,
      'hit': 3,
      'die': 6,
    };

    for (final base in [
      'assets/images/characters/human',
      'assets/images/monsters/slime_test',
    ]) {
      test('$base: every state sheet has frames×64 × (8|4)×64 geometry', () {
        for (final e in states.entries) {
          final f = File('$base/${e.key}.png');
          expect(f.existsSync(), isTrue, reason: '${f.path} missing');
          final (w, h) = _pngSize(f);
          expect(w, e.value * 64,
              reason: '${f.path}: width must be frames(${e.value})×64');
          expect(h == 8 * 64 || h == 4 * 64, isTrue,
              reason: '${f.path}: height must be 8 or 4 rows of 64 (D7)');
        }
      });
    }
  });
}

/// Reads PNG IHDR width/height without an image package.
(int, int) _pngSize(File f) {
  final b = f.readAsBytesSync();
  final bd = ByteData.sublistView(Uint8List.fromList(b));
  // PNG signature 8 bytes, IHDR length+type 8 bytes → width @16, height @20.
  return (bd.getUint32(16), bd.getUint32(20));
}

class _FileTsx extends TsxProvider {
  final String name;
  _FileTsx(this.name);

  @override
  String get filename => name;

  @override
  Parser getSource(String fn) {
    final xml = File('assets/tiles/$fn').readAsStringSync();
    return XmlParser(XmlDocument.parse(xml).rootElement);
  }

  @override
  Parser? getCachedSource() => null;
}
