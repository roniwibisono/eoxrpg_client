# ECHO OF XYLOS — AGENT TODO MASTER (sampai Full Release)

> Cara pakai: setiap task punya ID, role agent, file target, langkah, **Acceptance Criteria (AC)** yang bisa diverifikasi, dan dependensi. Satu task = satu sesi agent ideal. Jangan kerjakan task yang dependensinya belum hijau.
>
> **Tentang "stabil tanpa bug":** tidak ada proses yang bisa MENJAMIN nol bug — yang ada adalah gate kualitas terukur di tiap milestone (analyze 0 issue, test hijau, coverage minimum, crash-free ≥99.5%, zero known P0/P1 saat submit). Semua gate tertulis eksplisit di sini. Klaim selesai tanpa bukti gate = task belum selesai.

## 0. KONVENSI WAJIB SEMUA AGENT

1. **Baca dulu**: `EOX_GDD_PRODUKSI_v1.1.md` + bagian GDD v1.0 yang relevan dengan task.
2. **Angka** = ambil dari config/CDN, JANGAN hardcode. Semua angka berlabel BASELINE boleh dipakai tapi wajib lewat jalur config.
3. **Engine pure-Dart** (`lib/engine/`) dilarang import Flutter/Flame — diuji dengan test import-guard (T-QA-02).
4. **Currency** hanya berubah lewat ledger server. Client yang menulis balance lokal = bug arsitektur, tolak.
5. Setiap task selesai = `flutter analyze` 0 issue (client) / `./gradlew detekt test` hijau (backend) + test baru untuk perilaku baru.
6. Setiap PR/commit menyebut Task ID.
7. Definisi prioritas bug: P0 = crash/korupsi data/exploit ekonomi; P1 = fitur inti tak berfungsi; P2 = fungsional minor; P3 = kosmetik.

## GATE MILESTONE (exit criteria — milestone tutup hanya jika SEMUA hijau)

| Gate | M0 | M1 | M2 | M3 | M4 | M5 | M6/Rilis |
|---|---|---|---|---|---|---|---|
| analyze/detekt 0 issue | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Semua test hijau di CI | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Coverage engine ≥85% / services ≥80% | — | engine | +economy | +war/AI | +gacha | ✔ | ✔ |
| Vertical slice main di device fisik | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Simulasi ekonomi lulus (T-E-09) | — | — | ✔ | ✔ | ✔ | ✔ | ✔ |
| Load test backend lulus | — | — | — | siege | full | ✔ | ✔ |
| Crash-free ≥99.5% (data beta) | — | — | — | — | — | tertutup | terbuka |
| Zero known P0/P1 | — | — | — | — | — | ✔ | ✔ |
| Kepatuhan store (odds, privacy, rating) | — | — | — | — | draft | ✔ | ✔ |

---

# MILESTONE M0 — FONDASI (EPIC-S0, EPIC-D0)

### T-S0-01 · Monorepo & CI/CD · [DevOps Agent]
File: `.github/workflows/{client.yml,backend.yml}`, `melos.yaml`/struktur repo.
Langkah: repo `eox-client` (Flutter) + `eox-backend` (Ktor) + `eox-master-data` (JSON→CDN via tag rilis). CI client: analyze, test, build apk debug. CI backend: detekt, test, build jar, migrasi dry-run. Artefak build per commit.
AC: push ke branch → pipeline hijau end-to-end; badge status di README; build gagal memblokir merge.

### T-S0-02 · Skeleton backend Ktor + Neon · [Backend Agent]
File: `Application.kt`, `plugins/*`, `db/migrations/V1__init.sql` (Flyway).
Langkah: Ktor 3.x, kotlinx-serialization, Exposed; koneksi Neon via env; tabel: players, characters, currency_ledger, exchange_rate(+history), nodes_state, sanction, gacha_pity, ai_telemetry. Endpoint `GET /health`, `GET /api/config`.
AC: `./gradlew run` lokal + deploy staging; Flyway migrate bersih dari nol; /health 200; /api/config mengembalikan semua angka BASELINE dari tabel config.
Dependensi: T-S0-01.

### T-S0-03 · Auth (D-02) · [Backend Agent]
File: `routes/AuthRoutes.kt`, `services/AuthService.kt`.
Langkah: terima Firebase idToken → verifikasi → terbitkan JWT EOX (exp 1h) + refresh token; middleware auth untuk semua route /api kecuali health/config.
AC: token valid → 200; expired/salah → 401 dengan error code konsisten; unit test 4 kasus; rate-limit login 10/menit/IP.

### T-S0-04 · Skeleton client + router + env · [Flutter Agent]
File: `lib/core/*`, `lib/main.dart`, flavor dev/staging/prod.
Langkah: GetIt, go_router, Dio interceptor (JWT + refresh + retry idempotent), logger, error boundary, screen: splash → login → home placeholder.
AC: `flutter analyze` 0; login Firebase → exchange JWT → home menampilkan `GET /api/player/me`; ganti flavor mengganti base URL tanpa edit kode.

### T-D0-01 · Master data v1 + schema lock · [Data Agent]
File (repo eox-master-data): `factions.json, status_effects.json, class_tree.json, skills.json, items.json, ally_master.json, world_map.json (D-07), element_table.json, nexus_city.json, quests/*.json, config_baseline.json` + `schemas/*.schema.json`.
Langkah: tulis JSON Schema tiap file; CI repo data memvalidasi semua file vs schema + referential check (skill→class ada, npc→quest ada, node adjacency dua arah).
AC: CI merah jika satu referensi dangling; kunci objectives quest PERSIS `description, reputation, reward_currency, reward_amount, faction_id` ditegakkan schema; rilis data = git tag → URL jsDelivr berversi.
Catatan: konten boleh placeholder seperlunya, STRUKTUR harus final.

### T-D0-02 · Loader master data client · [Flutter Agent]
File: `lib/data/master/{cdn_loader.dart, master_repository.dart}`.
Langkah: fetch by version dari /api/config → CDN URL; cache sqflite; fallback assets/data; checksum.
AC: mode pesawat setelah sekali load → app tetap boot dari cache; versi baru di config → re-fetch; test unit cache hit/miss/corrupt.

---

# MILESTONE M1 — COMBAT + WORLD VERTICAL SLICE

> Keputusan D-01(b) hybrid: world eksplorasi real-time me-reuse build Fase 0–3; combat = scene turn-based baru.

## EPIC-C — Combat Engine Turn-Based

### T-C-01 · Engine inti pure-Dart · [Engine Agent — gunakan template GDD §12.1]
File: `lib/engine/combat/{battle_state.dart, battle_unit.dart, turn_queue.dart, combat_engine.dart, battle_event.dart}`.
Langkah: initiative `spd + d10` (SeededRng injektabel), aksi attack/skill/item/defend/flee, damage formula §5.3 dengan elementMod dari element_table, clamp min 1.
AC: deterministik dengan seed sama; test: sort initiative, clamp 1, defend +50%, flee formula & larangan flee boss; NOL import Flutter/Flame.

### T-C-02 · Status effects data-driven · [Engine Agent]
File: `lib/engine/combat/status_system.dart`.
Langkah: muat `status_effects.json`; dukung statMods, dotPerTurn, blocksSkills, absorb (Shielded), partyWide (Synchronized), Sanctioned (blok special, durasi dungeon).
AC: lima status v1.0 §5.4 lolos test perilaku + durasi decrement + stack rule (refresh, bukan stack — BASELINE); tambah status baru = edit JSON tanpa edit Dart (dibuktikan test memuat status fiktif).

### T-C-03 · Ally AI behavior profile · [Engine Agent]
File: `lib/engine/combat/ally_ai.dart`.
AC: 4 profil menghasilkan aksi berbeda pada state uji yang sama; healer memprioritaskan HP<45%; test deterministik per profil.

### T-C-04 · CombatBloc + Battle Scene Flame · [Flutter Agent]
File: `lib/features/combat/{bloc/*, view/battle_scene.dart, view/battle_overlay.dart}`.
Langkah: konsumsi `Stream<BattleEvent>`; scene Flame: posisi 4v5, anim sprite (sheet spec ASSET_SPEC), damage text, turn banner; overlay Flutter: command menu, HP/MP party, target picker.
AC: battle penuh main di device dari encounter → menang/kalah → hasil; tidak ada logika damage di scene (audit import); golden test layout command menu.

### T-C-05 · Encounter bridge world→battle · [Flutter Agent]
File: `lib/features/world/encounter_trigger.dart`.
Langkah: kontak monster di world real-time (reuse komponen Fase 0–3) → push battle route dengan formasi musuh dari `monster_master`; menang → kembali ke world, monster despawn + respawn timer; kalah → respawn protokol.
AC: transisi bolak-balik 20× tanpa leak (cek DevTools memory); state world (posisi, HP world) konsisten.

### T-C-06 · Battle report ke server · [Backend+Flutter Agent]
File: `routes/BattleRoutes.kt`, `services/BattleValidationService.kt`, client `battle_report_repository.dart`.
Langkah: client kirim seed + log aksi + hasil; server re-run engine (port formula ke Kotlin ATAU jalankan validasi statistik) pada sampling 10% + semua battle bernilai reward tinggi.
AC: laporan dimanipulasi (damage mustahil) → ditolak + flag akun; test 5 kasus manipulasi.

## EPIC-W — World Eksplorasi (reuse Fase 0–3)

### T-W-01 · Port build Fase 0–3 ke struktur fitur · [Flutter Agent]
Langkah: pindahkan map loader/movement/NPC-tap ke `lib/features/world/` + `lib/game/`; matikan combat real-time lama (hitbox arc/projectile) di belakang flag `legacyRealtimeCombat=false` — JANGAN dihapus sampai D-01 final ditandatangani.
AC: world jalan dengan joystick, kamera, kanopi, collision seperti build lama; 30 test lama tetap hijau atau diadaptasi sadar (tulis alasan tiap test yang diubah).

### T-W-02 · NPC interaksi & dialog · [Flutter Agent]
File: `lib/game/npc_component.dart`, `lib/features/world/dialog_overlay.dart`.
Langkah: NPC dari `nexus_city.json`/region data; tap → DialogOverlay (dialogue_key → teks i18n); hook ke quest/shop/banker sesuai `type`.
AC: 10 tipe NPC v1.0 §9.2 punya jalur interaksi (boleh placeholder UI untuk fitur yang epic-nya belum jalan, tapi routing harus benar); test: tap NPC merchant membuka shop, banker membuka exchange.

### T-W-03 · World map / war map view · [Flutter Agent]
File: `lib/features/factionwar/view/war_map_screen.dart`, `node_component.dart`.
Langkah: render regions→zones→nodes dari `world_map.json`; warna owner; badge AI (§13.2): glow biru strokeWidth 3 + label "Low Activity Support".
AC: polling 30s memperbarui owner tanpa rebuild penuh; golden test badge AI; tap node → panel detail (tier, owner, influence, AI flag).

**GATE M1**: vertical slice di device — login → world → ketemu monster → battle turn-based → menang dapat (placeholder) reward → kembali ke world. Engine coverage ≥85%.

---

# MILESTONE M2 — EKONOMI + QUEST

## EPIC-E — Ekonomi & ERE

### T-E-01 · Ledger service · [Backend Agent]
File: `services/EconomyService.kt`.
Langkah: semua mutasi via `appendLedger(playerId, currency, delta, reason, refId, idempotencyKey)`; saldo = materialized balance + cek konsistensi job harian.
AC: idempotency: request ganda → satu entry; transaksi konkuren 100 paralel → saldo akurat (test race); tidak ada UPDATE pada ledger (lint SQL).

### T-E-02 · Exchange Rate Engine worker · [Backend Agent — template §12.x]
File: `workers/EreTick6h.kt`, `services/ExchangeRateEngine.kt`.
Langkah: formula v1.0 §7.3, bobot dari config; tulis rate + breakdown JSON + history; purge >30 hari.
AC: unit test tiap variabel menggeser rate sesuai bobot; sanction → 0.25 override; clamp 0.25–4.0; tick idempoten (jalan 2× = 1 baris).

### T-E-03 · Endpoint exchange + Banker · [Backend+Flutter]
AC: tukar CM↔CRD pakai rate live server; fee BASELINE 1% (config); UI banker: rate, sparkline 7d fl_chart, arrow tren, badge sanction; ledger 2 entry berpasangan (debit/kredit) dengan ref sama.

### T-E-04 · NPC transaction rules · [Backend Agent]
File: `routes/NpcRoutes.kt`, `services/NpcTransactionService.kt`.
AC: matriks v1.0 §6.2 lulus SEMUA selnya sebagai test parametrik (beli capital sendiri ✔, beli capital rival ✘403, beli Nexus pakai CRD ✔, jual di Nexus terima faction currency ✔, Ruby di NPC ✘); pesan error punya kode unik.

### T-E-05 · HUD currency (v1.0 §13.1) · [Flutter Agent]
AC: 3 slot warna/posisi sesuai spec; update via stream balance; format angka besar (1.2M); badge sanction merah saat flag aktif.

### T-E-09 · SIMULASI EKONOMI (gate M2) · [Data/Engine Agent]
File: `tool/economy_sim/` (Dart CLI).
Langkah: simulasikan 30 hari × 1000 player bot (earn quest, spend NPC, exchange) + 7 faction dengan profil menang/kalah berbeda → output: inflasi per currency, rate trajectory, sumber/sink imbalance.
AC: laporan md otomatis; merah jika currency apa pun inflasi >15%/30 hari atau rate stuck di clamp >50% waktu — angka BASELINE direvisi sampai hijau, revisi dicatat di config + changelog.

## EPIC-Q — Quest

### T-Q-01 · QuestService backend (template §12.3) · [Backend]
AC: reward routing per tipe (faction→faction currency; dungeon/custodian/cross→CRD) lulus test parametrik; complete idempoten; validasi objectives server-side; daily reset 00:00 UTC.

### T-Q-02 · Quest client: repo + BLoC + UI · [Flutter]
AC: offline-first list (cache sqflite); accept/track/complete; jurnal quest dengan filter tipe; test reward routing client menampilkan currency benar.

### T-Q-03 · Konten quest rilis v1 · [Content Agent]
AC: per faction: 1 chain intro (5 quest) + 5 side; Nexus: 5 cross-faction + 3 custodian + 2 lore; dungeon: 3 daily — semua valid schema, terhubung NPC nyata, teruji auto (referential CI) + manual play.

**GATE M2**: loop ekonomi nyata di staging — quest → reward → belanja → exchange; simulasi T-E-09 hijau.

---

# MILESTONE M3 — FACTION WAR + AI FILLER

## EPIC-F — Faction War

### T-F-01 · Node & influence state server · [Backend]
AC: tick influence per jam per tier; GET state p95 <150ms dengan 500 node; history influence harian per faction.

### T-F-02 · Siege state machine · [Backend]
Langkah: declared→mobilizing→resolving→resolved→cooldown 2h; wave resolve formula §5.3; treasury damage loser; adjacency rule.
AC: test transisi ilegal ditolak; durasi per tier (15/30/60m) dari config; dua siege node sama bersamaan → kedua ditolak dengan lock; cooldown ditegakkan.

### T-F-03 · Partisipasi player dalam siege · [Backend+Flutter]
Langkah: player join siege → kontribusi power (dari party power + hasil battle dukungan); UI: timeline wave, kontributor top, hasil.
AC: kontribusi tercatat & memengaruhi hasil sesuai bobot config; reward siege via ledger; AFK join tanpa aksi = kontribusi 0.

### T-F-04 · Custodian Sanction system · [Backend]
AC: ambang war-crime (config) → sanction otomatis + manual override admin; efek: CRD freeze (transaksi CRD faction ditolak dengan kode error spesifik) + rate floor; UI badge; expiry job.

## EPIC-A — AI Faction Filler (template §12.5)

### T-A-01 · Strategic + Tactical AI · [Backend]
AC: stance underdog=aggressive / low-treasury=defensive (test); prioritas zone deterministik dengan seed; TIDAK pernah memilih Core node (assertion + test).

### T-A-02 · BattleResolverAI + VirtualPlayerSlot · [Backend]
AC: resolve power proxy `rand(0.8,1.2)`; casualties 15% loser; slot `virtual:true` tersaring dari leaderboard (test query); tidak ada loot/currency dihasilkan (audit ledger: nol entry ber-reason AI).

### T-A-03 · Hard-rules enforcement & telemetry · [Backend]
AC: win-rate malam dicap 40% (test simulasi 1000 battle), influence AI ≤25%/node/hari, fade-out 10 menit, yield atomik saat player enter (test race); semua event ke ai_telemetry; alert webhook saat win-rate >35%.

### T-A-04 · Client transparency UI (v1.0 §8.5, §13.2) · [Flutter]
AC: badge node, panel "Low Activity Support Active", prefix [AI] di battle log, layar settings % aktivitas AI per faction — semua dari field API, golden test.

**GATE M3**: perang hidup di staging 72 jam dengan AI Filler ON tanpa pelanggaran hard rule (audit telemetry otomatis); load test siege 200 player simultan p95 <300ms.

---

# MILESTONE M4 — NEXUS, GACHA, PROGRESI, MONETISASI

### T-N-01 · Nexus City lengkap (template §12.4) · [Flutter+Data]
AC: region neutral, 10 NPC fungsional penuh (merchant/blacksmith/inn/banker/quest/lore/custodian/blackmarket/relations/medic); black market rotasi stok mingguan server-side; test: pvp_enabled false, beli=CRD, jual=faction currency.

### T-N-02 · Crafting & blacksmith · [Engine+Flutter+Backend]
AC: resep dari items.json; success rate Aethel +10% diterapkan server; upgrade/repair memotong CRD material via ledger; test success-rate statistik (n=10k, toleransi ±1%).

### T-P-01 · Class promotion (template §12.2) · [Engine+Backend+Flutter]
AC: PromotionResult 4 varian persis (success/insufficientLevel/trainerRequired/alreadyPromoted); validasi server final; skill baru aktif di battle setelah promote; test client+server.

### T-P-02 · Leveling & stat growth · [Engine+Data]
AC: kurva XP dari config; stat per level per class dari class_tree; simulasi lv1→60 menghasilkan kurva power monotonic (test).

### T-G-01 · Gacha server-side + pity (D-06) · [Backend]
AC: odds dari config; pity 80 (config); roll auditable (seed+hash disimpan); test distribusi n=100k dalam toleransi ±0.2%; pull standar pakai CRD, premium pakai Ruby — keduanya via ledger.

### T-G-02 · Gacha client + disclosure odds · [Flutter]
AC: layar odds resmi (persyaratan store) dapat diakses dari banner; animasi pull; riwayat pull dari server; tidak ada logika roll di client (audit).

### T-M-01 · IAP Ruby (Play Billing + StoreKit) · [Flutter+Backend]
AC: server-side receipt verification; Ruby HANYA masuk via verifikasi sukses (ledger reason `iap`); restore purchase; sandbox test matrix (sukses/cancel/refund/replay-attack ditolak).

### T-M-02 · Shop kosmetik + accelerator cap 2× · [Flutter+Backend]
AC: tidak ada item berdampak stat dijual Ruby (review checklist v1.0 §11 sebagai test data-driven: item shop dengan statMods ≠ 0 dan currency Ruby → CI merah).

### T-AL-01 · Ally roster: recruit/train/promote + behavior assignment · [Flutter+Backend]
AC: ally dari gacha masuk roster; training currency rules; profil AI dipakai engine battle; kapasitas roster (config) ditegakkan.

**GATE M4**: loop penuh game main end-to-end di staging; checklist monetisasi v1.0 §11 lulus sebagai automated test; draft store listing + odds disclosure siap.

---

# MILESTONE M5 — HARDENING & BETA TERTUTUP

### T-QA-01 · Test pyramid penuh · [QA Agent]
AC: unit (engine/services) + widget/golden (UI inti) + integration (auth→battle→reward→exchange happy path & 10 jalur gagal) jalan di CI <20 menit; flaky test = P1.

### T-QA-02 · Guard arsitektur · [QA Agent]
AC: test import-guard (engine bebas Flutter/Flame; features tidak import engine internal langsung kecuali via API), lint SQL no-UPDATE ledger, dependency-cruiser/custom script di CI.

### T-QA-03 · Performa & profil · [Perf Agent]
AC: 60fps device menengah pada world ramai (50 entitas) & battle; memory leak nol pada 30× transisi world↔battle; cold start <4s; laporan profil tercatat per build.

### T-SEC-01 · Audit keamanan · [Security Agent]
AC: rate-limit semua endpoint mutasi; JWT refresh rotation; idempotency semua POST currency; pentest checklist (OWASP MASVS L1) dengan temuan P0/P1 = 0; secrets scan CI.

### T-OPS-01 · Observabilitas · [DevOps]
AC: Crashlytics + Sentry backend; dashboard: crash-free, p95 API, ERE tick, AI win-rate, inflasi harian; alert ke channel tim; runbook insiden (rollback rate, freeze ekonomi, kill-switch AI Filler, maintenance mode) ditulis & DIUJI di staging.

### T-BETA-01 · Beta tertutup (50–200 pemain) · [Producer+semua]
AC: 2 minggu; crash-free ≥99.5%; D1 retention terukur (target BASELINE 35%); semua P0/P1 ditutup; ekonomi nyata dibandingkan simulasi (deviasi >20% → re-tune + catat).

**GATE M5**: semua di atas + keputusan GO/NO-GO beta terbuka berdasar data, bukan perasaan.

---

# MILESTONE M6 — BETA TERBUKA → RILIS

### T-REL-01 · Kepatuhan store · [Producer Agent]
AC: rating usia (IARC), privacy policy + akun deletion flow in-app, odds gacha tampil, kebijakan loot-box per negara target diverifikasi (catat keputusan per region), screenshot/video listing final 2 bahasa.

### T-REL-02 · Beta terbuka + load test produksi · [DevOps]
AC: soak test 7 hari beban 5× proyeksi DAU; autoscaling teruji; biaya infra per DAU dihitung & masuk laporan.

### T-REL-03 · Konten rilis lengkap · [Content]
AC: 7 faction capital region + Nexus playable; minimal 3 dungeon; codex lore 30 entri; semua lewat validator CI + playthrough manual checklist.

### T-REL-04 · Rilis bertahap · [Producer]
AC: staged rollout 10%→50%→100% dengan gate crash-free per tahap; rollback plan teruji; war-room schedule minggu pertama.

### T-LIVE-01 · Live-ops siap hari-1 · [Backend+Producer]
AC: remote config (event, rate tuning, kill-switch), berita in-game/ticker (§13.3), jadwal event 4 minggu pertama, proses hotfix <24 jam terdokumentasi & dilatih sekali.

---

# BACKLOG PASCA-RILIS (jangan dikerjakan sebelum rilis — tulis di sini supaya tidak menggoda scope)

Pindah faction berbayar penalti · PvP arena Nexus-sanctioned · Guild/companies dalam faction · Season influence reset · Housing capital · Remnant raid boss lintas-faction · Marketplace player-to-player (risiko ekonomi tinggi — wajib simulasi ulang).

---

## MATRIKS DEPENDENSI ANTAR-EPIC (ringkas)

```
S0 → semua
D0 → C, W, E, Q, F, N, G, P
C  → F(partisipasi siege), N(crafting battle-test), G(ally dipakai battle)
E  → Q(reward), F(treasury), G(pull CRD), M(IAP ledger)
F  → A (AI mengisi war yang sudah ada)
Semua → QA/SEC/OPS (M5) → REL (M6)
```
