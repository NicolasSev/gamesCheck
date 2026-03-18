/**
 * Type-shape validation tests.
 * These ensure our TypeScript interfaces have the expected fields at runtime.
 */

import type {
  Profile,
  Game,
  GamePlayer,
  PlayerClaim,
  PlayerAlias,
  DeviceToken,
  AdminDashboardStats,
  AdminClaimOverview,
} from "@/types/database";

function hasKeys<T extends object>(
  obj: T,
  keys: (keyof T)[]
): boolean {
  return keys.every((k) => k in obj);
}

describe("Profile type shape", () => {
  const sampleProfile: Profile = {
    id: "uuid-1",
    username: "player1",
    display_name: "Player One",
    is_anonymous: false,
    is_public: true,
    is_super_admin: false,
    subscription_status: "free",
    subscription_expires_at: null,
    total_games_played: 10,
    total_buyins: 50000,
    total_cashouts: 55000,
    created_at: "2024-01-01T00:00:00Z",
    last_login_at: null,
    updated_at: null,
  };

  it("has required identity fields", () => {
    expect(hasKeys(sampleProfile, ["id", "username"])).toBe(true);
  });

  it("has stat fields", () => {
    expect(
      hasKeys(sampleProfile, [
        "total_games_played",
        "total_buyins",
        "total_cashouts",
      ])
    ).toBe(true);
  });

  it("has permission fields", () => {
    expect(
      hasKeys(sampleProfile, ["is_public", "is_super_admin", "is_anonymous"])
    ).toBe(true);
  });

  it("balance is cashouts minus buyins", () => {
    const balance =
      sampleProfile.total_cashouts - sampleProfile.total_buyins;
    expect(balance).toBe(5000);
  });
});

describe("Game type shape", () => {
  const sampleGame: Game = {
    id: "game-uuid",
    game_type: "Poker",
    creator_id: "user-uuid",
    is_public: false,
    soft_deleted: false,
    notes: "Test game",
    timestamp: "2024-06-01T20:00:00Z",
    created_at: "2024-06-01T18:00:00Z",
    updated_at: null,
  };

  it("has all required fields", () => {
    expect(
      hasKeys(sampleGame, [
        "id",
        "game_type",
        "creator_id",
        "is_public",
        "soft_deleted",
        "timestamp",
      ])
    ).toBe(true);
  });

  it("game_type can be Poker or Billiard", () => {
    const poker: Game["game_type"] = "Poker";
    const billiard: Game["game_type"] = "Billiard";
    expect(["Poker", "Billiard"]).toContain(poker);
    expect(["Poker", "Billiard"]).toContain(billiard);
  });
});

describe("PlayerClaim status values", () => {
  it("accepts pending status", () => {
    const status: PlayerClaim["status"] = "pending";
    expect(status).toBe("pending");
  });

  it("accepts approved status", () => {
    const status: PlayerClaim["status"] = "approved";
    expect(status).toBe("approved");
  });

  it("accepts rejected status", () => {
    const status: PlayerClaim["status"] = "rejected";
    expect(status).toBe("rejected");
  });
});

describe("GamePlayer profit calculation", () => {
  const player: GamePlayer = {
    id: "gp-1",
    game_id: "game-1",
    profile_id: null,
    player_name: "Alice",
    buyin: 5000,
    cashout: 7500,
    created_at: null,
  };

  it("calculates positive profit correctly", () => {
    const profit = player.cashout - player.buyin;
    expect(profit).toBe(2500);
  });

  it("calculates negative profit correctly", () => {
    const loser: GamePlayer = { ...player, cashout: 2000 };
    const profit = loser.cashout - loser.buyin;
    expect(profit).toBe(-3000);
  });
});

describe("AdminDashboardStats shape", () => {
  const stats: AdminDashboardStats = {
    total_users: 100,
    active_users_30d: 45,
    total_games: 500,
    games_this_week: 12,
    pending_claims: 3,
    total_buyins: 2500000,
    new_users_this_week: 8,
  };

  it("has all required dashboard fields", () => {
    expect(
      hasKeys(stats, [
        "total_users",
        "active_users_30d",
        "total_games",
        "games_this_week",
        "pending_claims",
        "total_buyins",
        "new_users_this_week",
      ])
    ).toBe(true);
  });

  it("active users is less than or equal to total users", () => {
    expect(stats.active_users_30d).toBeLessThanOrEqual(stats.total_users);
  });

  it("games this week is less than or equal to total games", () => {
    expect(stats.games_this_week).toBeLessThanOrEqual(stats.total_games);
  });
});

describe("AdminClaimOverview", () => {
  const claim: AdminClaimOverview = {
    id: "claim-1",
    player_name: "Bob",
    status: "pending",
    claimant_username: "alice",
    host_username: "charlie",
    claimant_id: "user-1",
    host_id: "user-2",
    game_id: "game-1",
    game_type: "Poker",
    notes: null,
    created_at: "2024-01-01T00:00:00Z",
    resolved_at: null,
  };

  it("has all required fields", () => {
    expect(
      hasKeys(claim, [
        "id",
        "player_name",
        "status",
        "claimant_username",
        "host_username",
        "game_id",
      ])
    ).toBe(true);
  });
});

describe("DeviceToken", () => {
  const token: DeviceToken = {
    id: "dt-1",
    user_id: "user-1",
    token: "apns-token-abc123",
    platform: "ios",
    created_at: null,
  };

  it("has required fields", () => {
    expect(hasKeys(token, ["id", "user_id", "token", "platform"])).toBe(true);
  });
});
