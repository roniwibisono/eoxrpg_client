#!/usr/bin/env python3
"""Generates ALL placeholder assets in their FINAL format (ASSET_SPEC.md).

Sprite sheets: <state>.png, frame 64x64, rows = Direction8 enum order
(down, downLeft, left, upLeft, up, upRight, right, downRight), columns =
frames per kAnimSpecs in lib/game/assets/character_sheet_loader.dart.
KEEP THIS FILE IN SYNC WITH kAnimSpecs.

Real art replaces these PNGs 1:1 — same names, same geometry. A 4-direction
art drop (rows: down,left,up,right; height 256) also works (D7 fallback).
"""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
FRAME = 64

# MUST mirror kAnimSpecs (frames per state) and kStateFileNames.
STATES = {
    "idle": 4,
    "walk": 6,
    "run": 6,
    "basic_attack": 6,
    "cast_skill": 6,
    "hit": 3,
    "die": 6,
}
IMPACT_FRAME = {"basic_attack": 3, "cast_skill": 4}

# Direction8 enum order -> facing angle (screen coords, +y down), degrees.
DIRS = [
    ("down", 90), ("downLeft", 135), ("left", 180), ("upLeft", 225),
    ("up", 270), ("upRight", 315), ("right", 0), ("downRight", 45),
]

STATE_COLORS = {
    "idle": (96, 160, 255),
    "walk": (88, 200, 120),
    "run": (40, 220, 90),
    "basic_attack": (240, 110, 80),
    "cast_skill": (180, 110, 240),
    "hit": (250, 210, 70),
    "die": (140, 140, 150),
}


def draw_frame(d, ox, oy, angle_deg, color, frame_i, frames, state, body=(200, 200, 210)):
    cx, cy = ox + FRAME // 2, oy + FRAME // 2
    # body circle, slight bob per frame so motion is visible
    bob = int(2 * math.sin(2 * math.pi * frame_i / max(frames, 1)))
    r = 16
    if state == "die":
        # shrink + flatten over the die animation
        t = frame_i / max(frames - 1, 1)
        r = int(16 * (1 - 0.6 * t))
    d.ellipse([cx - r, cy - r + bob, cx + r, cy + r + bob], fill=body,
              outline=(30, 30, 30), width=2)
    # facing arrow
    a = math.radians(angle_deg)
    ax, ay = cx + 22 * math.cos(a), cy + 22 * math.sin(a)
    d.line([cx, cy + bob, ax, ay + bob], fill=color, width=4)
    d.ellipse([ax - 4, ay - 4 + bob, ax + 4, ay + 4 + bob], fill=color)
    # frame index pips along the bottom
    for i in range(frames):
        px = ox + 6 + i * 8
        py = oy + FRAME - 7
        fill = color if i == frame_i else (70, 70, 70)
        d.ellipse([px, py, px + 5, py + 5], fill=fill)
    # impact frame marker: white ring
    if IMPACT_FRAME.get(state) == frame_i:
        d.ellipse([cx - r - 5, cy - r - 5 + bob, cx + r + 5, cy + r + 5 + bob],
                  outline=(255, 255, 255), width=3)


def gen_sheet_set(base_dir, body_color):
    os.makedirs(base_dir, exist_ok=True)
    for state, frames in STATES.items():
        img = Image.new("RGBA", (frames * FRAME, len(DIRS) * FRAME), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for row, (_, angle) in enumerate(DIRS):
            for col in range(frames):
                draw_frame(d, col * FRAME, row * FRAME, angle,
                           STATE_COLORS[state], col, frames, state, body_color)
        img.save(os.path.join(base_dir, f"{state}.png"))


def gen_tileset(path):
    # 8 tiles, 32px: 0 grass, 1 grass2, 2 dirt, 3 stone, 4 wall, 5 water,
    # 6 canopy (overhead), 7 bush (decor)
    T = 32
    colors = [
        (74, 117, 44), (66, 105, 40), (121, 85, 58), (120, 120, 128),
        (70, 70, 80), (52, 86, 140), (34, 70, 30), (50, 96, 40),
    ]
    img = Image.new("RGBA", (8 * T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, c in enumerate(colors):
        x = i * T
        d.rectangle([x, 0, x + T - 1, T - 1], fill=c)
        # simple texture so tiles are tellable apart
        if i in (0, 1):
            for k in range(5):
                d.point((x + (k * 7 + i * 3) % T, (k * 11) % T), fill=(90, 140, 60))
        if i == 4:  # wall: brick lines
            d.line([x, 10, x + T, 10], fill=(40, 40, 48), width=2)
            d.line([x, 21, x + T, 21], fill=(40, 40, 48), width=2)
        if i == 6:  # canopy: leafy blob with transparent corners
            d.rectangle([x, 0, x + T - 1, T - 1], fill=(0, 0, 0, 0))
            d.ellipse([x + 1, 1, x + T - 2, T - 2], fill=(34, 70, 30))
            d.ellipse([x + 6, 5, x + 16, 14], fill=(48, 92, 40))
        if i == 7:
            d.rectangle([x, 0, x + T - 1, T - 1], fill=(0, 0, 0, 0))
            d.ellipse([x + 4, 8, x + T - 5, T - 2], fill=(50, 96, 40))
        d.rectangle([x, 0, x + T - 1, T - 1], outline=(0, 0, 0, 40))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def gen_map(tiles_dir):
    """dev_arena.tmx — 40x30, layers per GDD §7 in render order."""
    W, H = 40, 30
    G, G2, DIRT, STONE, WALL, WATER, CANOPY, BUSH = range(1, 9)  # gids

    ground = [[G if (x * 7 + y * 13) % 5 else G2 for x in range(W)] for y in range(H)]
    decor = [[0] * W for _ in range(H)]
    overhead = [[0] * W for _ in range(H)]

    # stone plaza near spawn
    for y in range(12, 18):
        for x in range(4, 12):
            ground[y][x] = STONE
    # dirt path
    for x in range(12, 34):
        ground[15][x] = DIRT
        ground[16][x] = DIRT
    # water pool (visual; blocked via Collision rects below)
    water_rect = (26, 4, 34, 9)
    for y in range(water_rect[1], water_rect[3]):
        for x in range(water_rect[0], water_rect[2]):
            ground[y][x] = WATER
    # interior wall segments (visual)
    wall_rects = [(16, 8, 17, 14), (16, 19, 17, 25), (24, 12, 31, 13)]
    for (x0, y0, x1, y1) in wall_rects:
        for y in range(y0, y1):
            for x in range(x0, x1):
                ground[y][x] = WALL
    # bushes
    for (x, y) in [(7, 8), (8, 8), (20, 22), (21, 23), (33, 20)]:
        decor[y][x] = BUSH
    # canopy cluster (overhead) over the path so transparency is testable
    for y in range(13, 18):
        for x in range(19, 24):
            overhead[y][x] = CANOPY

    def csv_layer(data):
        return "\n".join(",".join(str(v) for v in row) + ("," if r < H - 1 else "")
                         for r, row in enumerate(data))

    TS = 32
    def rect_obj(oid, x0, y0, x1, y1, name=""):
        return (f'  <object id="{oid}" name="{name}" x="{x0*TS}" y="{y0*TS}" '
                f'width="{(x1-x0)*TS}" height="{(y1-y0)*TS}"/>')

    objs = []
    oid = 1
    # border walls
    for r in [(0, 0, W, 1), (0, H - 1, W, H), (0, 0, 1, H), (W - 1, 0, W, H)]:
        objs.append(rect_obj(oid, *r)); oid += 1
    for r in wall_rects:
        objs.append(rect_obj(oid, *r)); oid += 1
    objs.append(rect_obj(oid, *water_rect, name="water")); oid += 1

    spawn_objs = [
        f'  <object id="{oid}" name="player_spawn" x="{7*TS}" y="{14*TS}">\n'
        f'   <point/>\n  </object>'
    ]
    oid += 1
    for (x, y) in [(28, 16), (31, 22), (20, 7), (34, 14)]:
        spawn_objs.append(
            f'  <object id="{oid}" name="monster" x="{x*TS}" y="{y*TS}">\n'
            f'   <properties>\n'
            f'    <property name="monsterId" value="slime_test"/>\n'
            f'   </properties>\n   <point/>\n  </object>')
        oid += 1
    # one NPC spawn so the loader's npcId path is exercised (ignored in P0-3)
    spawn_objs.append(
        f'  <object id="{oid}" name="npc" x="{6*TS}" y="{12*TS}">\n'
        f'   <properties>\n    <property name="npcId" value="test_npc"/>\n'
        f'   </properties>\n   <point/>\n  </object>')
    oid += 1

    tsx = f'''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="dev_tileset" tilewidth="32" tileheight="32" tilecount="8" columns="8">
 <image source="dev_tileset.png" width="256" height="32"/>
</tileset>
'''

    def tile_layer(lid, name, data):
        return (f' <layer id="{lid}" name="{name}" width="{W}" height="{H}">\n'
                f'  <data encoding="csv">\n{csv_layer(data)}\n  </data>\n </layer>')

    tmx = f'''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="{W}" height="{H}" tilewidth="32" tileheight="32" infinite="0" nextlayerid="6" nextobjectid="{oid}">
 <tileset firstgid="1" source="dev_tileset.tsx"/>
{tile_layer(1, "Ground", ground)}
{tile_layer(2, "Decor_Back", decor)}
 <objectgroup id="3" name="Collision">
{chr(10).join(objs)}
 </objectgroup>
 <objectgroup id="4" name="Spawns">
{chr(10).join(spawn_objs)}
 </objectgroup>
{tile_layer(5, "Overhead", overhead)}
</map>
'''
    os.makedirs(tiles_dir, exist_ok=True)
    with open(os.path.join(tiles_dir, "dev_arena.tmx"), "w") as f:
        f.write(tmx)
    with open(os.path.join(tiles_dir, "dev_tileset.tsx"), "w") as f:
        f.write(tsx)


if __name__ == "__main__":
    gen_sheet_set(os.path.join(ROOT, "images", "characters", "human"),
                  body_color=(210, 210, 225))
    gen_sheet_set(os.path.join(ROOT, "images", "monsters", "slime_test"),
                  body_color=(120, 200, 110))
    gen_tileset(os.path.join(ROOT, "tiles", "dev_tileset.png"))
    gen_map(os.path.join(ROOT, "tiles"))
    print("assets generated")
