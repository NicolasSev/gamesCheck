import { createAdminClient } from "@/lib/supabase/server";
import { Sidebar } from "@/components/sidebar";

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createAdminClient();

  const { count } = await supabase
    .from("player_claims")
    .select("*", { count: "exact", head: true })
    .eq("status", "pending");

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar pendingClaims={count ?? 0} />
      <main className="flex-1 ml-60 p-8 overflow-auto">{children}</main>
    </div>
  );
}
