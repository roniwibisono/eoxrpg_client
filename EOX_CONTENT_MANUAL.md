# ECHO OF XYLOS — MANUAL KONTEN (Cara Menambah Komponen & Aset)

> Untuk siapa: content designer / artist / agent AI yang menambah konten TANPA menyentuh logika game. Prinsip: **konten = data (JSON + PNG + TMX), bukan kode**. Kalau menambah konten memaksa edit Dart/Kotlin, itu bug arsitektur — laporkan, jangan diakali.
>
> Tiga repo yang relevan:
> `eox-master-data` (JSON definisi, dirilis via git tag → jsDelivr) · `eox-client/assets` (PNG, TMX/TSX, audio) · backend tidak pernah disentuh untuk konten.
>
> Alur rilis konten (BERLAKU UNTUK SEMUA JENIS): edit data → `npm run validate` (schema + referential check) hijau → PR → merge → git tag versi → naikkan versi master data di `/api/config` staging → uji in-game staging → promosi ke prod.

---

## 1. MENAMBAH NPC

**Kapan dipakai:** pedagang baru, quest giver baru, NPC lore di region mana pun.

Langkah:
1. **Definisi** — tambah entri di `regions/<region_id>/npcs.json` (untuk Nexus: `nexus_city.json` array `npcs`):
```json
{
  "npc_id": "npc_nexus_starcartographer",
  "name": "Cartographer Yune",
  "type": "lore_keeper",
  "dialogue_key": "dlg.nexus.yune",
  "inventory_ref": null,
  "quest_ids": ["q_nexus_starmap_01"],
  "position": { "x": 1376, "y": 904 },
  "lore_tags": ["remnants", "starmaps"],
  "sprite_ref": "npcs/yune"
}
```
   `type` harus salah satu dari 10 tipe resmi (merchant, blacksmith, innkeeper, ama_banker, quest_giver, lore_keeper, custodian_envoy, black_market, faction_relations, medic) — tipe menentukan UI yang terbuka saat di-tap. Tipe baru = perubahan kode, ajukan dulu.
2. **Posisi** — `position` dalam pixel world map region tsb. Cara mendapat koordinat yang benar: buka TMX region di editor Tiled, taruh kursor di titik yang diinginkan, baca koordinat (status bar kiri-bawah, satuan px). JANGAN menebak.
3. **Sprite** — buat folder `assets/images/npcs/yune/` berisi minimal `idle.png` mengikuti ASSET_SPEC (64×64/frame; NPC boleh 1 arah = 1 baris; loader fallback otomatis). Daftarkan folder di `pubspec.yaml` bila folder baru.
4. **Dialog** — tambah key di `i18n/id.json` dan `i18n/en.json`:
```json
"dlg.nexus.yune.greet": "Bintang tidak berbohong, pelancong...",
"dlg.nexus.yune.menu":  "Mau lihat peta bintang tua?"
```
   Dua bahasa WAJIB; CI merah jika salah satu kosong.
5. **Jika merchant/black_market** — buat `inventories/<inventory_ref>.json`: daftar `{item_id, price, currency}`. Validator menolak `currency:"RUBY"` pada NPC (aturan keras GDD §6.2).
6. **Jika quest giver** — pastikan semua `quest_ids` ada (lihat §5 manual ini); validator memeriksa dua arah.
7. **Validasi & uji** — `npm run validate`; lalu di staging: tap NPC → dialog terbuka → fungsi tipe berjalan (shop/quest/inn). Checklist: nama tampil benar di kedua bahasa, sprite tidak ketimpa objek, posisi tidak di dalam collision.

---

## 2. MENAMBAH REGION / BIOME BARU

**Kapan dipakai:** zona baru milik faction, biome baru (gurun kristal, hutan void, dsb).

Langkah:
1. **Daftarkan di `world_map.json`** (kanonik — D-07):
```json
{
  "region_id": "region_vermil_wastes",
  "name_key": "region.vermil_wastes",
  "faction_owner": "iron_covenant",
  "biome": "crystal_desert",
  "tmx": "vermil_wastes.tmx",
  "zones": [
    { "zone_id": "z_vw_outer_1",
      "nodes": [
        { "id": "n_vw_o1", "tier": "outer", "position": {"x": 12, "y": 30},
          "income": 1, "adjacency": ["n_vw_o2", "n_ridge_t1"] }
      ] }
  ]
}
```
   Aturan node: `tier` ∈ outer/tactical/core/capital; `adjacency` harus dua arah (validator menegakkan); Core node per region maksimal 1 (BASELINE).
2. **Tileset biome** — buat `assets/tiles/<biome>_tileset.png` (tile 32×32, grid horizontal) + `<biome>_tileset.tsx` dengan `<image source="nama.png">` TANPA path — PNG harus di samping tsx (aturan flame_tiled, lihat ASSET_SPEC bagian map; ini sudah jadi sumber crash sekali, jangan diulang).
3. **TMX** — buat `assets/tiles/vermil_wastes.tmx` di Tiled. **Lima layer wajib, nama persis, urutan persis**: `Ground` (tile), `Decor_Back` (tile), `Collision` (object layer, HANYA persegi), `Spawns` (object layer), `Overhead` (tile). MapLoader menolak map yang melanggar dengan pesan eksplisit — itu disengaja.
4. **Spawns** — wajib 1 object bernama `player_spawn` (point). Monster: object dengan custom property `monsterId` (string, harus ada di `monster_master.json`). NPC: property `npcId`.
5. **Musik/ambience (opsional)** — `assets/audio/bgm/<biome>.ogg`, daftarkan di `regions/.../meta.json` field `bgm_ref`.
6. **Uji** — staging: masuk region → cek border collision keliling (jalan menyusuri seluruh tepi), kanopi/Overhead transparan saat di bawahnya, semua spawn hidup, A* monster tidak macet di dekorasi (kejar-kejaran 2 menit). Profil FPS di device menengah — biome dengan banyak Overhead/saveLayer adalah biaya render terbesar yang kita tahu.

---

## 3. MENAMBAH BUILDING (gedung di dalam region)

Building = kombinasi visual (tile/objek TMX) + collision + opsional pintu interaksi.

1. **Visual** — gambar building di layer `Ground`/`Decor_Back` (bagian bawah, di belakang player) dan bagian atap di `Overhead` (di depan player + transparan otomatis saat player di belakangnya).
2. **Collision** — tambah persegi di layer `Collision` menutupi footprint dinding (bukan atap). Sisakan celah pintu selebar ≥ 1.5 tile supaya pathfinding monster & gerak player nyaman.
3. **Pintu / interior (opsional)** — object di layer `Spawns` dengan property `portalTo: "<region_id>:<spawn_name>"`; interior = TMX terpisah (perlakukan seperti region mini, 5 layer tetap wajib). Spawn tujuan harus ada — validator memeriksa.
4. **Building fungsional** (inn, forge, bank cabang) — fungsi datang dari NPC di dalamnya (lihat §1), bukan dari building. Building tanpa NPC = dekorasi.
5. **Uji** — keliling building menempel dinding (wall-slide mulus, tidak nyangkut sudut), atap memudar benar, masuk-keluar pintu 10× tanpa stuck.

---

## 4. MENAMBAH MONSTER

1. `monster_master.json`:
```json
{ "monster_id": "void_stalker", "name_key": "mon.void_stalker",
  "level": 18, "stats": { "hp": 420, "atk": 36, "def": 14, "spd": 22 },
  "skills": ["skl_void_claw", "skl_phase_shift"],
  "element": "void", "behavior": "aggressive",
  "encounter": { "party_min": 1, "party_max": 3 },
  "loot_table": [ { "item_id": "it_void_shard", "chance": 0.18, "qty": [1,2] } ],
  "exp": 95, "currency_reward": { "code": "FACTION_LOCAL", "amount": 12 } }
```
   `FACTION_LOCAL` = currency faction pemilik region tempat ia dibunuh (server yang me-resolve). Semua `skills`, `item_id`, `element` harus terdaftar — validator menolak referensi dangling.
2. **Sprite** — `assets/images/monsters/void_stalker/` mengikuti ASSET_SPEC penuh (idle/walk/basic_attack/hit/die wajib; run & cast opsional → fallback otomatis).
3. **Penempatan** — tambah object spawn ber-`monsterId` di TMX region (lihat §2 langkah 4).
4. **Balance check** — jalankan `tool/economy_sim` mode monster: `dart run tool/economy_sim --monster void_stalker` → laporan TTK vs party selevel & nilai loot/jam. TTK di luar 2–6 giliran atau loot/jam >120% rata-rata tier = revisi sebelum merge (gate CI data).

---

## 5. MENAMBAH QUEST

1. `quests/<region|nexus>/q_xxx.json` — kunci objectives PERSIS (tanpa alias, schema menegakkan):
```json
{ "id": "q_nexus_starmap_01", "type": "crossFaction",
  "title_key": "q.starmap01.title", "description": "q.starmap01.desc",
  "giver_npc": "npc_nexus_starcartographer",
  "objectives": [
    { "description": "q.starmap01.obj1", "kind": "kill",
      "target": "void_stalker", "count": 5,
      "reputation": 10, "reward_currency": "CRD",
      "reward_amount": 40, "faction_id": null } ],
  "prerequisites": [], "repeatable": false }
```
2. **Routing reward mengikuti tipe** (GDD §10.2): faction→faction currency; dungeon/crossFaction/special→CRD; TIDAK ADA quest ber-reward Ruby — validator menolak.
3. Hubungkan dua arah: `giver_npc` punya `quest_ids` berisi id ini.
4. i18n dua bahasa untuk semua key.
5. **Uji staging**: ambil → progres ter-track → selesai → reward masuk ledger dengan reason `quest:q_...` (cek di admin panel) → daily reset benar bila repeatable.

---

## 6. MENAMBAH SKILL / STATUS EFFECT

1. Skill → `skills.json`: `{ id, name_key, class_ids[]|monster, mult, mp_cost, target: single|aoe|party, element, status_on_hit, cooldown_turns }`. Status → `status_effects.json` (statMods/dot/blocksSkills/absorb/duration/scope).
2. Tidak perlu kode untuk kombinasi field yang sudah didukung engine; mekanik BARU (mis. "serap MP") = task engine, ajukan ke backlog, jangan dipaksakan lewat data.
3. Uji: `dart test test/engine` (engine memuat data live) + 1 battle staging memakai skill tsb; cek log battle menampilkan status & durasi benar.

---

## 7. MENAMBAH ALLY (unit gacha)

1. `ally_master.json`: stats, rarity (R/SR/SSR), skills, faction_affinity, sprite_ref.
2. Sprite battle mengikuti ASSET_SPEC; potret gacha `assets/images/allies/portraits/<id>.png` 512×640.
3. Masukkan ke banner: `banners.json` `{ banner_id, pool:[{ally_id, weight}], start, end }` — total weight per rarity harus konsisten dengan odds yang dipublikasikan; validator menghitung ulang dan menolak selisih.
4. Uji: pull di staging (akun debug), unit muncul di roster, dipakai battle, profil AI jalan.

---

## 8. MENAMBAH ITEM

`items.json`: `{ id, name_key, type: consumable|material|equip|cosmetic, statMods, price_base, sell_value, tier }`. Aturan keras: `type:cosmetic` TIDAK BOLEH punya statMods ≠ 0 (anti pay-to-win, dites CI). Equip baru dengan slot baru = perubahan kode, ajukan dulu. Icon `assets/images/items/<id>.png` 96×96.

---

## 9. MENAMBAH MATA UANG / IKON HUD (jarang — hanya jika desain berubah)

Currency baru = keputusan desain besar (sentuh ledger, ERE, UI) — BUKAN konten. Yang boleh lewat data: ikon & warna di `factions.json` (`currency: { code, name_key, color_hex, icon_ref }`). Ikon `assets/images/currency/<code>.png` 64×64, siluet jelas di ukuran 20px.

---

## 10. CHECKLIST UMUM SEBELUM MERGE KONTEN APA PUN

1. `npm run validate` hijau (schema + referensi dua arah + aturan keras ekonomi).
2. i18n ID+EN lengkap untuk semua key baru.
3. Aset mengikuti ASSET_SPEC (geometri diuji otomatis oleh test sheet-spec).
4. Uji in-game di staging dengan checklist bagian terkait di atas — screenshot dilampirkan di PR.
5. Tidak ada perubahan file Dart/Kotlin di PR konten. Kalau ada, berhenti dan tanya.
6. Tag versi data + catat di CHANGELOG-data (apa, kenapa, dampak balance bila ada).
