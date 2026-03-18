"use server";

import { createAdminClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function updateUserProfile(
  userId: string,
  values: {
    is_super_admin?: boolean;
    subscription_status?: string;
    is_public?: boolean;
  }
) {
  const supabase = await createAdminClient();
  const { error } = await supabase
    .from("profiles")
    .update(values)
    .eq("id", userId);
  if (error) throw new Error(error.message);
  revalidatePath(`/users/${userId}`);
  revalidatePath("/users");
}

export async function deleteUserAccount(userId: string) {
  const supabase = await createAdminClient();
  await supabase.rpc("delete_user_account", { p_user_id: userId });
  revalidatePath("/users");
}
