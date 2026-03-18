import { createAdminClient } from "@/lib/supabase/server";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { format } from "date-fns";
import { Search } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; filter?: string }>;
}) {
  const params = await searchParams;
  const q = params.q ?? "";
  const filter = params.filter ?? "all";
  const supabase = await createAdminClient();

  let query = supabase
    .from("admin_users_overview")
    .select("*")
    .order("created_at", { ascending: false });

  if (q) {
    query = query.or(`username.ilike.%${q}%`);
  }
  if (filter === "admin") {
    query = query.eq("is_super_admin", true);
  } else if (filter === "premium") {
    query = query.eq("subscription_status", "premium");
  }

  const { data: users } = await query.limit(100);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Users</h1>
          <p className="text-muted-foreground text-sm mt-1">
            {users?.length ?? 0} users found
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3">
        <form className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            name="q"
            defaultValue={q}
            placeholder="Search by username…"
            className="pl-9"
          />
        </form>
        <div className="flex gap-2">
          {(["all", "admin", "premium"] as const).map((f) => (
            <Link
              key={f}
              href={`/users?filter=${f}${q ? `&q=${q}` : ""}`}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                filter === f
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </Link>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Username</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Subscription</TableHead>
              <TableHead className="text-right">Games</TableHead>
              <TableHead className="text-right">Balance</TableHead>
              <TableHead>Joined</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {users?.map((user) => (
              <TableRow key={user.id} className="hover:bg-muted/40">
                <TableCell>
                  <Link
                    href={`/users/${user.id}`}
                    className="font-medium hover:underline"
                  >
                    {user.username}
                  </Link>
                  {user.display_name && user.display_name !== user.username && (
                    <p className="text-xs text-muted-foreground">
                      {user.display_name}
                    </p>
                  )}
                </TableCell>
                <TableCell>
                  <div className="flex gap-1.5 flex-wrap">
                    {user.is_super_admin && (
                      <Badge variant="default" className="text-xs">
                        Admin
                      </Badge>
                    )}
                    {!user.is_public && (
                      <Badge variant="outline" className="text-xs">
                        Private
                      </Badge>
                    )}
                  </div>
                </TableCell>
                <TableCell>
                  <Badge
                    variant={
                      user.subscription_status === "premium"
                        ? "default"
                        : "secondary"
                    }
                    className="text-xs capitalize"
                  >
                    {user.subscription_status}
                  </Badge>
                </TableCell>
                <TableCell className="text-right">
                  {user.total_games_played}
                </TableCell>
                <TableCell className="text-right">
                  <span
                    className={
                      Number(user.balance) >= 0
                        ? "text-green-500"
                        : "text-red-500"
                    }
                  >
                    {Number(user.balance) >= 0 ? "+" : ""}
                    {Number(user.balance).toLocaleString()} ₸
                  </span>
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {user.created_at
                    ? format(new Date(user.created_at), "MMM d, yyyy")
                    : "—"}
                </TableCell>
              </TableRow>
            ))}
            {(!users || users.length === 0) && (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="text-center py-12 text-muted-foreground"
                >
                  No users found
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
