# CHANGELOG — EOXRPG Client

## 2026-06-16 — Tap-to-Aim + Viewport Fix

### Added
- **Tap-to-aim system** — tap skill button to select, tap map to fire
- Range circle indicator (red semi-transparent) around player when skill selected
- Gold border highlight on selected skill button
- Precision fix using `camera.viewfinder.position`

### Fixed
- **Viewport button repositioning** — buttons now use `dx`/`dy` offsets + `onGameResize`, survive cold start orientation switch
- **Duplicate AppLogger registration** in GetIt
- **Kotlin incremental cache corruption** (`gradle.properties`)

## 2026-06-15 — M0+M1 Foundation (Offline-First)

### Added
- `lib/core/` — config, env, error, logger, DI (GetIt)
- `lib/data/master/` — local master data loader (assets/data/)
- `assets/data/` — 11 JSON files: config_baseline, skills, status_effects, class_tree, element_table, factions, world_map, nexus_city, monster_master, items, ally_master
- `lib/engine/combat/` — turn-based combat engine: battle_unit, battle_event, turn_queue, combat_engine, ally_ai
- `lib/features/combat/` — CombatBloc, BattleScene (Flame), BattleOverlay, BattleScreen
- `lib/features/world/` — WorldGame (NPCs + encounter trigger + dialog), EncounterTriggerComponent
- `lib/features/factionwar/` — WarMapBloc, WarMapScreen (strategic map + node render)
- `lib/game/npc_component.dart` — 10 NPC types with tap → dialog
- `lib/game/node_component.dart` — faction war node with AI badge
- `lib/ui/overlays/dialog_overlay.dart` — NPC dialogue + typed action buttons
- 26 new tests in `test/battle_engine_test.dart`

### Changed
- `lib/main.dart` — simplified to offline-first MaterialApp, WorldGame, Navigator-based battle
- `lib/game/eox_game.dart` — added navy background color (#1A1A2E)
- `lib/features/world/world_game.dart` — hardened with try-catch, callback-based navigation
- `pubspec.yaml` — stripped Supabase, GoRouter, Dio, fl_chart, intl, dartz

### Removed
- Supabase integration (postponed — will re-add after offline core is stable)
- GoRouter navigation (replaced with Navigator)
- Dio HTTP client

### Fixed
- Kotlin incremental cache corruption (`gradle.properties` + `kotlin.incremental=false`)
- GetIt duplicate registration crash for AppLogger
- Background now navy instead of pure black for render debugging

### Known
- Battle overlay renders placeholder colored rectangles (sprites pending)
- NPCs render as colored circles + letters (full sprites pending)
- World map screen uses colored rectangles (map art pending)
- Combat is engine-only (no Flutter/Flame import in `lib/engine/`)
