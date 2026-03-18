import { createAdminClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/stat-card";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { GamesChart } from "@/components/charts/games-chart";
import {
  Users,
  Gamepad2,
  ClipboardList,
  TrendingUp,
  UserPlus,
  Activity,
} from "lucide-react";
import { format, subDays, eachDayOfInterval } from "date-fns";

export const dynamic = "force-dynamic";

function formatCurrency(n: number) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M ₸`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K ₸`;
  return `${n} ₸`;
}

function fillDays(
  data: { day: string; count: number }[],
  days = 30
): { day: string; count: number }[] {
  const map = new Map(data.map((d) => [d.day, d.count]));
  const interval = eachDayOfInterval({
    start: subDays(new Date(), days - 1),
    end: new Date(),
  });
  return interval.map((date) => {
    const key = format(date, "yyyy-MM-dd");
    return { day: format(date, "MMM d"), count: map.get(key) ?? 0 };
  });
}

export default async function DashboardPage() {
  const supabase = await createAdminClient();

  const [statsRes, gamesByDayRes, regsByDayRes, recentGamesRes] =
    await Promise.all([
      supabase.rpc("admin_dashboard_stats"),
      supabase.rpc("games_by_day", { days_back: 30 }),
      supabase.rpc("registrations_by_day", { days_back: 30 }),
      supabase
        .from("admin_games_overview")
        .select("*")
        .order("timestamp", { ascending: false })
        .limit(8),
    ]);

  type DayCount = { day: string; count: number };
  const stats = (statsRes.data as unknown as { total_users: number; active_users_30d: number; total_games: number; games_this_week: number; pending_claims: number; total_buyins: number; new_users_this_week: number }[])?.[0];
  const gamesByDay = fillDays(
    ((gamesByDayRes.data ?? []) as unknown as DayCount[]).map((r) => ({
      day: r.day,
      count: Number(r.count),
    }))
  );
  const regsByDay = fillDays(
    ((regsByDayRes.data ?? []) as unknown as DayCount[]).map((r) => ({
      day: r.day,
      count: Number(r.count),
    }))
  );
  const recentGames = (recentGamesRes.data ?? []) as {
    id: string; game_type: string; creator_username: string; player_count: number; total_buyins: number; timestamp: string; soft_deleted: boolean;
  }[];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Overview of Fish & Chips activity
        </p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-2 xl:grid-cols-3 gap-4">
        <StatCard
          title="Total Users"
          value={stats?.total_users ?? 0}
          sub={`+${stats?.new_users_this_week ?? 0} this week`}
          icon={Users}
          trend="up"
        />
        <StatCard
          title="Active (30d)"
          value={stats?.active_users_30d ?? 0}
          sub="logged in last 30 days"
          icon={Activity}
        />
        <StatCard
          title="Total Games"
          value={stats?.total_games ?? 0}
          sub={`+${stats?.games_this_week ?? 0} this week`}
          icon={Gamepad2}
          trend="up"
        />
        <StatCard
          title="Pending Claims"
          value={stats?.pending_claims ?? 0}
          sub="awaiting approval"
          icon={ClipboardList}
          trend={Number(stats?.pending_claims) > 0 ? "down" : "neutral"}
        />
        <StatCard
          title="Total Volume"
          value={formatCurrency(Number(stats?.total_buyins ?? 0))}
          sub="all-time buyins"
          icon={TrendingUp}
        />
        <StatCard
          title="New Users"
          value={stats?.new_users_this_week ?? 0}
          sub="last 7 days"
          icon={UserPlus}
          trend="up"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Games per Day (30d)</CardTitle>
          </CardHeader>
          <CardContent>
            <GamesChart data={gamesByDay} />
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Registrations per Day (30d)</CardTitle>
          </CardHeader>
          <CardContent>
            <GamesChart data={regsByDay} />
          </CardContent>
        </Card>
      </div>

      {/* Recent Games */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Recent Games</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-muted-foreground">
                  <th className="text-left pb-3 font-medium">Type</th>
                  <th className="text-left pb-3 font-medium">Creator</th>
                  <th className="text-left pb-3 font-medium">Players</th>
                  <th className="text-left pb-3 font-medium">Buyins</th>
                  <th className="text-left pb-3 font-medium">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {recentGames.map((game) => (
                  <tr key={game.id} className="hover:bg-muted/40">
                    <td className="py-3 font-medium">{game.game_type}</td>
                    <td className="py-3 text-muted-foreground">
                      {game.creator_username}
                    </td>
                    <td className="py-3">{game.player_count}</td>
                    <td className="py-3">
                      {Number(game.total_buyins).toLocaleString()} ₸
                    </td>
                    <td className="py-3 text-muted-foreground">
                      {game.timestamp
                        ? format(new Date(game.timestamp), "MMM d, yyyy")
                        : "—"}
                    </td>
                  </tr>
                ))}
                {recentGames.length === 0 && (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-muted-foreground">
                      No games yet
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
