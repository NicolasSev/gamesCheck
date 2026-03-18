import { createAdminClient } from "@/lib/supabase/server";
import { PushForm } from "./push-form";

export const dynamic = "force-dynamic";

export default async function PushPage() {
  const supabase = await createAdminClient();
  const { count } = await supabase
    .from("device_tokens")
    .select("*", { count: "exact", head: true });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Push Notifications</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Send push notifications via Edge Function
        </p>
      </div>
      <PushForm deviceCount={count ?? 0} />
    </div>
  );
}
