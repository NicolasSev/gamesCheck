import { createAdminClient } from "@/lib/supabase/server";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { HorizontalBarChart, GameTypePieChart } from "@/components/charts/analytics-charts";
import { GamesChart } from "@/components/charts/games-chart";
import type { UserStatistics, GamePlayer, Game } from "@/types/database";
import { format, subDays, eachDayOfInterval } from "date-fns";

export const dynamic = "force-dynamic";

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

export default async function AnalyticsPage() {
  const supabase = await createAdminClient();

  const [
    topPlayersRes,
    gameTypesRes,
    gamesByDayRes,
    avgBuyinByTypeRes,
    userStatsRes,
  ] = await Promise.all([
    supabase
      .from("user_statistics")
      .select("*")
      .order("balance", { ascending: false })
      .limit(10),
    supabase
      .from("games")
      .select("game_type")
      .eq("soft_deleted", false),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (supabase as any).rpc("games_by_day", { days_back: 60 }),
    supabase
      .from("game_players")
      .select("buyin, games(game_type)")
      .limit(5000),
    supabase
      .from("user_statistics")
      .select("total_games_played, balance, win_rate, avg_profit"),
  ]);

  // Top players — enrich with usernames
  const topStatsData = (topPlayersRes.data ?? []) as UserStatistics[];
  const topPlayerIds = topStatsData.map((u) => u.user_id);
  const { data: topProfiles } = topPlayerIds.length
    ? await supabase
        .from("profiles")
        .select("id, username")
        .in("id", topPlayerIds)
    : { data: [] };

  const usernameMap = new Map(
    (topProfiles ?? []).map((p) => [p.id, p.username])
  );
  const topPlayers = topStatsData.map((u) => ({
    label: usernameMap.get(u.user_id) ?? u.user_id.slice(0, 8),
    value: Math.round(Number(u.balance)),
    games: u.total_games_played,
    winRate: Number(u.win_rate),
  }));

  // Game type distribution
  const typeCount = new Map<string, number>();
  for (const g of (gameTypesRes.data ?? []) as Pick<Game, "game_type">[]) {
    typeCount.set(g.game_type, (typeCount.get(g.game_type) ?? 0) + 1);
  }
  const gameTypePie = Array.from(typeCount.entries()).map(([label, value]) => ({
    label,
    value,
  }));

  // Games by day (60d)
  const gamesByDay = fillDays(
    ((gamesByDayRes.data ?? []) as { day: string; count: number }[]).map(
      (r) => ({ day: r.day, count: Number(r.count) })
    ),
    60
  );

  // Avg buyin by type
  const buyinByType = new Map<string, number[]>();
  type GamePlayerWithGame = { buyin: number; games: { game_type: string } | null };
  for (const gp of (avgBuyinByTypeRes.data ?? []) as unknown as GamePlayerWithGame[]) {
    const games = gp.games;
    if (!games) continue;
    const type = games.game_type;
    if (!buyinByType.has(type)) buyinByType.set(type, []);
    buyinByType.get(type)!.push(Number(gp.buyin));
  }
  const avgBuyinData = Array.from(buyinByType.entries()).map(
    ([label, values]) => ({
      label,
      value: Math.round(values.reduce((a, b) => a + b, 0) / values.length),
    })
  );

  // Overall stats
  const allStats = (userStatsRes.data ?? []) as UserStatistics[];
  const totalBalance = allStats.reduce((s, u) => s + Number(u.balance), 0);
  const avgWinRate =
    allStats.length > 0
      ? allStats.reduce((s, u) => s + Number(u.win_rate), 0) / allStats.length
      : 0;
  const avgProfit =
    allStats.length > 0
      ? allStats.reduce((s, u) => s + Number(u.avg_profit), 0) / allStats.length
      : 0;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Analytics</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Platform-wide statistics
        </p>
      </div>

      {/* Overview cards */}
      <div className="grid grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-5">
            <p className="text-xs text-muted-foreground">Total Platform Balance</p>
            <p className={`text-2xl font-bold mt-1 ${totalBalance >= 0 ? "text-green-500" : "text-red-500"}`}>
              {totalBalance >= 0 ? "+" : ""}{totalBalance.toLocaleString()} ₸
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <p className="text-xs text-muted-foreground">Avg Win Rate</p>
            <p className="text-2xl font-bold mt-1">
              {(avgWinRate * 100).toFixed(1)}%
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <p className="text-xs text-muted-foreground">Avg Profit / Session</p>
            <p className={`text-2xl font-bold mt-1 ${avgProfit >= 0 ? "text-green-500" : "text-red-500"}`}>
              {avgProfit >= 0 ? "+" : ""}{Math.round(avgProfit).toLocaleString()} ₸
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Games over time */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Games per Day (60 days)</CardTitle>
        </CardHeader>
        <CardContent>
          <GamesChart data={gamesByDay} />
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        {/* Game type distribution */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Game Type Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <GameTypePieChart data={gameTypePie} />
          </CardContent>
        </Card>

        {/* Avg buyin by type */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Avg Buyin by Type</CardTitle>
          </CardHeader>
          <CardContent>
            <HorizontalBarChart
              data={avgBuyinData.map((d) => ({
                ...d,
                label: `${d.label} (~${d.value.toLocaleString()} ₸)`,
              }))}
            />
          </CardContent>
        </Card>
      </div>

      {/* Top players */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Top 10 Players by Balance</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>#</TableHead>
                <TableHead>Username</TableHead>
                <TableHead className="text-right">Games</TableHead>
                <TableHead className="text-right">Win Rate</TableHead>
                <TableHead className="text-right">Balance</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {topPlayers.map((player, idx) => (
                <TableRow key={player.label}>
                  <TableCell className="text-muted-foreground">
                    {idx + 1}
                  </TableCell>
                  <TableCell className="font-medium">{player.label}</TableCell>
                  <TableCell className="text-right">{player.games}</TableCell>
                  <TableCell className="text-right">
                    {(player.winRate * 100).toFixed(0)}%
                  </TableCell>
                  <TableCell
                    className={`text-right font-semibold ${
                      player.value >= 0 ? "text-green-500" : "text-red-500"
                    }`}
                  >
                    {player.value >= 0 ? "+" : ""}
                    {player.value.toLocaleString()} ₸
                  </TableCell>
                </TableRow>
              ))}
              {topPlayers.length === 0 && (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="text-center py-8 text-muted-foreground"
                  >
                    No data yet
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
