# ECHO OF XYLOS — GDD EDISI PRODUKSI v1.1

> Sky Alley Studio · `id.skyalley.eoxrpg` · Android/iOS · Flutter + Flame (client), Kotlin/Ktor (backend), Neon PostgreSQL (data), jsDelivr CDN (master data statis)
>
> Dokumen ini MELENGKAPI GDD v1.0 (desain) dengan spesifikasi teknis produksi: arsitektur, skema data, kontrak API, dan daftar keputusan terbuka. Jika ada konflik angka/desain, v1.1 menandainya — tidak menimpanya diam-diam.

---

## 0. STATUS DOKUMEN & KEPUTUSAN TERBUKA (BACA DULU)

Tidak ada gunanya GDD yang berpura-pura semua sudah diputuskan. Berikut keputusan yang BELUM final dan memblokir pekerjaan di bawahnya:

| ID | Keputusan terbuka | Opsi | Rekomendasi | Memblokir |
|---|---|---|---|---|
| D-01 | **Model combat** — GDD v1.0 §5 = turn-based party; build Fase 0–3 yang sudah ada = real-time hitbox | (a) turn-based murni, buang combat real-time; (b) hybrid: eksplorasi real-time + battle turn-based; (c) real-time murni, revisi GDD §5 | **(b) Hybrid.** Menyelamatkan ±90% build eksplorasi yang sudah lolos test (map Tiled, movement AABB, NPC tap), dan §5 v1.0 tetap dihormati untuk battle. Pola JRPG-MMO teruji di mobile. | EPIC-C (combat), EPIC-W (world) |
| D-02 | Backend auth — belum disebut di v1.0 | Firebase Auth / custom Ktor JWT / hybrid | Firebase Auth (sudah dipakai project SAKTI; tim familiar) + JWT exchange ke Ktor | EPIC-S (server) |
| D-03 | Realtime transport untuk war map & siege | Polling 30s (v1.0 §12.5) / WebSocket / SSE | Mulai polling 30s sesuai v1.0, desain endpoint agar bisa naik ke WebSocket tanpa ubah skema | EPIC-F (faction war) |
| D-04 | Penyimpanan progress player | Server-authoritative penuh / offline-first + sync | Server-authoritative untuk ekonomi & war; offline-first HANYA cache read (quest list, master data) | EPIC-S, EPIC-E |
| D-05 | Engine versi | Flutter 3.44+ / Flame 1.37+ (terverifikasi build Fase 0–3) | Kunci minor version di pubspec, upgrade per milestone, bukan per sprint | semua client |
| D-06 | Gacha pity & odds | Belum ada di v1.0 | WAJIB ada sebelum rilis: disclosure odds adalah syarat kebijakan Apple/Google | EPIC-G |
| D-07 | Region data dunia (selain Nexus City) | Belum ada daftar region/zone/node kanonik | Buat `world_map.json` kanonik sebelum EPIC-F dimulai | EPIC-F, EPIC-W |

**Konvensi angka:** SEMUA angka di GDD v1.0 (formula damage, bobot ERE, cap AI 40%/25%, durasi siege, dst.) berstatus `BASELINE` — dipakai untuk implementasi pertama, WAJIB lewat simulasi ekonomi + playtest sebelum dianggap final. Jangan pernah hardcode; semua dari config/CDN.

---

## 1. RINGKASAN DESAIN (delta dari v1.0)

Seluruh isi v1.0 §1–§11 dan §13 berlaku. Bagian di bawah hanya menambah presisi teknis.

### 1.1 Pilar teknis turunan dari pilar desain

| Pilar v1.0 | Konsekuensi teknis |
|---|---|
| Living World | Backend wajib hidup 24/7: AI Filler = cron/worker Ktor, bukan logika client |
| Fair Economy | SEMUA mutasi currency server-side; client tidak pernah menghitung rate/reward |
| Transparent AI | Field `virtual:true` & label AI = kontrak API, diuji otomatis, bukan goodwill UI |
| Meaningful Choice | Pilihan faction permanen per karakter → perlu desain slot karakter (lihat 3.2) |

---

## 2. ARSITEKTUR SISTEM

### 2.1 Diagram tingkat tinggi

```
┌─────────────── CLIENT (Flutter + Flame) ───────────────┐
│ UI Flutter (overlay, menu, HUD, chart fl_chart)        │
│ Flame: world eksplorasi real-time (map Tiled, NPC,     │
│        node war-map view) + battle scene turn-based    │
│ State: BLoC per fitur · GetIt service locator          │
│ Data: Dio (API) · sqflite (cache) · rootBundle/CDN     │
└──────────────┬──────────────────────────┬──────────────┘
               │ HTTPS/JSON (JWT)         │ HTTPS (read-only)
┌──────────────▼─────────────┐  ┌─────────▼─────────────┐
│ BACKEND Kotlin/Ktor        │  │ CDN jsDelivr (GitHub)  │
│ - AuthService (D-02)       │  │ master data statis:    │
│ - QuestService             │  │ items, skills, classes,│
│ - EconomyService + ERE     │  │ npc, quests, world_map │
│ - FactionWarService        │  │ (versi via tag rilis)  │
│ - AI Filler workers        │  └────────────────────────┘
│ - TelemetryService         │
└──────────────┬─────────────┘
        ┌──────▼──────┐
        │ Neon        │  ledger currency, war state, rate
        │ PostgreSQL  │  history 30 hari, ai_telemetry,
        └─────────────┘  player progress, gacha pity
```

### 2.2 Pembagian otoritas (ANTI-CHEAT BY DESIGN)

| Domain | Otoritas | Alasan |
|---|---|---|
| Damage battle PvE solo | Client hitung, server VALIDASI sampling | UX responsif; validasi mencegah injeksi reward |
| Reward quest/dungeon/siege | Server only | Ekonomi = integritas game |
| Exchange rate (ERE) | Server only, tick 6 jam | v1.0 §7 |
| Mutasi currency apa pun | Server only, lewat ledger append-only | Audit & rollback |
| Posisi player di world | Client (PvE) | Tidak ada PvP open-world di v1.0 |
| Siege resolution | Server only | v1.0 §4.2 |
| Gacha roll | Server only + pity di DB | Disclosure odds & fairness |

### 2.3 Struktur repo client (kanonik)

```
lib/
  core/            config, env, error, logger, router
  engine/          PURE DART (nol Flutter/Flame) — battle turn-based,
                   formula, status, initiative; bisa jalan server-side
  data/            repository, DTO, sqflite cache, CDN loader, Dio client
  features/
    auth/  party/  combat/ (BLoC + battle scene Flame)
    world/ (eksplorasi real-time — reuse build Fase 0–3)
    factionwar/  economy/  quest/  nexus/  gacha/  shop/  settings/
  game/            komponen Flame share: map loader, npc component,
                   node component, kamera, HUD in-world
assets/data/       fallback offline master data (subset CDN)
assets/images|tiles/  sesuai ASSET_SPEC build Fase 0–3
```

### 2.4 Struktur backend (kanonik)

```
src/main/kotlin/id/skyalley/eox/
  Application.kt  plugins/ (auth, serialization, statuspages, callid)
  routes/   auth, quest, economy, factionwar, gacha, telemetry
  services/ EconomyService, ExchangeRateEngine, QuestService,
            SiegeService, GachaService, SanctionService
  ai/       FactionStrategicAI.kt, ZoneTacticalAI.kt,
            BattleResolverAI.kt, AITelemetryLogger.kt, VirtualPlayerSlot.kt
  db/       tables (Exposed/SQLDelight), migrations (Flyway)
  workers/  EreTick6h, AiFillerTick5m, SiegeScheduler, DailyReset
```

---

## 3. SPESIFIKASI SISTEM (presisi produksi)

### 3.1 Combat turn-based (mengikat v1.0 §5 + agent §12.1)

- Party: player + 3 ally. Musuh 1–5 unit. Encounter dipicu dari world (kontak monster di map real-time → transisi battle scene) — keputusan D-01(b).
- Initiative: `spd + d10` per unit per ronde; re-roll tiap ronde (BASELINE; alternatif roll sekali per battle — uji rasa di playtest).
- Aksi: attack / skill / item / defend (DEF +50% sampai giliran berikut — BASELINE) / flee (chance = `clamp(0.4 + (avgSpdParty - avgSpdEnemy)*0.02, 0.1, 0.9)` — BASELINE; flee dilarang di boss & siege).
- Damage: `max(1, (ATK*mult - DEF*0.4) * (1+critBonus) * elementMod)` — element table: BELUM ADA di v1.0 → buat `element_table.json` (D-07 lampiran); sebelum ada, `elementMod = 1.0`.
- Status (v1.0 §5.4) diimplementasi data-driven: `status_effects.json` dengan field `{id, statMods:{}, dotPerTurn, blocksSkills, absorb, durationTurns, scope}` — JANGAN hardcode lima status itu; akan bertambah.
- Ally behavior profile: aggressive/balanced/defensive/healer → pohon keputusan sederhana berbasis skor target (HP terendah, threat, heal threshold 45% — BASELINE).
- Battle event = `Stream<BattleEvent>` dari engine pure-Dart → BLoC → scene Flame menganimasikan. Engine TIDAK tahu Flame (kontrak sama dengan build Fase 0–3, terbukti enak dites).

### 3.2 Karakter & faction lock

- 1 akun = maks 3 slot karakter; faction dipilih per karakter dan PERMANEN (pindah faction = fitur pasca-rilis, butuh desain penalti ekonomi).
- Class promotion lv30/lv60 (v1.0 §5.5) — data di `class_tree.json`, validasi server saat klaim (level + lokasi trainer + belum promote).

### 3.3 Ekonomi & ledger

Tabel inti (Neon):

```sql
currency_ledger(id, player_id, currency_code, delta, balance_after,
  reason_code, ref_id, created_at)            -- append-only, no UPDATE
exchange_rate(faction_code, rate, score_breakdown_json, computed_at)
exchange_rate_history(... retensi 30 hari, job purge harian)
sanction(faction_code, active, reason, started_at, ends_at)
gacha_pity(player_id, banner_id, counter_since_top, updated_at)
```

Aturan keras (dari v1.0 §6, ditegakkan di service + test):
1. Beli di capital → potong faction currency SENDIRI; beli di Nexus → CRD; jual di mana pun → terima faction currency sendiri.
2. Cross-faction trade lock: endpoint transaksi NPC memvalidasi `npc.region.faction ∈ {player.faction, neutral}`.
3. Ruby tidak pernah keluar dari quest/NPC; satu-satunya sumber: IAP + event grant bertanda audit.
4. ERE formula v1.0 §7.3 dihitung worker tiap 6 jam; `clamp(0.25, 4.0)`; sanction → floor 0.25 override; SEMUA bobot dari tabel config, bukan konstanta Kotlin.

### 3.4 Faction war & siege

- `world_map.json` kanonik (D-07): `regions[] → zones[] → nodes[]`, tiap node `{id, tier: outer|tactical|core|capital, position, income, adjacency[]}` — adjacency penting: siege hanya boleh dideklarasikan ke node yang berbatasan dengan wilayah faction (BASELINE rule, cegah teleport-war).
- Siege state machine (server): `declared → mobilizing → resolving(waves) → resolved → cooldown(2h)`. Tiap wave: formula v1.0 §5.3 siege. Hasil + casualties + perubahan treasury ditulis transaksional.
- Influence tick per node per jam (BASELINE: outer 1, tactical 3, core 8) → masuk skor ERE.

### 3.5 AI Faction Filler

Implementasi mengikat §8 + §12.5 v1.0. Tambahan presisi:
- Worker tick 5 menit; SEMUA hard rules §8.4 = assertion di kode + unit test + alert telemetry saat mendekati cap (win rate 35% = warning).
- "Yield saat player masuk" = endpoint `enter-node` mengeset `aiControlled=false` ATOMIK; race dengan battle AI yang sedang resolve → battle dibatalkan, node netral sementara 60 detik (BASELINE).
- Telemetry wajib: `ai_telemetry(event, node_id, faction, ai_power_used, ts)` + dashboard query harian win-rate AI per faction.

### 3.6 Quest

Mengikat v1.0 §10 + §12.3. Kunci JSON objectives PERSIS: `description, reputation, reward_currency, reward_amount, faction_id` — tanpa alias (sudah jadi sumber bug di iterasi lama; tulis test schema-lock).
Daily reset 00:00 UTC server-side; client hanya menampilkan countdown.

### 3.7 Gacha & ally (melengkapi v1.0 yang belum merinci)

- Banner standar (CRD) & premium (Ruby). Odds WAJIB dipublikasikan in-game (kepatuhan store). BASELINE: SSR 1.5%, SR 12%, R 86.5%, pity SSR di 80 pull, simpan pity server-side.
- Ally: stats dari `ally_master.json`; training pakai faction currency; promotion pakai CRD (BASELINE — uji di simulasi ekonomi).

### 3.8 Nexus City

Mengikat v1.0 §9 + §12.4. 10 NPC katalog = konten minimum rilis. PvP flag `false` di data DAN di kode (dua-duanya dites). Banker UI: rate sekarang, sparkline 7 hari (`fl_chart`), arrow tren, badge sanction.

---

## 4. KONTRAK API (ringkas, untuk detail per-endpoint lihat TODO EPIC-S)

```
POST /api/auth/exchange          Firebase idToken → JWT EOX
GET  /api/player/me              profil, balances, faction
GET  /api/factionwar/state       nodes + aiControlled + influence (poll 30s)
POST /api/factionwar/enter-node  yield AI, daftar partisipasi
POST /api/factionwar/declare-siege
GET  /api/economy/rates          rate semua faction + sparkline 7d
POST /api/economy/exchange       faction ↔ CRD (server hitung, ledger)
POST /api/npc/transaction        buy/sell — validasi region & currency rules
POST /api/quest/complete         validasi + reward routing (§12.3)
POST /api/gacha/pull             roll server-side, pity
POST /api/battle/report          hasil battle PvE + seed → validasi sampling
GET  /api/config                 semua angka BASELINE/tunable + versi master data
```

Semua response `{ok, data, error{code,message}, serverTime}`. Idempotency key untuk semua POST yang memutasi currency.

---

## 5. NON-FUNGSIONAL & KEPATUHAN

| Area | Target rilis |
|---|---|
| Performa client | 60fps device menengah, 30fps floor low-end; battle scene < 300MB RAM |
| Cold start | < 4s sampai main menu (tanpa download patch) |
| Server | p95 API < 300ms; ERE tick < 30s; uptime 99.5% |
| Kualitas | crash-free sessions ≥ 99.5% (Crashlytics); `flutter analyze` 0; coverage engine ≥ 85%, services backend ≥ 80% |
| Keamanan | JWT exp 1h + refresh; rate-limit per endpoint; ledger append-only; tidak ada secret di client |
| Kepatuhan store | Disclosure odds gacha; usia rating; kebijakan loot box regional (cek per negara target); privacy policy + data deletion |
| Lokalisasi | ID + EN saat rilis (arsitektur i18n sejak awal — `intl`, key-based) |

> Catatan jujur: "tanpa bug" bukan target yang bisa diverifikasi. Target yang bisa diverifikasi adalah gate di atas + zero known P0/P1 saat submit store. Itu yang dipakai di TODO.

---

## 6. RENCANA RILIS (gambaran; detail di AGENT_TODO.md)

```
M0 Fondasi → M1 Combat+World vertical slice → M2 Ekonomi+Quest →
M3 Faction War+AI Filler → M4 Nexus+Gacha+Monetisasi →
M5 Hardening+Beta tertutup → M6 Beta terbuka+Live-ops → RILIS
```

Tiap milestone punya exit gate terukur — milestone tidak boleh ditutup dengan gate merah. Definisi lengkap di `AGENT_TODO.md`.
