import { createAdminClient } from "@/lib/supabase/server";
import { notFound } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
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
import Link from "next/link";
import { GameActions } from "./game-actions";

export const dynamic = "force-dynamic";

export default async function GameDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createAdminClient();

  const [gameRes, playersRes, balanceRes, batchesRes, claimsRes] =
    await Promise.all([
      supabase.from("admin_games_overview").select("*").eq("id", id).single(),
      supabase
        .from("game_players")
        .select("*, profiles(username)")
        .eq("game_id", id)
        .order("buyin", { ascending: false }),
      supabase.rpc("check_game_balance", { p_game_id: id }),
      supabase
        .from("billiard_batches")
        .select("*")
        .eq("game_id", id)
        .order("timestamp", { ascending: true }),
      supabase
        .from("admin_claims_overview")
        .select("*")
        .eq("game_id", id)
        .order("created_at", { ascending: false }),
    ]);

  if (!gameRes.data) notFound();
  const game = gameRes.data;
  const players = playersRes.data ?? [];
  const balance = balanceRes.data?.[0];
  const batches = batchesRes.data ?? [];
  const claims = claimsRes.data ?? [];

  return (
    <div className="space-y-6 max-w-4xl">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold">{game.game_type} Game</h1>
            {game.is_public && (
              <Badge variant="secondary">Public</Badge>
            )}
            {game.soft_deleted && (
              <Badge variant="destructive">Deleted</Badge>
            )}
          </div>
          <p className="text-muted-foreground text-sm mt-1">
            Created by{" "}
            <Link
              href={`/users/${game.creator_id}`}
              className="text-primary hover:underline"
            >
              {game.creator_username}
            </Link>{" "}
            ·{" "}
            {game.timestamp
              ? format(new Date(game.timestamp), "MMMM d, yyyy")
              : "—"}
          </p>
          <p className="text-xs text-muted-foreground mt-0.5">{id}</p>
        </div>
        <GameActions gameId={id} softDeleted={Boolean(game.soft_deleted)} />
      </div>

      {/* Balance */}
      {balance && (
        <Card
          className={`border-2 ${
            balance.is_balanced ? "border-green-500/30" : "border-red-500/30"
          }`}
        >
          <CardContent className="p-4 flex items-center gap-6">
            <div>
              <p className="text-xs text-muted-foreground">Balance Status</p>
              <p
                className={`text-lg font-bold ${
                  balance.is_balanced ? "text-green-500" : "text-red-500"
                }`}
              >
                {balance.is_balanced ? "Balanced ✓" : "Unbalanced ✗"}
              </p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Total Buyins</p>
              <p className="font-semibold">
                {Number(balance.total_buyins).toLocaleString()} ₸
              </p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Total Cashouts</p>
              <p className="font-semibold">
                {Number(balance.total_cashouts).toLocaleString()} ₸
              </p>
            </div>
            {!balance.is_balanced && (
              <div>
                <p className="text-xs text-muted-foreground">Diff</p>
                <p className="font-semibold text-red-500">
                  {Number(balance.diff) >= 0 ? "+" : ""}
                  {Number(balance.diff).toLocaleString()} ₸
                </p>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* Players */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm">
            Players ({players.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Linked Profile</TableHead>
                <TableHead className="text-right">Buyin</TableHead>
                <TableHead className="text-right">Cashout</TableHead>
                <TableHead className="text-right">Profit</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {players.map((p) => {
                const profit = Number(p.cashout) - Number(p.buyin);
                const profileData = p.profiles as
                  | { username: string }
                  | null;
                return (
                  <TableRow key={p.id}>
                    <TableCell className="font-medium">
                      {p.player_name}
                    </TableCell>
                    <TableCell>
                      {profileData ? (
                        <Link
                          href={`/users/${p.profile_id}`}
                          className="text-sm text-primary hover:underline"
                        >
                          {profileData.username}
                        </Link>
                      ) : (
                        <span className="text-xs text-muted-foreground">
                          Unlinked
                        </span>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      {Number(p.buyin).toLocaleString()} ₸
                    </TableCell>
                    <TableCell className="text-right">
                      {Number(p.cashout).toLocaleString()} ₸
                    </TableCell>
                    <TableCell className="text-right">
                      <span
                        className={
                          profit >= 0 ? "text-green-500" : "text-red-500"
                        }
                      >
                        {profit >= 0 ? "+" : ""}
                        {profit.toLocaleString()} ₸
                      </span>
                    </TableCell>
                  </TableRow>
                );
              })}
              {players.length === 0 && (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="text-center py-8 text-muted-foreground"
                  >
                    No players
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Billiard Batches */}
      {batches.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">
              Billiard Batches ({batches.length})
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>#</TableHead>
                  <TableHead className="text-right">Player 1</TableHead>
                  <TableHead className="text-right">Player 2</TableHead>
                  <TableHead>Time</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {batches.map((batch, idx) => (
                  <TableRow key={batch.id}>
                    <TableCell>{idx + 1}</TableCell>
                    <TableCell className="text-right font-semibold">
                      {batch.score_player1}
                    </TableCell>
                    <TableCell className="text-right font-semibold">
                      {batch.score_player2}
                    </TableCell>
                    <TableCell className="text-muted-foreground text-sm">
                      {batch.timestamp
                        ? format(new Date(batch.timestamp), "HH:mm")
                        : "—"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {/* Claims */}
      {claims.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">
              Claims ({claims.length})
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
                      {claim.claimant_username} → {claim.host_username}
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
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
