"use server";

import { createAdminClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function updateClaimStatus(
  claimId: string,
  status: "approved" | "rejected"
) {
  const supabase = await createAdminClient();
  const { error } = await supabase
    .from("player_claims")
    .update({
      status,
      resolved_at: new Date().toISOString(),
    })
    .eq("id", claimId);
  if (error) throw new Error(error.message);
  revalidatePath("/claims");
}
