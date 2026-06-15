# ASSET_SPEC — Kontrak Sprite Sheet & Map

Art asli **menimpa file dummy 1:1** — nama sama, geometri sama, tanpa
sentuh kode. Loader: `lib/game/assets/character_sheet_loader.dart`
(`kAnimSpecs` = satu-satunya sumber kebenaran; `tool/generate_assets.py`
harus disinkronkan jika spec berubah).

## Sprite sheet karakter & monster

Lokasi: `assets/images/characters/<race>/` dan
`assets/images/monsters/<monsterId>/`. Satu PNG per state.

Frame: **64×64 px**. Baris = arah. Kolom = frame animasi.

| File | Frame | Step time | Loop | Frame event |
|---|---|---|---|---|
| `idle.png` | 4 | 0.18s | ya | — |
| `walk.png` | 6 | 0.10s | ya | — |
| `run.png` | 6 | 0.08s | ya | — |
| `basic_attack.png` | 6 | 0.07s | tidak | **impact di frame index 3** |
| `cast_skill.png` | 6 | 0.09s | tidak | **release di frame index 4** |
| `hit.png` | 3 | 0.08s | tidak | — |
| `die.png` | 6 | 0.12s | tidak (berhenti di frame akhir) | — |

Contoh: `walk.png` 8 arah = 6×64 lebar × 8×64 tinggi = **384×512 px**.

### Urutan baris arah (D7)

Sheet 8 arah (tinggi 512): `down, downLeft, left, upLeft, up, upRight,
right, downRight` — persis urutan enum `Direction8`.

Sheet 4 arah (tinggi 256): `down, left, up, right`. Loader mendeteksi dari
tinggi PNG; diagonal otomatis memakai animasi horizontal terdekat
(downLeft/upLeft → left, dst — aturan terdokumentasi di `Direction8.to4`,
bisa dibalik ke prioritas vertikal di satu tempat itu saja).

### State opsional (fallback otomatis)

`run.png` hilang → pakai `walk.png`. `cast_skill.png` hilang → pakai
`basic_attack.png`. State lain wajib ada — loader melempar error dengan
pesan jelas jika tidak (fail-loud, bukan diam-diam rusak).

### Frame impact

Damage melee & release projectile terjadi DI frame yang ditandai di tabel,
bukan saat tombol ditekan (GDD §6.2). Artist: letakkan pose kontak senjata
di frame index 3 (`basic_attack`) dan pose lepas mantra di frame index 4
(`cast_skill`). Jika timing art berbeda, ubah `impactFrame` di `kAnimSpecs`.

## Map (Tiled)

Lokasi: `assets/tiles/`. Lima layer wajib, urutan render (GDD §7):
`Ground` (tile), `Decor_Back` (tile), `Collision` (**object layer berisi
persegi**), `Spawns` (object layer), `Overhead` (tile).

`Spawns`: satu object bernama `player_spawn`; object monster memakai custom
property `monsterId` (string); NPC memakai `npcId` (di-load tapi belum
di-spawn pada Fase 0–3).

**Penting (deviasi sadar dari GDD §9, usulan errata):** PNG tileset
diletakkan **di samping** file `.tsx` di `assets/tiles/`, dengan
`<image source="nama.png">` tanpa path. Alasan: flame_tiled me-resolve
source terhadap prefix `Images`, dan konvensi `images/tilesets/` di GDD §9
menghasilkan key `../images/...` yang tidak bisa dinormalisasi AssetBundle.
MapLoader sudah memakai `Images(prefix: 'assets/tiles/')`. Konsekuensi:
folder `assets/tiles/` harus terdaftar di pubspec (sudah).
