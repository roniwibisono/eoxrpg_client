# eoxrpg_client — Fase 0–3 (Foundation Build)

Klien Flutter + Flame untuk **Echo of Xylos RPG** sesuai GDD Volume 0.
Scope build ini: **Fase 0 (skeleton), Fase 1 (map), Fase 2 (movement +
animasi), Fase 3 (combat MVP)**. Bukan vertical slice penuh — belum ada
inventory, loot, NPC, dungeon, network.

## Status verifikasi

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | 0 issue |
| `flutter test` (30 test) | semua lolos |
| Toolchain | Flutter 3.44.1 stable · flame 1.37.0 · flame_tiled 3.1.1 |
| Verifikasi di device fisik | **BELUM** — lihat checklist di bawah |

Smoke test mem-boot game sungguhan di `flutter test` (parse TMX asli, load
sprite sheet asli, mounting komponen, pipeline combat end-to-end). Yang
TIDAK bisa diverifikasi tanpa device: rendering visual aktual, rasa
joystick, performa frame, input multi-touch.

## Menjalankan

```bash
flutter pub get
flutter run          # device/emulator Android atau iOS, landscape
flutter test         # 30 unit/struktur/smoke test
python3 tool/generate_assets.py   # regenerasi aset dummy (butuh Pillow)
```

Kontrol: joystick kiri (dorong penuh = lari), tombol kanan: ATK (arc melee),
FIRE (projectile + burn DoT), NOVA (AoE), DODGE (dash + i-frames).

## Arsitektur (GDD §6.1)

```
lib/engine/   PURE DART — nol import Flutter/Flame (siap server-side §8.3)
  core/       Vec2, SeededRng (deterministik)
  entity/     Direction8 (D7), EntityStateMachine (§6.4)
  combat/     models, CombatEngineApi, ReferenceCombatEngine*, cooldown+dedup
  world/      AABB resolve (push-out + wall-slide), NavGrid A* (monster-only)
lib/game/     Layer Flame (view) — TIDAK PERNAH menghitung damage (D8)
  game_orchestrator.dart   satu-satunya jembatan Flame ↔ domain
  map/        MapLoader: 5 layer wajib §7, validasi fail-loud
  components/ player, monster, hitbox (arc/projectile/aoe), damage text,
              overhead opacity wrapper
  hud/        joystick + tombol skill (cooldown sweep baca CooldownManager)
lib/ui/       Overlay Flutter: HP/MP bar (dengar stream), death overlay
assets/       Sprite sheet dummy FORMAT FINAL (lihat ASSET_SPEC.md),
              dev_arena.tmx + tileset
```

## ⚠️ Yang PLACEHOLDER (jangan dikira final)

1. **Formula damage** — `ReferenceCombatEngine` ada hanya supaya build bisa
   jalan end-to-end. Sumber kebenaran tetap CombatEngine v2 + GameConfig
   milik project (GDD §5/D6). Cara mengganti: `INTEGRATION.md`.
2. **Semua angka** cooldown/range/stat/aggro adalah tebakan kasar bertanda
   `PLACEHOLDER` di kode — D9: angka final dari playtest, bukan dari sini.
3. **Aset** — sheet dummy bergambar panah arah + pip frame. Format file
   sudah final; art asli tinggal menimpa PNG (ASSET_SPEC.md).
4. **Keputusan kecil yang kuambil dan bisa kamu balikkan**: diagonal→
   horizontal pada fallback 4 arah (Direction8.to4), dodge 0.25s/i-frames,
   respawn monster 8 detik, death penalty = tidak ada (TBD-08 masih open).

## Checklist verifikasi manual di device (wajib sebelum lanjut Fase 4)

1. Map render: 2 layer ground, bushes, kanopi di atas player.
2. Jalan ke bawah kanopi (cluster tile sekitar tengah map) → kanopi memudar
   ke ~45% lalu balik saat keluar.
3. Tabrak dinding diagonal → wall-slide mulus, tidak nyangkut/menembus.
4. Dorong joystick penuh → animasi lari; setengah → jalan.
5. ATK dekat slime → damage muncul DI frame impact (ring putih di sheet
   dummy), bukan saat tombol ditekan.
6. FIRE dari jauh → projectile berhenti di dinding; kena slime → angka
   ungu DoT tick tiap detik.
7. NOVA → ring biru mengembang, semua slime dalam radius kena SEKALI.
8. DODGE menembus serangan slime → teks "DODGE" cyan, tanpa damage.
9. Mati (biarkan slime memukul) → overlay YOU DIED → Respawn balik ke
   spawn dengan HP/MP penuh.
10. Slime mati → bangkai hilang ±1.6s → respawn ±8s di titik asal.
11. Profil performa di device low-end (target GDD: 60fps; build ini belum
    dioptimasi — y-sort per frame & saveLayer kanopi adalah kandidat biaya).

## Blocker eksternal yang TIDAK diselesaikan build ini

Dari audit CDN sebelumnya dan GDD §5: `item_master.json` belum ada,
2 monster ID hilang dari `monster_master.json`, baru 1/5 dungeon. Itu
blocker Fase 4+ (loot/inventory), bukan Fase 0–3, tapi tetap menghambat
kelanjutan — perlu diselesaikan di sisi data CDN.
