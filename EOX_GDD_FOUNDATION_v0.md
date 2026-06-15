# EOXRPG — Master GDD / PRD (Volume 0: Foundation)
## Echo of Xylos — Top-Down 2D RPG Client (Flutter + Flame)

> Status dokumen: Foundation / Volume 0. Ini adalah single source of truth yang dirujuk semua volume lain dan semua AI agent. Volume 1–4 (detail penuh) mengekspansi bab-bab di sini, tidak menggantikannya. Kalau ada konflik, dokumen ini menang sampai di-update.
>
> Konvensi confidence: klaim version-sensitive / forward-looking diberi label. Tanpa label = keputusan desain (bukan klaim faktual, jadi "benar/salah" tidak berlaku — hanya konsisten/tidak).

---

## 0. Decision Log (baca ini dulu)

🔴 **OTORITAS COMBAT:** Semua detail combat (model real-time, damage resolution, targeting, cooldown, status effect, monster AI, death) diatur oleh `EOXRPG_GDD_Combat_v2.md`, BUKAN dokumen ini. §6 di sini hanya ringkasan + boundary. Kalau konflik soal combat → v2 menang.

| # | Keputusan | Alasan | Konsekuensi |
|---|---|---|---|
| D1 | Engine: Flutter + Flame (bukan Godot) | CombatEngine, faction, quest, skill (~150 effect types) sudah di Dart. Pindah engine = buang ~53k LOC. | Semua agent prompt pakai Flame API. |
| D2 | Visual: orthogonal top-down. Movement = continuous joystick + AABB per-frame. | GDD Combat v2 §1.1 menargetkan "skill + dodge rhythm"; A* tile-pathfinding bertabrakan dengan iframe-dodge sub-tile. | Player digerakkan joystick, collision di-resolve tiap frame vs layer Collision. A* HANYA untuk chase monster. Tap-to-move = opsi setting, bukan default. |
| D3 | Offline-first, dengan boundary tegas | Validasi gameplay & ekonomi tanpa biaya server. | Lihat §8. Rules engine shareable; authority layer PvP tidak. |
| D4 | PvP real-time = fase jauh, server-authoritative | Client-authoritative PvP = cheat surga. | Jangan janji PvP "tinggal switch". Lihat §6.3 & §8.3. |
| D5 | Map: Tiled (.tmx) + flame_tiled, grid orthogonal | Standar industri Flame; collision AABB & A* monster ringan di grid kotak. | Lihat §7. |
| D6 | Reuse CombatEngine v2 Dart yang sudah ada | DamageResolver/FormulaEvaluator/HitResolver tidak berubah dari v1. | Flame jadi view; engine tetap model. Lihat §6.1 & Combat v2 §14. |
| D7 | Arah: data-driven N-directional, default 8-arah, fallback 4-arah | GDD v2 minta 8-arah; tapi 8-arah ≈ 2× cost art. Decouple kode dari keputusan art. | Sediakan 4 sheet → jalan 4-arah (diagonal→cardinal). Sediakan 8 → jalan 8-arah. Tanpa rewrite kode. |
| D8 | Combat resolution = hitbox/projectile collision (bukan resolve-at-cast) | Real-time action butuh damage saat hitbox menyentuh, bukan saat tombol ditekan. | Flame TIDAK hitung damage; ia trigger GameOrchestrator.resolveHit() saat collision, lalu visualkan. Lihat Combat v2 §5. |
| D9 | Semua angka CD / turn→detik / range-radius = PLACEHOLDER | CDN tidak punya field cooldown/range; di-derive dari mp_cost. Akan terasa salah saat playtest. | Jangan treat final. Override per-skill setelah playtest. Lihat Combat v2 §7 & §13. |

---

## 1. Vision & Pillars

**One-liner.** EOXRPG adalah RPG 2D top-down offline-first di mana pemain menjelajah dunia Xylos yang terbagi faksi-faksi politik, naik level melalui PvE & quest, crafting equipment, dan terlibat dalam politik faksi — dibangun supaya bisa bertransisi ke online secara bertahap.

**Design Pillars (urut prioritas):**

1. **Combat yang terasa "berbobot".** Setiap tebasan, crit, miss, skill punya feedback visual+audio yang sinkron frame-perfect. Ini pilar #1 — kalau combat tidak enak, sisanya tidak penting.
2. **Dunia yang hidup lewat faksi & politik.** Bukan sekadar grinding; pilihan faksi mengubah quest, ekonomi, akses wilayah.
3. **Progression jangka panjang.** Class change, skill tree, crafting, gear chase. Loop yang menahan pemain berminggu-minggu.
4. **Offline yang utuh, online yang opsional.** Game harus lengkap dan menyenangkan 100% offline. Online adalah lapisan tambahan, bukan prasyarat fun.

**Anti-pillars (yang SECARA SADAR tidak kita kejar di v1):**

- Bukan MMORPG seamless-world ribuan pemain. (Lihat §6.3 — kenapa.)
- Bukan real-time PvP di v1.
- Bukan true isometric. (8-directional sprite OK & default per D7, tapi map tetap orthogonal grid.)

⚠️ Weakness yang harus kamu sadari: istilah "MMORPG" di brief awal menciptakan ekspektasi yang tidak realistis untuk tim kecil. Dokumen ini sengaja menurunkan klaim ke "RPG offline dengan jalur upgrade ke online co-op/sosial". Kalau kamu benar mau MMO masif, itu proyek 3–5 tahun + tim + budget server, dan Flame bukan bottleneck-nya — netcode & operasi server yang jadi bottleneck. [confidence: tinggi, prinsip umum dev game online]

---

## 2. Target & Scope

- **Platform v1:** Android + iOS (Flutter native). Web/desktop "best-effort", tidak diprioritaskan.
- **Mode v1:** 100% offline single-player.
- **Audience:** penggemar RPG klasik 2D (RO/Tibia/Pokémon-like), mobile-first, sesi 15–45 menit.
- **Orientasi:** portrait atau landscape? → Keputusan terbuka. Rekomendasi: landscape (kamera lebih luas, HUD ala referensi gambar di bawah). Tandai sebagai **TBD-01**.

---

## 3. Core Gameplay Loop

```
[Spawn di kota faksi]

   → terima Quest (NPC / quest board)

   → keluar ke map (movement tap-to-move / joystick)

   → encounter Monster → COMBAT (auto/skill) → loot + EXP

   → kembali, turn-in quest → reward + reputasi faksi

   → crafting / upgrade gear di kota

   → unlock map/region baru / class change

   → (loop, dengan layer politik faksi memodifikasi reward & akses)
```

- **Session loop (menit-an):** move → fight → loot → repeat.
- **Progression loop (jam-an):** quest chain → level → skill point → gear.
- **Meta loop (hari/minggu):** class change → faction standing → wilayah baru → endgame dungeon/raid (PvE co-op AI offline).

---

## 4. World & Lore (ringkas — diekspansi di Vol.1 Lore Bible)

Dunia Xylos terbagi atas faksi politik yang saling bersaing (mis. Concordium vs OmniCorp — nama dari sistem faksi Echo of Xylos yang sudah ada). Tiap faksi punya: ibu kota, BGM tema sendiri, quest line, kebijakan ekonomi (pajak, exchange rate currency), dan siklus pemilihan pemimpin (election cycle) yang memberi leader powers (pajak, perang, buff, treasury project).

Catatan reuse: sistem faksi, election cycle, leader powers, EconomyService, CurrencyExchange sudah ada di codebase Echo of Xylos. EOXRPG menampilkannya secara spasial (NPC, papan, wilayah), bukan membangun ulang.

Lore Bible (Vol.1) harus mencakup: kosmologi, sejarah konflik faksi, 7 faksi + ideologi, peta region + iklim, bestiary (lore tiap monster), NPC penting. → Placeholder untuk ekspansi.

---

## 5. Races, Classes, Progression

- **Race/Genus:** struktur aset memisahkan per ras (lihat asset pipeline §9). Tiap ras = set sprite sheet sendiri. Daftar ras → TBD, isi di Vol.1.
- **Class system:** base class → class change quest (sistem ini sudah ada di Echo of Xylos: reputation gap, dual-key JSON desc/description & rep/reputation). EOXRPG memvisualkan quest-nya.
- **Progression knobs:** level, EXP curve, skill points, stat allocation, gear tier, faction reputation, class tier.
- **Skill system:** ~150 effect types sudah ada (skill audit Echo of Xylos). Map tiap effect ke animasi CastSkill + SFX (§6.2).

Spesifikasi numerik (EXP curve, stat formula, damage formula) harus ditarik dari GameConfig singleton + CombatEngine yang sudah ada, BUKAN dikarang ulang. Agent yang menulis balance dilarang menebak angka — wajib baca file sumber. (Ini constraint di prompt, §AI Agent Context.)

---

## 6. Combat (PILAR #1 — RINGKASAN; detail di EOXRPG_GDD_Combat_v2.md)

Bagian ini hanya menyimpan boundary arsitektur & PvP. Model real-time, targeting dual-mode, cooldown, status effect, monster AI, death → semua di Combat v2. Jangan duplikat di sini.

### 6.1 Arsitektur: Model–View terpisah (real-time, hitbox-based)

```
┌──────────────────────────────────────────────────────┐
│ PURE DART (existing, reuse — Combat v2 §14)            │
│  CombatEngine.initBattle() → CombatState               │
│  CombatEngine.resolveHit({caster,target,skill,state})  │
│                              → AttackResult            │
│  CombatEngine.tick(dt,state)  (DoT, regen, CD, death)  │
│  DamageResolver/FormulaEvaluator/HitResolver (UNCHANGED)│
│  ── TIDAK tahu apa-apa soal Flame/render ──            │
└───────────────┬────────────────────────────────────────┘
        resolveHit()│        ▲ AttackResult (via Stream)
                ▼   │        │
┌──────────────────────────────────────────────────────┐
│ GameOrchestrator (jembatan Flame ↔ Domain)            │
│  onProjectileHit / onArcHit / onMonsterSkillUse        │
│  → panggil resolveHit() → broadcast ke _combatStream   │
└───────────────┬────────────────────────────────────────┘
                ▼
┌──────────────────────────────────────────────────────┐
│ FLAME (view): ProjectileComponent / ArcHitboxComponent │
│  / AoEExplosionComponent (CollisionCallbacks, DEDUP)   │
│  → onCollision = panggil orchestrator (BUKAN hitung)   │
│  → DamageTextComponent (warna per outcome, v2 §6.3)    │
│ FLUTTER OVERLAY: HP/MP bar, skill bar, dengar stream   │
└──────────────────────────────────────────────────────┘
```

Prinsip non-negotiable: Flame component tidak pernah menghitung damage. Saat hitbox/projectile menyentuh target, ia memanggil GameOrchestrator yang memanggil resolveHit(), lalu memvisualkan AttackResult. Ini yang membuat migrasi online untuk PvE relatif mulus — resolveHit bisa dipanggil server nanti.

### 6.2 Kapan damage terjadi (Combat v2 §5.1)

Bukan saat tombol skill ditekan, tapi saat hitbox menyentuh target: projectile onCollide, AoE hitbox aktif frame 3–5, arc/melee hitbox aktif ~0.15s. Wajib dedup: satu cast = satu damage per target, bukan per-frame overlap. Basic-attack melee tetap pakai frame-trigger (frame impact) via animationTicker.onFrame — detail di P-ANIM/P-COMBAT.

### 6.3 PvE vs PvP — boundary jujur

| Aspek | PvE (offline & online co-op) | PvP real-time (fase jauh) |
|---|---|---|
| Authority | Client OK (offline), server untuk co-op | Wajib server-authoritative |
| Reuse CombatEngine? | Ya, hampir penuh | Engine rules ya, tapi resolution pindah ke server + anti-cheat + lag compensation |
| Effort | Sedang | Sangat besar — proyek tersendiri |

⚠️ Jangan tulis di GDD bahwa "PvP tinggal aktifkan flag". Itu salah. PvP butuh: server authoritative tick, input prediction, reconciliation, anti-cheat. [confidence: tinggi]

### 6.4 State machine combat-entity (shared Player & Monster)

`enum EntityState { idle, walk, run, basicAttack, castSkill, hit, die }` × Direction (8-arah default, 4-arah fallback per D7). Aturan transisi (die mengunci, hit interruptible kecuali saat die, attack/cast tidak dibatalkan oleh movement) + per-frame trigger → prompt P-ANIM.

---

## 7. Map / World Construction (RO/TibiaMe-style, realistis)

Pendekatan (sesuai saran brief, divalidasi):

- **Tool:** Tiled (.tmx), render via flame_tiled. [confidence: tinggi — flame_tiled adalah bridge package resmi Flame]
- **Grid:** orthogonal (kotak lurus). Meski art bisa terlihat 45°, simpan map di grid kotak → collision & A* ringan. Ini saran brief yang BENAR.
- **Camera:** follow PlayerComponent (camera.follow).

**Layer wajib di Tiled (urut render bawah→atas):**

1. **Ground** — lantai dasar (walkable).
2. **Decor_Back** — objek di belakang pemain.
3. **Collision** — object layer kotak transparan = tembok/obstacle. Bukan tile layer untuk collision; pakai object layer rectangle → di-parse jadi hitbox.
4. **Spawns** — object layer berisi titik spawn dengan custom property monsterId / npcId → spawn dinamis by ID.
5. **Overhead** — atap/pohon di atas pemain, dengan opsi transparan saat pemain di bawahnya.

**Collision:** continuous AABB terhadap rectangle di layer Collision. Player digerakkan joystick lalu posisi di-resolve tiap frame (push-out + wall-slide), BUKAN A* untuk player. Jangan pakai Forge2D/Box2D (overkill untuk top-down). [confidence: medium — AABB cukup untuk RO-like]

**Movement (final, per D2):** virtual joystick continuous + AABB. A* dibangun dari grid layer Collision (NavGrid) dan dipakai HANYA untuk chase monster (Combat v2 §10), bukan player. Tap-to-move = opsi setting opsional. Detail di prompt P-MAP.

---

## 8. Technical Architecture & Offline→Online

### 8.1 Service Layer (Repository Pattern)

```dart
abstract class FactionStateRepository { ... }
  ├─ LocalFactionState   (GameDatabase: SharedPreferences/SQLite)  ← sekarang
  └─ CloudFactionState   (Firestore/Neon)                          ← nanti

// Switch satu baris di service_locator.dart:
getIt.registerSingleton<FactionStateRepository>(LocalFactionState());
```

LocalSyncManager = jembatan: semua request ke FirestoreService/SyncService dialihkan ke GameDatabase. Firebase di-mock lokal.

Berlaku untuk: faction state, player save, inventory, quest progress, economy. Migrasi mulus untuk ini. ✅

### 8.2 Local Raid (ganti multiplayer real-time)

RaidBattleService yang dulu real-time → Local Raid: MonsterAIService mengontrol ally (rekan tim) + musuh sepenuhnya di device. Reuse pola host-resolve nanti untuk online co-op.

### 8.3 Yang TIDAK mulus (ulangi, karena penting)

PvP real-time resolution. Lihat §6.3. Boundary ini harus ada di kepala sejak awal supaya CombatEngine ditulis pure & deterministic (tanpa side-effect, tanpa baca random global tak-seeded) → kelak bisa dijalankan server-side identik. **Action item:** pastikan CombatEngine deterministic & RNG-nya seedable. [confidence: tinggi bahwa ini perlu untuk PvP]

### 8.4 Database lokal

`game_database.dart`: SQLite untuk data relasional besar (inventory, quest, monster kills), SharedPreferences untuk settings/flags kecil. (Konsisten dengan pola Echo of Xylos.)

---

## 9. Asset Pipeline & Folder Structure

Struktur `assets/`:

```
assets/
├─ images/
│  ├─ ui/            # tombol, frame, healthbar, minimap
│  ├─ characters/
│  │  ├─ human/      # per ras: idle/walk/run/attack/cast/hit/die × N arah (8 default, 4 fallback)
│  │  └─ <race>/
│  ├─ monsters/
│  │  └─ <monsterId>/
│  ├─ tilesets/      # untuk Tiled
│  └─ fx/            # damage text font, skill vfx
├─ audio/
│  ├─ bgm/           # .ogg/.mp3, per region/faksi (concordium.ogg, omnicorp.ogg)
│  └─ sfx/           # .wav (hit, sword_swing, step, error)
├─ tiles/            # .tmx + .tsx
└─ data/             # JSON master (atau dari CDN jsDelivr)
```

- **Memory / OOM:** preload per region/map aktif saja, bukan semua. Saat ganti region: dispose region lama, load region baru. → prompt P-ASSET.
- **Texture atlas:** pakai flame_fire_atlas (FireAtlas) atau TexturePacker output → kurangi draw calls. [confidence: medium — manfaat nyata untuk ratusan sprite; verifikasi profiling sebelum optimasi prematur]
- **Audio:** BGM .ogg/.mp3 (kompresi bagus, looping, fade in/out). SFX .wav (latency rendah). Preload SFX umum saat loading screen. SFX di-trigger per-frame animasi. Volume master BGM & SFX terpisah → simpan di GameDatabase. → prompt P-AUDIO.

---

## 10. Production Roadmap (fase, bukan tanggal)

| Fase | Deliverable | Definition of Done |
|---|---|---|
| 0. Skeleton | Project Flame jalan, GameWidget, satu map Tiled ter-render, kamera follow kotak. | Bisa gerak di 1 map. |
| 1. Movement & Collision | Joystick continuous + AABB resolve, collision layer, overhead transparency, NavGrid (untuk monster). | Tidak tembus tembok; wall-slide mulus. |
| 2. Animation | SpriteAnimationGroupComponent N-arah (8 default/4 fallback), semua state, per-frame trigger. | Player idle/walk/run/attack/die mulus + impact frame ter-trigger. |
| 3. Combat MVP | GameOrchestrator hubungkan CombatEngine v2 ↔ Flame, hitbox/projectile + dedup, DamageText, monster Hit/Die, dodge iframe. | Bisa bunuh monster real-time, lihat damage/crit/miss/dodge. |
| 4. Loot/Quest/EXP | Loot drop, EXP, level up, satu quest chain. | Loop inti utuh offline. |
| 5. Systems | Crafting, equipment, faction standing, economy. | Reuse system Echo of Xylos via repository. |
| 6. Content | Region kedua, class change, dungeon, local raid AI. | Endgame loop offline. |
| 7. Polish | Audio per region, UI overlay penuh, save/load robust. | Releasable offline build. |
| 8. (Stretch) Online | Co-op AI→co-op online, cloud save. PvP = fase tersendiri. | Diputuskan setelah v1 sukses. |

⚠️ Tradeoff yang kamu lewatkan: roadmap ini menunda semua online. Itu disengaja. Membangun online dan offline paralel dengan tim kecil = dua-duanya setengah jadi. [confidence: medium, opini berbasis pengalaman umum dev]

---

## 11. Open Questions (TBD register)

| ID | Pertanyaan | Status / Default |
|---|---|---|
| TBD-01 | Orientasi layar | Landscape (default) |
| TBD-02 | Movement default | ✅ RESOLVED: joystick continuous + AABB (D2). Tap-to-move = opsi. |
| TBD-03 | Jumlah ras playable | Isi di Vol.1 |
| TBD-04 | 4 vs 8 arah | ✅ RESOLVED: kode N-dir, default 8, fallback 4 (D7). Keputusan art (4 vs 8) terpisah. |
| TBD-05 | Forge2D pernah diperlukan? | Tidak (AABB cukup) |
| TBD-06 | Cooldown final per skill | OPEN: v2 derive dari mp_cost = placeholder. Wajib override 85 skill setelah playtest (D9). |
| TBD-07 | secondsPerTurn=2.0 untuk CC | OPEN: stun 2s mungkin terlalu lama di action. Tune saat playtest (D9). |
| TBD-08 | Death penalty severity | OPEN: v2 lunak (-5% EXP). Konfirmasi apakah mau lebih keras (feel Tibia/RO). |
| TBD-09 | Skill loadout >6 (Race_Genus) | OPEN: expand 8 slot vs slot-locking (v2 §12.3 belum putuskan). |

---

## 12. Catatan Verifikasi (jujur)

- Versi Flame 1.37.0 & Flutter 3.41 akurat per 31 Mei 2026 [confidence: tinggi, sumber pub.dev/Wikipedia], tapi cepat basi — agent wajib cek `flutter pub outdated` di awal.
- Klaim "flame_tiled / flame_audio / flame_fire_atlas adalah bridge package resmi" [confidence: tinggi, dari GitHub flame-engine].
- Semua angka balance/EXP/damage di game ini tidak ada di dokumen ini — sumber kebenaran adalah codebase Echo of Xylos. This needs verification dari file sumber, bukan dari dokumen ini.
- Klaim soal kesulitan PvP/netcode = prinsip umum, bukan benchmark spesifik. [confidence: tinggi prinsipnya, low untuk angka effort spesifik]

---

**Volume berikutnya yang disarankan, berurutan:** Vol.1 Core Design (Lore + Class + Combat numbers, tarik dari CombatEngine) → Vol.3 Technical (schema + JSON spec) → Vol.2 Systems → Vol.4 Production. Alasan urutan: combat & teknis memvalidasi kelayakan; lore bisa nyusul.
