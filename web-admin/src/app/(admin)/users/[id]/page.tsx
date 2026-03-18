import { createAdminClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { UserForm } from "./user-form";
import { format } from "date-fns";
import { User, Gamepad2, Tags, ClipboardList } from "lucide-react";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createAdminClient();

  const [profileRes, gamesRes, aliasesRes, claimsRes] = await Promise.all([
    supabase.from("profiles").select("*").eq("id", id).single(),
    supabase
      .from("admin_games_overview")
      .select("*")
      .eq("creator_id", id)
      .order("timestamp", { ascending: false })
      .limit(10),
    supabase
      .from("player_aliases")
      .select("*")
      .eq("profile_id", id)
      .order("games_count", { ascending: false }),
    supabase
      .from("admin_claims_overview")
      .select("*")
      .or(`claimant_id.eq.${id},host_id.eq.${id}`)
      .order("created_at", { ascending: false })
      .limit(10),
  ]);

  if (!profileRes.data) notFound();
  const profile = profileRes.data;
  const games = gamesRes.data ?? [];
  const aliases = aliasesRes.data ?? [];
  const claims = claimsRes.data ?? [];

  return (
    <div className="space-y-6 max-w-5xl">
      {/* Header */}
      <div className="flex items-start gap-4">
        <div className="flex items-center justify-center w-14 h-14 rounded-xl bg-muted text-2xl font-bold shrink-0">
          {profile.username.charAt(0).toUpperCase()}
        </div>
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-2">
            {profile.username}
            {profile.is_super_admin && (
              <Badge variant="default">Admin</Badge>
            )}
          </h1>
          <p className="text-muted-foreground text-sm mt-0.5">
            {profile.id}
          </p>
          <p className="text-muted-foreground text-xs mt-0.5">
            Joined{" "}
            {profile.created_at
              ? format(new Date(profile.created_at), "MMMM d, yyyy")
              : "—"}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Stats */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm flex items-center gap-2">
              <User className="w-4 h-4" /> Stats
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Row label="Games Played" value={profile.total_games_played} />
            <Row
              label="Total Buyins"
              value={`${Number(profile.total_buyins).toLocaleString()} ₸`}
            />
            <Row
              label="Total Cashouts"
              value={`${Number(profile.total_cashouts).toLocaleString()} ₸`}
            />
            <Row
              label="Balance"
              value={
                <span
                  className={
                    Number(profile.total_cashouts) -
                      Number(profile.total_buyins) >=
                    0
                      ? "text-green-500"
                      : "text-red-500"
                  }
                >
                  {(
                    Number(profile.total_cashouts) - Number(profile.total_buyins)
                  ).toLocaleString()}{" "}
                  ₸
                </span>
              }
            />
            <Row
              label="Last Login"
              value={
                profile.last_login_at
                  ? format(new Date(profile.last_login_at), "MMM d, yyyy")
                  : "Never"
              }
            />
          </CardContent>
        </Card>

        {/* Edit */}
        <Card className="md:col-span-2">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm">Edit Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <UserForm profile={profile} />
          </CardContent>
        </Card>
      </div>

      {/* Games */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm flex items-center gap-2">
            <Gamepad2 className="w-4 h-4" /> Recent Games ({games.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="divide-y divide-border">
            {games.map((game) => (
              <div
                key={game.id}
                className="flex items-center justify-between py-3"
              >
                <div>
                  <p className="text-sm font-medium">{game.game_type}</p>
                  <p className="text-xs text-muted-foreground">
                    {game.player_count} players ·{" "}
                    {Number(game.total_buyins).toLocaleString()} ₸
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {game.soft_deleted && (
                    <Badge variant="outline" className="text-xs">
                      Deleted
                    </Badge>
                  )}
                  <Link
                    href={`/games/${game.id}`}
                    className="text-xs text-primary hover:underline"
                  >
                    View →
                  </Link>
                  <span className="text-xs text-muted-foreground">
                    {game.timestamp
                      ? format(new Date(game.timestamp), "MMM d")
                      : "—"}
                  </span>
                </div>
              </div>
            ))}
            {games.length === 0 && (
              <p className="py-6 text-center text-muted-foreground text-sm">
                No games
              </p>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Aliases */}
      {aliases.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm flex items-center gap-2">
              <Tags className="w-4 h-4" /> Aliases ({aliases.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {aliases.map((alias) => (
                <Badge key={alias.id} variant="secondary" className="text-xs">
                  {alias.alias_name}
                  {alias.games_count > 0 && (
                    <span className="ml-1 opacity-60">×{alias.games_count}</span>
                  )}
                </Badge>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Claims */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm flex items-center gap-2">
            <ClipboardList className="w-4 h-4" /> Claims ({claims.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="divide-y divide-border">
            {claims.map((claim) => (
              <div
                key={claim.id}
                className="flex items-center justify-between py-3"
              >
                <div>
                  <p className="text-sm font-medium">{claim.player_name}</p>
                  <p className="text-xs text-muted-foreground">
                    {claim.claimant_id === id
                      ? `You claimed → host: ${claim.host_username}`
                      : `Claimant: ${claim.claimant_username}`}
                  </p>
                </div>
                <Badge
                  variant={
                    claim.status === "approved"
                      ? "default"
                      : claim.status === "rejected"
                      ? "destructive"
                      : "secondary"
                  }
                  className="text-xs capitalize"
                >
                  {claim.status}
                </Badge>
              </div>
            ))}
            {claims.length === 0 && (
              <p className="py-6 text-center text-muted-foreground text-sm">
                No claims
              </p>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function Row({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className="text-sm font-medium">{value}</span>
    </div>
  );
}
