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
import { ClaimActions } from "./claim-actions";

export const dynamic = "force-dynamic";

export default async function ClaimsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const params = await searchParams;
  const activeStatus = params.status ?? "pending";
  const supabase = await createAdminClient();

  let query = supabase
    .from("admin_claims_overview")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(100);

  if (activeStatus !== "all") {
    query = query.eq("status", activeStatus);
  }

  const { data: claims } = await query;

  const statusBadge = (status: string) => {
    if (status === "approved")
      return (
        <Badge className="text-xs bg-green-600 hover:bg-green-700">
          Approved
        </Badge>
      );
    if (status === "rejected")
      return <Badge variant="destructive" className="text-xs">Rejected</Badge>;
    return (
      <Badge variant="secondary" className="text-xs">
        Pending
      </Badge>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Claims</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {claims?.length ?? 0} claims
        </p>
      </div>

      {/* Tabs */}
      <div className="flex gap-2">
        {(["pending", "approved", "rejected", "all"] as const).map((s) => (
          <Link
            key={s}
            href={`/claims?status=${s}`}
            className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors capitalize ${
              activeStatus === s
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:text-foreground"
            }`}
          >
            {s}
          </Link>
        ))}
      </div>

      <div className="rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Player Name</TableHead>
              <TableHead>Claimant</TableHead>
              <TableHead>Host</TableHead>
              <TableHead>Game</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Date</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {claims?.map((claim) => (
              <TableRow key={claim.id} className="hover:bg-muted/40">
                <TableCell className="font-medium">
                  {claim.player_name}
                </TableCell>
                <TableCell>
                  <Link
                    href={`/users/${claim.claimant_id}`}
                    className="text-sm hover:underline"
                  >
                    {claim.claimant_username}
                  </Link>
                </TableCell>
                <TableCell>
                  <Link
                    href={`/users/${claim.host_id}`}
                    className="text-sm hover:underline"
                  >
                    {claim.host_username}
                  </Link>
                </TableCell>
                <TableCell>
                  <Link
                    href={`/games/${claim.game_id}`}
                    className="text-sm text-muted-foreground hover:underline"
                  >
                    {claim.game_type}
                  </Link>
                </TableCell>
                <TableCell>{statusBadge(claim.status)}</TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {claim.created_at
                    ? format(new Date(claim.created_at), "MMM d, yyyy")
                    : "—"}
                </TableCell>
                <TableCell>
                  <ClaimActions claimId={claim.id} status={claim.status} />
                </TableCell>
              </TableRow>
            ))}
            {(!claims || claims.length === 0) && (
              <TableRow>
                <TableCell
                  colSpan={7}
                  className="text-center py-12 text-muted-foreground"
                >
                  No claims found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
