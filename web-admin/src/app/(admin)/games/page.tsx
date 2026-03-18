import { createAdminClient } from "@/lib/supabase/server";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { format } from "date-fns";

export const dynamic = "force-dynamic";

export default async function GamesPage({
  searchParams,
}: {
  searchParams: Promise<{
    type?: string;
    deleted?: string;
    public?: string;
  }>;
}) {
  const params = await searchParams;
  const supabase = await createAdminClient();

  let query = supabase
    .from("admin_games_overview")
    .select("*")
    .order("timestamp", { ascending: false })
    .limit(100);

  if (params.type) {
    query = query.eq("game_type", params.type);
  }
  if (params.deleted === "yes") {
    query = query.eq("soft_deleted", true);
  } else if (params.deleted !== "all") {
    query = query.eq("soft_deleted", false);
  }
  if (params.public === "yes") {
    query = query.eq("is_public", true);
  } else if (params.public === "no") {
    query = query.eq("is_public", false);
  }

  const { data: games } = await query;

  const activeDeleted = params.deleted ?? "no";
  const activeType = params.type ?? "all";
  const activePublic = params.public ?? "all";

  function buildUrl(overrides: Record<string, string>) {
    const p: Record<string, string> = {
      deleted: activeDeleted,
      type: activeType,
      public: activePublic,
      ...overrides,
    };
    const qs = Object.entries(p)
      .filter(([, v]) => v && v !== "all" && v !== "no")
      .map(([k, v]) => `${k}=${v}`)
      .join("&");
    return `/games${qs ? `?${qs}` : ""}`;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Games</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {games?.length ?? 0} games
        </p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="flex gap-2">
          {(["all", "Poker", "Billiard"] as const).map((t) => (
            <Link
              key={t}
              href={buildUrl({ type: t })}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                activeType === t
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              {t}
            </Link>
          ))}
        </div>

        <div className="flex gap-2">
          {([
            { value: "no", label: "Active" },
            { value: "yes", label: "Deleted" },
            { value: "all", label: "All" },
          ] as const).map((opt) => (
            <Link
              key={opt.value}
              href={buildUrl({ deleted: opt.value })}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                activeDeleted === opt.value
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              {opt.label}
            </Link>
          ))}
        </div>

        <div className="flex gap-2">
          {([
            { value: "all", label: "Any" },
            { value: "yes", label: "Public" },
            { value: "no", label: "Private" },
          ] as const).map((opt) => (
            <Link
              key={opt.value}
              href={buildUrl({ public: opt.value })}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                activePublic === opt.value
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              {opt.label}
            </Link>
          ))}
        </div>
      </div>

      <div className="rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Type</TableHead>
              <TableHead>Creator</TableHead>
              <TableHead className="text-right">Players</TableHead>
              <TableHead className="text-right">Total Buyins</TableHead>
              <TableHead>Flags</TableHead>
              <TableHead>Date</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {games?.map((game) => (
              <TableRow key={game.id} className="hover:bg-muted/40">
                <TableCell>
                  <Link
                    href={`/games/${game.id}`}
                    className="font-medium hover:underline"
                  >
                    {game.game_type}
                  </Link>
                </TableCell>
                <TableCell>
                  <Link
                    href={`/users/${game.creator_id}`}
                    className="text-sm text-muted-foreground hover:underline"
                  >
                    {game.creator_username}
                  </Link>
                </TableCell>
                <TableCell className="text-right">{game.player_count}</TableCell>
                <TableCell className="text-right">
                  {Number(game.total_buyins).toLocaleString()} ₸
                </TableCell>
                <TableCell>
                  <div className="flex gap-1.5">
                    {game.is_public && (
                      <Badge variant="secondary" className="text-xs">
                        Public
                      </Badge>
                    )}
                    {game.soft_deleted && (
                      <Badge variant="destructive" className="text-xs">
                        Deleted
                      </Badge>
                    )}
                  </div>
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {game.timestamp
                    ? format(new Date(game.timestamp), "MMM d, yyyy")
                    : "—"}
                </TableCell>
              </TableRow>
            ))}
            {(!games || games.length === 0) && (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="text-center py-12 text-muted-foreground"
                >
                  No games found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
