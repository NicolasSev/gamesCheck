// Supabase Edge Function: send-push
// Отправляет APNs push-уведомления при изменениях в БД
// Вызывается через Database Webhook или напрямую
//
// Переменные окружения (Supabase Dashboard → Edge Functions → Secrets):
//   APNS_KEY_ID      — Key ID из Apple Developer Portal
//   APNS_TEAM_ID     — Team ID
//   APNS_PRIVATE_KEY — .p8 содержимое (base64)
//   APNS_BUNDLE_ID   — com.nicolascooper.FishAndChips
//   APNS_ENVIRONMENT  — development | production

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PushPayload {
  type: "game_created" | "game_updated" | "claim_created" | "claim_resolved" | "profile_public";
  record: Record<string, unknown>;
  old_record?: Record<string, unknown>;
}

serve(async (req: Request) => {
  try {
    const payload: PushPayload = await req.json();
    const { type, record } = payload;

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    let targetUserIds: string[] = [];
    let title = "";
    let body = "";

    switch (type) {
      case "game_created": {
        title = "Новая игра";
        body = `${record.game_type ?? "Poker"} — новая игра создана`;
        // Notify all users except creator
        const { data: tokens } = await supabase
          .from("device_tokens")
          .select("token")
          .neq("user_id", record.creator_id);
        targetUserIds = (tokens ?? []).map((t: { token: string }) => t.token);
        break;
      }
      case "claim_created": {
        title = "Новая заявка";
        body = `${record.player_name} хочет присоединиться к игре`;
        const { data: tokens } = await supabase
          .from("device_tokens")
          .select("token")
          .eq("user_id", record.host_id);
        targetUserIds = (tokens ?? []).map((t: { token: string }) => t.token);
        break;
      }
      case "claim_resolved": {
        const status = record.status === "approved" ? "одобрена" : "отклонена";
        title = "Заявка " + status;
        body = `Ваша заявка на ${record.player_name} ${status}`;
        const { data: tokens } = await supabase
          .from("device_tokens")
          .select("token")
          .eq("user_id", record.claimant_id);
        targetUserIds = (tokens ?? []).map((t: { token: string }) => t.token);
        break;
      }
      case "profile_public": {
        title = "Новый публичный игрок";
        body = `${record.display_name} открыл свой профиль`;
        const { data: tokens } = await supabase
          .from("device_tokens")
          .select("token")
          .neq("user_id", record.id);
        targetUserIds = (tokens ?? []).map((t: { token: string }) => t.token);
        break;
      }
    }

    if (targetUserIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    // TODO: Implement APNs sending via JWT + HTTP/2
    // For now, log the push payload
    console.log(`Push: ${title} — ${body} → ${targetUserIds.length} devices`);

    return new Response(
      JSON.stringify({
        sent: targetUserIds.length,
        title,
        body,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Push error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
