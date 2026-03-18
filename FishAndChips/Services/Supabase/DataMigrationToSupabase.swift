import Foundation
import CoreData

/// Одноразовая миграция данных из Core Data (CloudKit cache) в Supabase
/// Вызывается при первом запуске после переключения на Supabase
final class DataMigrationToSupabase {
    private let persistence: PersistenceController
    private let supabase: SupabaseService
    private let auth: SupabaseAuthService

    private static let migrationKey = "hasMigratedToSupabase"

    static var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    init(
        persistence: PersistenceController = .shared,
        supabase: SupabaseService = .shared,
        auth: SupabaseAuthService = .shared
    ) {
        self.persistence = persistence
        self.supabase = supabase
        self.auth = auth
    }

    // MARK: - Main Migration

    /// Полная миграция: auth -> profile -> games -> game_players -> aliases -> claims
    func migrate(email: String, password: String) async throws -> MigrationResult {
        guard !Self.hasMigrated else {
            return MigrationResult(status: .alreadyMigrated)
        }

        var result = MigrationResult(status: .inProgress)
        let context = persistence.container.viewContext

        // 1. Миграция авторизации
        let userRequest = NSFetchRequest<User>(entityName: "User")
        let users = (try? context.fetch(userRequest)) ?? []
        guard let localUser = users.first else {
            return MigrationResult(status: .failed(error: "Локальный пользователь не найден"))
        }

        let authUser: AuthUser
        do {
            authUser = try await auth.signUp(
                email: email,
                password: password,
                username: localUser.username,
                displayName: localUser.playerProfile?.displayName
            )
            result.usersMigrated = 1
        } catch {
            do {
                authUser = try await auth.signIn(email: email, password: password)
                result.usersMigrated = 1
            } catch {
                return MigrationResult(status: .failed(error: "Ошибка авторизации: \(error.localizedDescription)"))
            }
        }

        // 2. Миграция профиля
        if let profile = localUser.playerProfile {
            var profileDTO = profile.toProfileDTO()
            profileDTO = ProfileDTO(
                id: authUser.id,
                username: profileDTO.username,
                displayName: profileDTO.displayName,
                isAnonymous: profileDTO.isAnonymous,
                isPublic: profileDTO.isPublic,
                isSuperAdmin: localUser.isSuperAdmin,
                subscriptionStatus: localUser.subscriptionStatus,
                subscriptionExpiresAt: localUser.subscriptionExpiresAt,
                totalGamesPlayed: profileDTO.totalGamesPlayed,
                totalBuyins: profileDTO.totalBuyins,
                totalCashouts: profileDTO.totalCashouts,
                createdAt: localUser.createdAt,
                lastLoginAt: Date(),
                updatedAt: nil
            )
            let _: ProfileDTO = try await supabase.upsert(table: "profiles", values: profileDTO)
            result.profilesMigrated = 1
        }

        // 3. Миграция игр
        let gameRequest = NSFetchRequest<Game>(entityName: "Game")
        let games = (try? context.fetch(gameRequest)) ?? []

        for game in games where !game.softDeleted {
            var gameDTO = game.toGameDTO()
            gameDTO = GameDTO(
                id: gameDTO.id,
                gameType: gameDTO.gameType,
                creatorId: authUser.id,
                isPublic: gameDTO.isPublic,
                softDeleted: false,
                notes: gameDTO.notes,
                timestamp: gameDTO.timestamp,
                createdAt: nil,
                updatedAt: nil
            )

            do {
                let _: GameDTO = try await supabase.upsert(table: "games", values: gameDTO)
                result.gamesMigrated += 1

                // 4. Миграция game_players
                let gwps = (game.gameWithPlayers as? Set<GameWithPlayer>) ?? []
                for gwp in gwps {
                    guard var gpDTO = gwp.toGamePlayerDTO() else { continue }
                    if gwp.playerProfile?.userId == localUser.userId {
                        gpDTO = GamePlayerDTO(
                            id: gpDTO.id,
                            gameId: gpDTO.gameId,
                            profileId: authUser.id,
                            playerName: gpDTO.playerName,
                            buyin: gpDTO.buyin,
                            cashout: gpDTO.cashout,
                            createdAt: nil
                        )
                    }
                    let _: GamePlayerDTO = try await supabase.upsert(table: "game_players", values: gpDTO)
                    result.gamePlayersMigrated += 1
                }
            } catch {
                debugLog("Migration: failed to migrate game \(game.gameId): \(error)")
                result.errors.append("Game \(game.gameId): \(error.localizedDescription)")
            }
        }

        // 5. Миграция aliases
        let aliasRequest = NSFetchRequest<PlayerAlias>(entityName: "PlayerAlias")
        let aliases = (try? context.fetch(aliasRequest)) ?? []

        for alias in aliases {
            var aliasDTO = alias.toPlayerAliasDTO()
            if alias.profileId == localUser.playerProfile?.profileId {
                aliasDTO = PlayerAliasDTO(
                    id: aliasDTO.id,
                    profileId: authUser.id,
                    aliasName: aliasDTO.aliasName,
                    claimedAt: aliasDTO.claimedAt,
                    gamesCount: aliasDTO.gamesCount
                )
            }
            do {
                let _: PlayerAliasDTO = try await supabase.upsert(table: "player_aliases", values: aliasDTO)
                result.aliasesMigrated += 1
            } catch {
                debugLog("Migration: failed to migrate alias \(alias.aliasName): \(error)")
                result.errors.append("Alias \(alias.aliasName): \(error.localizedDescription)")
            }
        }

        // 6. Миграция claims
        let claimRequest = NSFetchRequest<PlayerClaim>(entityName: "PlayerClaim")
        let claims = (try? context.fetch(claimRequest)) ?? []

        for claim in claims {
            var claimDTO = claim.toPlayerClaimDTO()
            if claim.claimantUserId == localUser.userId {
                claimDTO = PlayerClaimDTO(
                    id: claimDTO.id,
                    playerName: claimDTO.playerName,
                    gameId: claimDTO.gameId,
                    gamePlayerId: claimDTO.gamePlayerId,
                    claimantId: authUser.id,
                    hostId: claimDTO.hostId,
                    status: claimDTO.status,
                    resolvedAt: claimDTO.resolvedAt,
                    resolvedById: claimDTO.resolvedById,
                    notes: claimDTO.notes,
                    createdAt: claimDTO.createdAt
                )
            }
            if claim.hostUserId == localUser.userId {
                claimDTO = PlayerClaimDTO(
                    id: claimDTO.id,
                    playerName: claimDTO.playerName,
                    gameId: claimDTO.gameId,
                    gamePlayerId: claimDTO.gamePlayerId,
                    claimantId: claimDTO.claimantId,
                    hostId: authUser.id,
                    status: claimDTO.status,
                    resolvedAt: claimDTO.resolvedAt,
                    resolvedById: claimDTO.resolvedById,
                    notes: claimDTO.notes,
                    createdAt: claimDTO.createdAt
                )
            }
            do {
                let _: PlayerClaimDTO = try await supabase.upsert(table: "player_claims", values: claimDTO)
                result.claimsMigrated += 1
            } catch {
                debugLog("Migration: failed to migrate claim \(claim.claimId): \(error)")
                result.errors.append("Claim \(claim.claimId): \(error.localizedDescription)")
            }
        }

        // Mark as migrated
        if result.errors.isEmpty {
            result.status = .completed
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
            BackendSwitch.switchToSupabase()
        } else {
            result.status = .completedWithErrors
        }

        return result
    }
}

// MARK: - Migration Result

struct MigrationResult {
    enum Status {
        case inProgress
        case completed
        case completedWithErrors
        case alreadyMigrated
        case failed(error: String)
    }

    var status: Status
    var usersMigrated: Int = 0
    var profilesMigrated: Int = 0
    var gamesMigrated: Int = 0
    var gamePlayersMigrated: Int = 0
    var aliasesMigrated: Int = 0
    var claimsMigrated: Int = 0
    var errors: [String] = []

    var summary: String {
        """
        Users: \(usersMigrated)
        Profiles: \(profilesMigrated)
        Games: \(gamesMigrated)
        Game Players: \(gamePlayersMigrated)
        Aliases: \(aliasesMigrated)
        Claims: \(claimsMigrated)
        Errors: \(errors.count)
        """
    }
}
