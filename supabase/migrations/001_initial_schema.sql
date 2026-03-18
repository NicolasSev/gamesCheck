-- ============================================================
-- Fish & Chips: Supabase Migration — Initial Schema
-- ============================================================
-- Запускать в Supabase SQL Editor или через supabase db push
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- profiles: объединяет User + PlayerProfile (связь 1:1 через auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    is_anonymous BOOLEAN NOT NULL DEFAULT TRUE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_super_admin BOOLEAN NOT NULL DEFAULT FALSE,
    subscription_status TEXT NOT NULL DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    total_games_played INTEGER NOT NULL DEFAULT 0,
    total_buyins NUMERIC(12,2) NOT NULL DEFAULT 0,
    total_cashouts NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_type TEXT NOT NULL DEFAULT 'Poker',
    creator_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    soft_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE game_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    player_name TEXT,
    buyin INTEGER NOT NULL DEFAULT 0,
    cashout BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE player_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    alias_name TEXT UNIQUE NOT NULL,
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    games_count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE player_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_name TEXT NOT NULL,
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    game_player_id UUID REFERENCES game_players(id) ON DELETE SET NULL,
    claimant_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    host_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    resolved_at TIMESTAMPTZ,
    resolved_by_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE billiard_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    score_player1 SMALLINT NOT NULL DEFAULT 0,
    score_player2 SMALLINT NOT NULL DEFAULT 0,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX idx_games_creator ON games(creator_id);
CREATE INDEX idx_games_timestamp ON games(timestamp DESC);
CREATE INDEX idx_games_updated ON games(updated_at DESC);
CREATE INDEX idx_game_players_game ON game_players(game_id);
CREATE INDEX idx_game_players_profile ON game_players(profile_id);
CREATE INDEX idx_player_aliases_profile ON player_aliases(profile_id);
CREATE INDEX idx_player_claims_claimant ON player_claims(claimant_id);
CREATE INDEX idx_player_claims_host ON player_claims(host_id);
CREATE INDEX idx_player_claims_status ON player_claims(status) WHERE status = 'pending';
CREATE UNIQUE INDEX idx_device_tokens_token ON device_tokens(token);

-- ============================================================
-- 3. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE billiard_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles_select" ON profiles
    FOR SELECT USING (is_public OR id = auth.uid());

CREATE POLICY "profiles_insert" ON profiles
    FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update" ON profiles
    FOR UPDATE USING (id = auth.uid());

-- games
CREATE POLICY "games_select" ON games
    FOR SELECT USING (is_public OR creator_id = auth.uid());

CREATE POLICY "games_insert" ON games
    FOR INSERT WITH CHECK (creator_id = auth.uid());

CREATE POLICY "games_update" ON games
    FOR UPDATE USING (creator_id = auth.uid());

CREATE POLICY "games_delete" ON games
    FOR DELETE USING (creator_id = auth.uid());

-- game_players
CREATE POLICY "game_players_select" ON game_players
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = game_players.game_id
            AND (games.is_public OR games.creator_id = auth.uid())
        )
    );

CREATE POLICY "game_players_insert" ON game_players
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = game_players.game_id
            AND games.creator_id = auth.uid()
        )
    );

CREATE POLICY "game_players_update" ON game_players
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = game_players.game_id
            AND games.creator_id = auth.uid()
        )
    );

CREATE POLICY "game_players_delete" ON game_players
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = game_players.game_id
            AND games.creator_id = auth.uid()
        )
    );

-- player_aliases
CREATE POLICY "player_aliases_select" ON player_aliases
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = player_aliases.profile_id
            AND (profiles.is_public OR profiles.id = auth.uid())
        )
    );

CREATE POLICY "player_aliases_insert" ON player_aliases
    FOR INSERT WITH CHECK (profile_id = auth.uid());

CREATE POLICY "player_aliases_update" ON player_aliases
    FOR UPDATE USING (profile_id = auth.uid());

CREATE POLICY "player_aliases_delete" ON player_aliases
    FOR DELETE USING (profile_id = auth.uid());

-- player_claims
CREATE POLICY "player_claims_select" ON player_claims
    FOR SELECT USING (claimant_id = auth.uid() OR host_id = auth.uid());

CREATE POLICY "player_claims_insert" ON player_claims
    FOR INSERT WITH CHECK (claimant_id = auth.uid());

CREATE POLICY "player_claims_update" ON player_claims
    FOR UPDATE USING (host_id = auth.uid());

-- billiard_batches
CREATE POLICY "billiard_batches_select" ON billiard_batches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = billiard_batches.game_id
            AND (games.is_public OR games.creator_id = auth.uid())
        )
    );

CREATE POLICY "billiard_batches_insert" ON billiard_batches
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = billiard_batches.game_id
            AND games.creator_id = auth.uid()
        )
    );

CREATE POLICY "billiard_batches_delete" ON billiard_batches
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM games
            WHERE games.id = billiard_batches.game_id
            AND games.creator_id = auth.uid()
        )
    );

-- device_tokens
CREATE POLICY "device_tokens_select" ON device_tokens
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "device_tokens_insert" ON device_tokens
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_delete" ON device_tokens
    FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- 4. FUNCTIONS & TRIGGERS
-- ============================================================

-- Автообновление updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_games_updated_at
    BEFORE UPDATE ON games
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Автопересчёт статистики профиля при изменении game_players
CREATE OR REPLACE FUNCTION recalculate_profile_stats()
RETURNS TRIGGER AS $$
DECLARE
    target_profile_id UUID;
BEGIN
    target_profile_id := COALESCE(NEW.profile_id, OLD.profile_id);
    IF target_profile_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    UPDATE profiles SET
        total_games_played = sub.cnt,
        total_buyins = sub.buyins,
        total_cashouts = sub.cashouts
    FROM (
        SELECT
            COUNT(*) AS cnt,
            COALESCE(SUM(buyin), 0) AS buyins,
            COALESCE(SUM(cashout), 0) AS cashouts
        FROM game_players
        WHERE profile_id = target_profile_id
    ) sub
    WHERE profiles.id = target_profile_id;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profile_stats_on_insert
    AFTER INSERT ON game_players
    FOR EACH ROW EXECUTE FUNCTION recalculate_profile_stats();

CREATE TRIGGER update_profile_stats_on_update
    AFTER UPDATE ON game_players
    FOR EACH ROW EXECUTE FUNCTION recalculate_profile_stats();

CREATE TRIGGER update_profile_stats_on_delete
    AFTER DELETE ON game_players
    FOR EACH ROW EXECUTE FUNCTION recalculate_profile_stats();

-- Автосоздание профиля при регистрации через Supabase Auth
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, display_name, created_at)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', NEW.email),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Serverside checksum для smart sync
CREATE OR REPLACE FUNCTION get_game_checksums(p_user_id UUID)
RETURNS TABLE(game_id UUID, checksum TEXT) AS $$
    SELECT
        g.id,
        MD5(CONCAT(
            g.id::TEXT, '_',
            EXTRACT(EPOCH FROM g.timestamp)::TEXT, '_',
            (SELECT COUNT(*) FROM game_players gp WHERE gp.game_id = g.id)::TEXT, '_',
            (SELECT COALESCE(SUM(gp.buyin), 0) FROM game_players gp WHERE gp.game_id = g.id)::TEXT
        ))
    FROM games g
    WHERE g.creator_id = p_user_id AND NOT g.soft_deleted;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- 5. MATERIALIZED VIEWS
-- ============================================================

CREATE MATERIALIZED VIEW game_summaries AS
SELECT
    g.id AS game_id,
    g.creator_id,
    g.game_type,
    g.timestamp,
    COUNT(gp.id) AS total_players,
    COALESCE(SUM(gp.buyin), 0) AS total_buyins,
    g.is_public,
    g.updated_at AS last_modified,
    MD5(CONCAT(
        g.id::TEXT, '_',
        EXTRACT(EPOCH FROM g.timestamp)::TEXT, '_',
        COUNT(gp.id)::TEXT, '_',
        COALESCE(SUM(gp.buyin), 0)::TEXT
    )) AS checksum
FROM games g
LEFT JOIN game_players gp ON g.id = gp.game_id
WHERE NOT g.soft_deleted
GROUP BY g.id;

CREATE UNIQUE INDEX idx_game_summaries_game ON game_summaries(game_id);

CREATE MATERIALIZED VIEW user_statistics AS
SELECT
    p.id AS user_id,
    COUNT(gp.id) AS total_games_played,
    COALESCE(SUM(gp.buyin), 0) AS total_buyins,
    COALESCE(SUM(gp.cashout), 0) AS total_cashouts,
    COALESCE(SUM(gp.cashout), 0) - COALESCE(SUM(gp.buyin), 0) AS balance,
    MAX(g.timestamp) AS last_game_date,
    CASE
        WHEN COUNT(gp.id) > 0
        THEN ROUND(
            COUNT(CASE WHEN gp.cashout > gp.buyin THEN 1 END)::NUMERIC
            / COUNT(gp.id) * 100, 1
        )
        ELSE 0
    END AS win_rate,
    CASE
        WHEN COUNT(gp.id) > 0
        THEN ROUND(
            (COALESCE(SUM(gp.cashout), 0) - COALESCE(SUM(gp.buyin), 0))::NUMERIC
            / COUNT(gp.id), 2
        )
        ELSE 0
    END AS avg_profit,
    NOW() AS last_updated
FROM profiles p
LEFT JOIN game_players gp ON p.id = gp.profile_id
LEFT JOIN games g ON gp.game_id = g.id AND NOT g.soft_deleted
GROUP BY p.id;

CREATE UNIQUE INDEX idx_user_statistics_user ON user_statistics(user_id);

-- ============================================================
-- 6. REALTIME
-- ============================================================

-- Включить Realtime для таблиц, на которые подписывается клиент
ALTER PUBLICATION supabase_realtime ADD TABLE games;
ALTER PUBLICATION supabase_realtime ADD TABLE player_claims;
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;
