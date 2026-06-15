# INTEGRATION — Mengganti Engine Referensi & Memasang Map Asli

## 1. Drop-in CombatEngine v2 (WAJIB sebelum balance apa pun)

Seluruh `lib/game/` hanya bicara ke interface
`lib/engine/combat/combat_engine_api.dart`. `ReferenceCombatEngine` adalah
stand-in berformula PLACEHOLDER — **jangan dituning, ganti**.

Langkah:

1. Salin modul CombatEngine v2 yang sudah ada (DamageResolver,
   FormulaEvaluator, HitResolver, dst) ke project ini TANPA diubah
   (prinsip D6 / Combat v2 §14).
2. Tulis adapter:

```dart
class XylosCombatEngineAdapter implements CombatEngineApi {
  final XylosCombatEngine inner; // engine asli
  XylosCombatEngineAdapter(this.inner);

  @override
  AttackResult resolveHit({required caster, required target, required skill}) {
    // map CombatantRuntime/SkillDef ↔ model engine asli di sini.
    // Dipanggil saat KONTAK HITBOX (D8), sudah ter-dedup per (cast, target).
  }

  @override
  bool canCast(caster, skill) => /* cek MP/resource engine asli */;

  @override
  void payCastCost(caster, skill) { /* sekali per cast, saat cast mulai */ }

  @override
  List<CombatEvent> tick(double dt, Iterable<CombatantRuntime> entities) {
    // DoT / regen / expiry engine asli → terjemahkan ke DotDamageEvent /
    // DeathEvent supaya damage text & die animation tetap jalan.
  }
}
```

3. Ganti SATU baris di konstruktor `EoxGame` (`lib/game/eox_game.dart`):
   `engine ?? ReferenceCombatEngine(SeededRng(42))` →
   `engine ?? XylosCombatEngineAdapter(...)`. Atau inject dari `main.dart`:
   `EoxGame(engine: XylosCombatEngineAdapter(...))`.

Kontrak yang harus dijaga adapter (GDD §8.3): deterministik, RNG seedable,
tanpa import Flutter/Flame di jalur resolve — supaya resolve bisa pindah ke
server saat PvE-online.

Skill asli: ganti `lib/data/reference_skills.dart` dengan loader
`skill_list.json` dari CDN; `SkillDef` di sini hanya butuh field bentuk
hitbox (shape/range/projectileSpeed/aoeRadius) + cost/cooldown — field
efek kompleks tetap urusan engine asli lewat adapter.

## 2. Memasang nexus_core_v2.tmx (atau map region lain)

1. Salin `.tmx` + semua `.tsx` + PNG tileset ke `assets/tiles/` — PNG harus
   di samping tsx dengan `source` tanpa path (lihat ASSET_SPEC.md bagian
   map; ini usulan errata GDD §9).
2. Pastikan 5 layer wajib ada dengan nama persis: `Ground`, `Decor_Back`,
   `Collision` (object rects), `Spawns` (dengan `player_spawn` +
   `monsterId`), `Overhead`. MapLoader menolak map yang kurang layer dengan
   pesan eksplisit.
3. Ganti nama map: `EoxGame(mapName: 'nexus_core_v2.tmx')` di `main.dart`.
4. Catatan biaya: MapLoader mem-parse tmx DUA KALI (ground + overhead)
   karena flame_tiled membangun daftar renderable layer sekali saat load.
   Untuk dev_arena ini ~ms; untuk map besar ukur dulu — jika berat,
   alternatifnya memecah Overhead ke tmx terpisah.

## 3. Monster baru

Tambah folder `assets/images/monsters/<monsterId>/` sesuai ASSET_SPEC,
daftarkan folder di `pubspec.yaml`, lalu pakai `monsterId` itu di property
spawn map. Stats per-monster saat ini PLACEHOLDER konstan di
`MonsterComponent` — saat integrasi data asli, ganti dengan lookup
`monster_master.json` (blocker: 2 monster ID masih hilang di CDN).

## 4. Catatan test infra (penting untuk smoke test berikutnya)

Di `flutter test`, semua pump frame HARUS di dalam SATU `tester.runAsync`
per test: onLoad komponen me-load image lewat future real-async yang tidak
pernah selesai di fake-async zone, dan pemanggilan `runAsync` kedua dalam
test yang sama teramati deadlock. Pola yang benar ada di
`test/game_smoke_test.dart`.
