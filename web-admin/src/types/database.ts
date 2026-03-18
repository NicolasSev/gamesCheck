export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: Profile;
        Insert: Partial<Profile>;
        Update: Partial<Profile>;
      };
      games: {
        Row: Game;
        Insert: Partial<Game>;
        Update: Partial<Game>;
      };
      game_players: {
        Row: GamePlayer;
        Insert: Partial<GamePlayer>;
        Update: Partial<GamePlayer>;
      };
      player_aliases: {
        Row: PlayerAlias;
        Insert: Partial<PlayerAlias>;
        Update: Partial<PlayerAlias>;
      };
      player_claims: {
        Row: PlayerClaim;
        Insert: Partial<PlayerClaim>;
        Update: Partial<PlayerClaim>;
      };
      billiard_batches: {
        Row: BilliardBatch;
        Insert: Partial<BilliardBatch>;
        Update: Partial<BilliardBatch>;
      };
      device_tokens: {
        Row: DeviceToken;
        Insert: Partial<DeviceToken>;
        Update: Partial<DeviceToken>;
      };
    };
    Views: {
      game_summaries: {
        Row: GameSummary;
      };
      user_statistics: {
        Row: UserStatistics;
      };
      admin_users_overview: {
        Row: AdminUserOverview;
      };
      admin_games_overview: {
        Row: AdminGameOverview;
      };
      admin_claims_overview: {
        Row: AdminClaimOverview;
      };
    };
    Functions: {
      get_game_checksums: {
        Args: { p_user_id: string };
        Returns: { game_id: string; checksum: string }[];
      };
      delete_user_account: {
        Args: { p_user_id: string };
        Returns: void;
      };
      check_game_balance: {
        Args: { p_game_id: string };
        Returns: {
          is_balanced: boolean;
          total_buyins: number;
          total_cashouts: number;
          diff: number;
        }[];
      };
      admin_dashboard_stats: {
        Args: Record<string, never>;
        Returns: AdminDashboardStats[];
      };
      games_by_day: {
        Args: { days_back?: number };
        Returns: { day: string; count: number }[];
      };
      registrations_by_day: {
        Args: { days_back?: number };
        Returns: { day: string; count: number }[];
      };
    };
  };
}

export interface Profile {
  id: string;
  username: string;
  display_name: string | null;
  is_anonymous: boolean;
  is_public: boolean;
  is_super_admin: boolean;
  subscription_status: string;
  subscription_expires_at: string | null;
  total_games_played: number;
  total_buyins: number;
  total_cashouts: number;
  created_at: string;
  last_login_at: string | null;
  updated_at: string | null;
}

export interface Game {
  id: string;
  game_type: string;
  creator_id: string;
  is_public: boolean;
  soft_deleted: boolean;
  notes: string | null;
  timestamp: string;
  created_at: string | null;
  updated_at: string | null;
}

export interface GamePlayer {
  id: string;
  game_id: string;
  profile_id: string | null;
  player_name: string;
  buyin: number;
  cashout: number;
  created_at: string | null;
}

export interface PlayerAlias {
  id: string;
  profile_id: string;
  alias_name: string;
  claimed_at: string | null;
  games_count: number;
}

export interface PlayerClaim {
  id: string;
  player_name: string;
  game_id: string;
  game_player_id: string | null;
  claimant_id: string;
  host_id: string;
  status: "pending" | "approved" | "rejected";
  resolved_at: string | null;
  resolved_by_id: string | null;
  notes: string | null;
  created_at: string;
}

export interface BilliardBatch {
  id: string;
  game_id: string;
  score_player1: number;
  score_player2: number;
  timestamp: string | null;
}

export interface DeviceToken {
  id: string;
  user_id: string;
  token: string;
  platform: string;
  created_at: string | null;
}

export interface GameSummary {
  game_id: string;
  creator_id: string;
  game_type: string;
  timestamp: string;
  total_players: number;
  total_buyins: number;
  is_public: boolean;
  last_modified: string;
  checksum: string;
}

export interface UserStatistics {
  user_id: string;
  total_games_played: number;
  total_buyins: number;
  total_cashouts: number;
  balance: number;
  last_game_date: string | null;
  win_rate: number;
  avg_profit: number;
  last_updated: string;
}

export interface AdminUserOverview {
  id: string;
  username: string;
  display_name: string | null;
  is_public: boolean;
  is_super_admin: boolean;
  subscription_status: string;
  total_games_played: number;
  total_buyins: number;
  total_cashouts: number;
  balance: number;
  created_at: string;
  last_login_at: string | null;
}

export interface AdminGameOverview {
  id: string;
  game_type: string;
  creator_username: string;
  creator_id: string;
  is_public: boolean;
  soft_deleted: boolean;
  player_count: number;
  total_buyins: number;
  timestamp: string;
}

export interface AdminClaimOverview {
  id: string;
  player_name: string;
  status: "pending" | "approved" | "rejected";
  claimant_username: string;
  host_username: string;
  claimant_id: string;
  host_id: string;
  game_id: string;
  game_type: string;
  notes: string | null;
  created_at: string;
  resolved_at: string | null;
}

export interface AdminDashboardStats {
  total_users: number;
  active_users_30d: number;
  total_games: number;
  games_this_week: number;
  pending_claims: number;
  total_buyins: number;
  new_users_this_week: number;
}
