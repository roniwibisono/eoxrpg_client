-- ============================================================
-- ECHO OF XYLOS — Supabase Database Schema (GDD v1.1 + D-02)
-- Copy-paste ke Supabase SQL Editor → Run
-- ============================================================

-- 1. PLAYERS (linked to Supabase auth.users)
CREATE TABLE IF NOT EXISTS players (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    TEXT,
  faction_id  TEXT NOT NULL DEFAULT 'nexus_custodian',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "players_select_own" ON players
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "players_insert_own" ON players
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "players_update_own" ON players
  FOR UPDATE USING (auth.uid() = id);


-- 2. CHARACTERS (max 3 slot per player, faction lock permanent)
CREATE TABLE IF NOT EXISTS characters (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id   UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  class_id    TEXT NOT NULL DEFAULT 'novice',
  level       INT NOT NULL DEFAULT 1,
  exp         INT NOT NULL DEFAULT 0,
  faction_id  TEXT NOT NULL,
  hp          INT NOT NULL DEFAULT 500,
  mp          INT NOT NULL DEFAULT 100,
  atk         INT NOT NULL DEFAULT 20,
  def         INT NOT NULL DEFAULT 10,
  spd         INT NOT NULL DEFAULT 10,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "characters_select_own" ON characters
  FOR SELECT USING (auth.uid() = player_id);

CREATE POLICY "characters_insert_own" ON characters
  FOR INSERT WITH CHECK (auth.uid() = player_id);

CREATE POLICY "characters_update_own" ON characters
  FOR UPDATE USING (auth.uid() = player_id);


-- 3. CURRENCY LEDGER (append-only, no UPDATE — GDD §3.3)
CREATE TABLE IF NOT EXISTS currency_ledger (
  id              BIGSERIAL PRIMARY KEY,
  player_id       UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  currency_code   TEXT NOT NULL,
  delta           DOUBLE PRECISION NOT NULL,
  balance_after   DOUBLE PRECISION NOT NULL,
  reason_code     TEXT NOT NULL,
  ref_id          TEXT,
  idempotency_key TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_idempotency
  ON currency_ledger(idempotency_key) WHERE idempotency_key IS NOT NULL;

ALTER TABLE currency_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ledger_select_own" ON currency_ledger
  FOR SELECT USING (auth.uid() = player_id);

-- NO insert/update/delete policy for player — only server-side functions


-- 4. EXCHANGE RATE (ERE — GDD §3.3)
CREATE TABLE IF NOT EXISTS exchange_rate (
  id                    BIGSERIAL PRIMARY KEY,
  faction_code          TEXT NOT NULL,
  rate                  DOUBLE PRECISION NOT NULL,
  score_breakdown_json  JSONB NOT NULL DEFAULT '{}',
  computed_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_erate_faction_time
  ON exchange_rate(faction_code, computed_at DESC);

ALTER TABLE exchange_rate ENABLE ROW LEVEL SECURITY;

CREATE POLICY "erate_select_all" ON exchange_rate FOR SELECT USING (true);


-- 5. NODES STATE (faction war territory)
CREATE TABLE IF NOT EXISTS nodes_state (
  id              TEXT PRIMARY KEY,
  region_id       TEXT NOT NULL,
  zone_id         TEXT NOT NULL,
  tier            TEXT NOT NULL CHECK (tier IN ('outer','tactical','core','capital')),
  owner_faction   TEXT NOT NULL,
  influence       DOUBLE PRECISION NOT NULL DEFAULT 0,
  ai_controlled   BOOLEAN NOT NULL DEFAULT false,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE nodes_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nodes_select_all" ON nodes_state FOR SELECT USING (true);


-- 6. SANCTIONS
CREATE TABLE IF NOT EXISTS sanction (
  id          BIGSERIAL PRIMARY KEY,
  faction_code TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT false,
  reason      TEXT,
  started_at  TIMESTAMPTZ,
  ends_at     TIMESTAMPTZ
);

ALTER TABLE sanction ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sanction_select_all" ON sanction FOR SELECT USING (true);


-- 7. SIEGES
CREATE TABLE IF NOT EXISTS sieges (
  id              BIGSERIAL PRIMARY KEY,
  declarer_faction TEXT NOT NULL,
  target_node_id  TEXT NOT NULL REFERENCES nodes_state(id),
  status          TEXT NOT NULL DEFAULT 'declared'
                  CHECK (status IN ('declared','mobilizing','resolving','resolved','cooldown')),
  declared_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);

ALTER TABLE sieges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "siege_select_all" ON sieges FOR SELECT USING (true);


-- 8. GACHA PITY
CREATE TABLE IF NOT EXISTS gacha_pity (
  id                  BIGSERIAL PRIMARY KEY,
  player_id           UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  banner_id           TEXT NOT NULL,
  counter_since_top   INT NOT NULL DEFAULT 0,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(player_id, banner_id)
);

ALTER TABLE gacha_pity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pity_select_own" ON gacha_pity
  FOR SELECT USING (auth.uid() = player_id);


-- 9. GACHA PULL HISTORY
CREATE TABLE IF NOT EXISTS gacha_pulls (
  id          BIGSERIAL PRIMARY KEY,
  player_id   UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  banner_id   TEXT NOT NULL,
  ally_id     TEXT NOT NULL,
  rarity      TEXT NOT NULL CHECK (rarity IN ('R','SR','SSR')),
  pulled_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE gacha_pulls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pulls_select_own" ON gacha_pulls
  FOR SELECT USING (auth.uid() = player_id);


-- 10. QUESTS (master data)
CREATE TABLE IF NOT EXISTS quests (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL,
  title_key   TEXT NOT NULL,
  description TEXT NOT NULL,
  giver_npc   TEXT,
  objectives  JSONB NOT NULL DEFAULT '[]',
  repeatable  BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "quests_select_all" ON quests FOR SELECT USING (true);


-- 11. PLAYER QUESTS
CREATE TABLE IF NOT EXISTS player_quests (
  id          BIGSERIAL PRIMARY KEY,
  player_id   UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  quest_id    TEXT NOT NULL REFERENCES quests(id),
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed')),
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  UNIQUE(player_id, quest_id)
);

ALTER TABLE player_quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pquests_select_own" ON player_quests
  FOR SELECT USING (auth.uid() = player_id);

CREATE POLICY "pquests_insert_own" ON player_quests
  FOR INSERT WITH CHECK (auth.uid() = player_id);


-- 12. AI TELEMETRY
CREATE TABLE IF NOT EXISTS ai_telemetry (
  id          BIGSERIAL PRIMARY KEY,
  event       TEXT NOT NULL,
  node_id     TEXT,
  faction     TEXT NOT NULL,
  ai_power    DOUBLE PRECISION,
  ts          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE ai_telemetry ENABLE ROW LEVEL SECURITY;

CREATE POLICY "telemetry_select_all" ON ai_telemetry FOR SELECT USING (true);


-- 13. ALLY ROSTER (gacha units owned by player)
CREATE TABLE IF NOT EXISTS ally_roster (
  id          BIGSERIAL PRIMARY KEY,
  player_id   UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  ally_id     TEXT NOT NULL,
  level       INT NOT NULL DEFAULT 1,
  exp         INT NOT NULL DEFAULT 0,
  obtained_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE ally_roster ENABLE ROW LEVEL SECURITY;

CREATE POLICY "roster_select_own" ON ally_roster
  FOR SELECT USING (auth.uid() = player_id);


-- ============================================================
-- REPLICATION SETUP (Supabase Realtime)
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE nodes_state;
ALTER PUBLICATION supabase_realtime ADD TABLE sieges;
ALTER PUBLICATION supabase_realtime ADD TABLE currency_ledger;
ALTER PUBLICATION supabase_realtime ADD TABLE player_quests;


-- ============================================================
-- GACHA PULL FUNCTION (server-side RPC)
-- Run this in a SEPARATE SQL editor after tables are created
-- ============================================================

CREATE OR REPLACE FUNCTION gacha_pull(p_player_id UUID, p_banner_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pity_count   INT;
  v_roll         DOUBLE PRECISION;
  v_rarity       TEXT;
  v_ally_id      TEXT;
  v_ssr_rate     DOUBLE PRECISION := 0.015;
  v_sr_rate      DOUBLE PRECISION := 0.12;
  v_pity_threshold INT := 80;
BEGIN
  -- Get current pity counter
  SELECT counter_since_top INTO v_pity_count
  FROM gacha_pity
  WHERE player_id = p_player_id AND banner_id = p_banner_id;

  IF NOT FOUND THEN
    v_pity_count := 0;
    INSERT INTO gacha_pity (player_id, banner_id, counter_since_top)
    VALUES (p_player_id, p_banner_id, 0);
  END IF;

  v_roll := random();

  -- Pity guarantee at threshold
  IF v_pity_count >= v_pity_threshold THEN
    v_rarity := 'SSR';
  ELSIF v_roll < v_ssr_rate THEN
    v_rarity := 'SSR';
  ELSIF v_roll < v_ssr_rate + v_sr_rate THEN
    v_rarity := 'SR';
  ELSE
    v_rarity := 'R';
  END IF;

  -- Pick random ally of that rarity (placeholder — replace with real banner pool lookup)
  v_ally_id := 'ally_guardian_r';

  -- Record pull
  INSERT INTO gacha_pulls (player_id, banner_id, ally_id, rarity)
  VALUES (p_player_id, p_banner_id, v_ally_id, v_rarity);

  -- Add to roster
  INSERT INTO ally_roster (player_id, ally_id)
  VALUES (p_player_id, v_ally_id);

  -- Update pity
  IF v_rarity = 'SSR' THEN
    UPDATE gacha_pity SET counter_since_top = 0, updated_at = now()
    WHERE player_id = p_player_id AND banner_id = p_banner_id;
  ELSE
    UPDATE gacha_pity SET counter_since_top = counter_since_top + 1, updated_at = now()
    WHERE player_id = p_player_id AND banner_id = p_banner_id;
  END IF;

  RETURN jsonb_build_object(
    'ally_id', v_ally_id,
    'rarity', v_rarity,
    'pity_count', CASE WHEN v_rarity = 'SSR' THEN 0 ELSE v_pity_count + 1 END
  );
END;
$$;
