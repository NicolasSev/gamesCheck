"use server";

import { createAdminClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function toggleSoftDelete(gameId: string, currentState: boolean) {
  const supabase = await createAdminClient();
  const { error } = await supabase
    .from("games")
    .update({ soft_deleted: !currentState })
    .eq("id", gameId);
  if (error) throw new Error(error.message);
  revalidatePath(`/games/${gameId}`);
  revalidatePath("/games");
}
