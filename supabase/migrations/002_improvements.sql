-- ============================================================
-- Fish & Chips: Migration 002 — Improvements
-- ============================================================

-- ============================================================
-- 1. GDPR: Полное удаление аккаунта
-- ============================================================

-- Функция для полного удаления пользователя и всех его данных
-- CASCADE FK удалит: game_players, player_aliases, player_claims, device_tokens
-- Игры НЕ удаляются (creator_id SET NULL), чтобы сохранить историю для других игроков
CREATE OR REPLACE FUNCTION delete_user_account(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Soft delete всех игр пользователя
    UPDATE games SET soft_deleted = TRUE WHERE creator_id = p_user_id;

    -- Удалить профиль (CASCADE удалит aliases, device_tokens)
    DELETE FROM profiles WHERE id = p_user_id;

    -- Удалить из auth.users (требует SECURITY DEFINER)
    DELETE FROM auth.users WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. Серверная валидация
-- ============================================================

-- Проверка: нельзя создать claim на свою собственную игру
CREATE OR REPLACE FUNCTION validate_claim()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.claimant_id = NEW.host_id THEN
        RAISE EXCEPTION 'Cannot claim your own game';
    END IF;

    -- Проверка: нет дубликатов pending claims
    IF EXISTS (
        SELECT 1 FROM player_claims
        WHERE game_id = NEW.game_id
          AND claimant_id = NEW.claimant_id
          AND status = 'pending'
          AND id != NEW.id
    ) THEN
        RAISE EXCEPTION 'Duplicate pending claim exists';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_claim_before_insert
    BEFORE INSERT ON player_claims
    FOR EACH ROW EXECUTE FUNCTION validate_claim();

-- Проверка: баланс игры (sum buyins = sum cashouts) — warning, не block
-- Реализуется как функция для вызова из клиента
CREATE OR REPLACE FUNCTION check_game_balance(p_game_id UUID)
RETURNS TABLE(is_balanced BOOLEAN, total_buyins BIGINT, total_cashouts BIGINT, diff BIGINT) AS $$
    SELECT
        COALESCE(SUM(buyin), 0) = COALESCE(SUM(cashout), 0) AS is_balanced,
        COALESCE(SUM(buyin), 0) AS total_buyins,
        COALESCE(SUM(cashout), 0) AS total_cashouts,
        COALESCE(SUM(cashout), 0) - COALESCE(SUM(buyin), 0) AS diff
    FROM game_players
    WHERE game_id = p_game_id;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- 3. Database Webhooks (для push-уведомлений)
-- ============================================================

-- Webhooks настраиваются через Supabase Dashboard:
-- 1. Database → Webhooks → Create Webhook
-- 2. Table: games, Event: INSERT → URL: edge-function/send-push
-- 3. Table: player_claims, Event: INSERT/UPDATE → URL: edge-function/send-push

-- ============================================================
-- 4. Обновление materialized views (cron)
-- ============================================================

-- Для pg_cron (включить в Supabase Dashboard → Database → Extensions):
-- SELECT cron.schedule('refresh-game-summaries', '*/15 * * * *',
--   'REFRESH MATERIALIZED VIEW CONCURRENTLY game_summaries');
-- SELECT cron.schedule('refresh-user-statistics', '*/15 * * * *',
--   'REFRESH MATERIALIZED VIEW CONCURRENTLY user_statistics');

-- Ручное обновление:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY game_summaries;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY user_statistics;
