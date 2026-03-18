"use server";

import { createAdminClient } from "@/lib/supabase/server";

interface PushResult {
  success: boolean;
  sent: number;
  error?: string;
}

export async function sendPushNotification(
  title: string,
  body: string,
  targetType: "all" | "specific",
  targetUserId?: string
): Promise<PushResult> {
  const supabase = await createAdminClient();

  let tokens: string[] = [];

  if (targetType === "specific" && targetUserId) {
    const { data } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", targetUserId);
    tokens = (data ?? []).map((d) => d.token);
  } else {
    const { data } = await supabase
      .from("device_tokens")
      .select("token");
    tokens = (data ?? []).map((d) => d.token);
  }

  if (tokens.length === 0) {
    return { success: false, sent: 0, error: "No device tokens found" };
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  try {
    const resp = await fetch(`${supabaseUrl}/functions/v1/send-push`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${serviceKey}`,
      },
      body: JSON.stringify({
        type: "admin_broadcast",
        title,
        body,
        tokens,
      }),
    });

    if (!resp.ok) {
      return {
        success: false,
        sent: 0,
        error: `Edge Function error: ${resp.status}`,
      };
    }

    const data = await resp.json();
    return { success: true, sent: data.sent ?? tokens.length };
  } catch (e) {
    return { success: false, sent: 0, error: String(e) };
  }
}
