-- ============================================================
-- Fish & Chips: Migration 003 — Admin Views & Functions
-- ============================================================

-- ============================================================
-- 1. admin_users_overview
-- ============================================================

CREATE OR REPLACE VIEW admin_users_overview AS
SELECT
    p.id,
    p.username,
    p.display_name,
    p.is_public,
    p.is_super_admin,
    p.subscription_status,
    p.total_games_played,
    p.total_buyins,
    p.total_cashouts,
    COALESCE(p.total_cashouts - p.total_buyins, 0) AS balance,
    p.created_at,
    p.last_login_at
FROM profiles p;

-- ============================================================
-- 2. admin_games_overview
-- ============================================================

CREATE OR REPLACE VIEW admin_games_overview AS
SELECT
    g.id,
    g.game_type,
    g.creator_id,
    COALESCE(p.username, 'unknown') AS creator_username,
    g.is_public,
    g.soft_deleted,
    g.timestamp,
    COALESCE(gp.player_count, 0) AS player_count,
    COALESCE(gp.total_buyins, 0) AS total_buyins
FROM games g
LEFT JOIN profiles p ON g.creator_id = p.id
LEFT JOIN (
    SELECT game_id, COUNT(*) AS player_count, SUM(buyin) AS total_buyins
    FROM game_players
    GROUP BY game_id
) gp ON g.id = gp.game_id;

-- ============================================================
-- 3. admin_claims_overview
-- ============================================================

CREATE OR REPLACE VIEW admin_claims_overview AS
SELECT
    pc.id,
    pc.player_name,
    pc.status,
    pc.claimant_id,
    COALESCE(p_claimant.username, 'unknown') AS claimant_username,
    pc.host_id,
    COALESCE(p_host.username, 'unknown') AS host_username,
    pc.game_id,
    COALESCE(g.game_type, 'unknown') AS game_type,
    pc.notes,
    pc.created_at,
    pc.resolved_at
FROM player_claims pc
LEFT JOIN profiles p_claimant ON pc.claimant_id = p_claimant.id
LEFT JOIN profiles p_host ON pc.host_id = p_host.id
LEFT JOIN games g ON pc.game_id = g.id;

-- ============================================================
-- 4. admin_dashboard_stats()
-- ============================================================

CREATE OR REPLACE FUNCTION admin_dashboard_stats()
RETURNS TABLE (
    total_users        BIGINT,
    active_users_30d   BIGINT,
    total_games        BIGINT,
    games_this_week    BIGINT,
    pending_claims     BIGINT,
    total_buyins       NUMERIC,
    new_users_this_week BIGINT
) AS $$
    SELECT
        (SELECT COUNT(*) FROM profiles)                                             AS total_users,
        (SELECT COUNT(*) FROM profiles
         WHERE last_login_at >= NOW() - INTERVAL '30 days')                         AS active_users_30d,
        (SELECT COUNT(*) FROM games WHERE soft_deleted = FALSE)                     AS total_games,
        (SELECT COUNT(*) FROM games
         WHERE soft_deleted = FALSE
           AND timestamp >= NOW() - INTERVAL '7 days')                              AS games_this_week,
        (SELECT COUNT(*) FROM player_claims WHERE status = 'pending')               AS pending_claims,
        (SELECT COALESCE(SUM(total_buyins), 0) FROM profiles)                       AS total_buyins,
        (SELECT COUNT(*) FROM profiles
         WHERE created_at >= NOW() - INTERVAL '7 days')                             AS new_users_this_week;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- 5. Games by day (for dashboard chart)
-- ============================================================

CREATE OR REPLACE FUNCTION games_by_day(days_back INT DEFAULT 30)
RETURNS TABLE (day DATE, count BIGINT) AS $$
    SELECT
        DATE(timestamp) AS day,
        COUNT(*) AS count
    FROM games
    WHERE soft_deleted = FALSE
      AND timestamp >= NOW() - (days_back || ' days')::INTERVAL
    GROUP BY DATE(timestamp)
    ORDER BY day;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- 6. Registrations by day
-- ============================================================

CREATE OR REPLACE FUNCTION registrations_by_day(days_back INT DEFAULT 30)
RETURNS TABLE (day DATE, count BIGINT) AS $$
    SELECT
        DATE(created_at) AS day,
        COUNT(*) AS count
    FROM profiles
    WHERE created_at >= NOW() - (days_back || ' days')::INTERVAL
    GROUP BY DATE(created_at)
    ORDER BY day;
$$ LANGUAGE sql STABLE;
