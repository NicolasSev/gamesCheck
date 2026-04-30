//
//  PlayerClaimService.swift
//  PokerCardRecognizer
//

import Foundation
import CoreData

// MARK: - RPC row

/// Ответ строки функции `host_resolve_claim`.
struct HostResolveResult: Codable, Sendable {
    let status: String?
    let blockReason: String?
    let conflictProfileIds: [UUID]?

    enum CodingKeys: String, CodingKey {
        case status
        case blockReason = "block_reason"
        case conflictProfileIds = "conflict_profile_ids"
    }
}

// MARK: - Errors

enum ClaimError: LocalizedError, Equatable {
    case claimNotFound
    case claimAlreadyResolved
    case unauthorized
    /// После успешного RPC сервер сохранил `blocked`.
    case claimBlocked(reason: String)
    /// Пустой или некорректный список ключей для запроса merge.
    case mergeRequestInvalid

    var errorDescription: String? {
        switch self {
        case .claimNotFound:
            return "Заявка не найдена"
        case .claimAlreadyResolved:
            return "Заявка уже обработана"
        case .unauthorized:
            return "Нет прав для выполнения операции"
        case let .claimBlocked(reason):
            return "Заявка заблокирована: \(reason)"
        case .mergeRequestInvalid:
            return "Укажите хотя бы один ключ имени для запроса админу"
        }
    }

    static func == (lhs: ClaimError, rhs: ClaimError) -> Bool {
        switch (lhs, rhs) {
        case (.claimNotFound, .claimNotFound),
             (.claimAlreadyResolved, .claimAlreadyResolved),
             (.unauthorized, .unauthorized):
            return true
        case let (.claimBlocked(a), .claimBlocked(b)):
            return a == b
        case (.mergeRequestInvalid, .mergeRequestInvalid):
            return true
        default:
            return false
        }
    }
}

// MARK: - Service

class PlayerClaimService {
    typealias HostResolveRpc = @Sendable (
        _ claimId: UUID,
        _ action: String,
        _ notes: String?
    ) async throws -> [HostResolveResult]

    typealias AfterClaimMutationSync = @Sendable () async throws -> Void

    private let persistence: PersistenceController
    private let notificationService: NotificationService
    private let hostResolveRpc: HostResolveRpc
    private let afterClaimMutationSync: AfterClaimMutationSync

    init(
        persistence: PersistenceController = .shared,
        notificationService: NotificationService = .shared,
        hostResolveRpc: HostResolveRpc? = nil,
        afterClaimMutationSync: AfterClaimMutationSync? = nil
    ) {
        self.persistence = persistence
        self.notificationService = notificationService
        self.hostResolveRpc = hostResolveRpc ?? Self.liveHostResolveRpc
        self.afterClaimMutationSync =
            afterClaimMutationSync ?? Self.liveAfterClaimMutation
    }

    private static func liveHostResolveRpc(
        claimId: UUID,
        action: String,
        notes: String?
    ) async throws -> [HostResolveResult] {
        struct Params: Codable, Sendable {
            let p_claim_id: UUID
            let p_action: String
            let p_notes: String?
        }
        let trimmed = notes.flatMap(trimNotes)
        return try await SupabaseService.shared.rpc(
            "host_resolve_claim",
            params: Params(p_claim_id: claimId, p_action: action, p_notes: trimmed)
        )
    }

    private static func trimNotes(_ notes: String) -> String? {
        let t = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func liveAfterClaimMutation() async throws {
        try await SyncCoordinator.shared.fullResyncAfterClaim()
    }

    // MARK: - Queries

    func getMyClaims(userId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimantUserId == %@", userId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "status", ascending: true),
            NSSortDescriptor(keyPath: \PlayerClaim.createdAt, ascending: false),
        ]

        do {
            let allClaims = try context.fetch(request)
            let pending = allClaims.filter { $0.status == "pending" }
            let resolved = allClaims.filter { $0.status != "pending" }
                .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }
            return pending + resolved
        } catch {
            debugLog("Error fetching my claims: \(error)")
            return []
        }
    }

    func getPendingClaimsForHost(hostUserId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "hostUserId == %@ AND status == %@", hostUserId as CVarArg, "pending")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PlayerClaim.createdAt, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            debugLog("Error fetching pending claims: \(error)")
            return []
        }
    }

    func getAllClaimsForHost(hostUserId: UUID) -> [PlayerClaim] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "hostUserId == %@", hostUserId as CVarArg)

        do {
            let allClaims = try context.fetch(request)
            let pending = allClaims.filter { $0.status == "pending" }
                .sorted { $0.createdAt > $1.createdAt }
            let blocked = allClaims.filter { $0.status == "blocked" }
                .sorted { $0.createdAt > $1.createdAt }
            let finalized = allClaims.filter {
                $0.status == "approved" || $0.status == "rejected"
            }
                .sorted { ($0.resolvedAt ?? $0.createdAt) > ($1.resolvedAt ?? $1.createdAt) }

            return pending + blocked + finalized
        } catch {
            debugLog("Error fetching all claims for host: \(error)")
            return []
        }
    }

    func getClaim(byId claimId: UUID) -> PlayerClaim? {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<PlayerClaim> = PlayerClaim.fetchRequest()
        request.predicate = NSPredicate(format: "claimId == %@", claimId as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            debugLog("Error fetching claim: \(error)")
            return nil
        }
    }

    // MARK: - Approve / Reject

    func approveClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) async throws {
        guard let claim = getClaim(byId: claimId) else {
            throw ClaimError.claimNotFound
        }
        guard claim.hostUserId == resolverUserId else {
            throw ClaimError.unauthorized
        }
        guard claim.status == "pending" || claim.status == "blocked" else {
            throw ClaimError.claimAlreadyResolved
        }

        do {
            let rows = try await hostResolveRpc(claimId, "approve", notes)
            guard let row = rows.first else { throw ClaimError.claimNotFound }

            try await afterClaimMutationSync()

            if row.status == "blocked" {
                throw ClaimError.claimBlocked(reason: row.blockReason ?? "conflict")
            }

            notifyClaimApproved(snapshot: claim)
        } catch let e as ClaimError {
            throw e
        } catch {
            PendingSyncTracker.shared.addPendingPlayerClaim(claimId)
            debugLog("[approveClaim] RPC/sync: \(error)")
            throw error
        }
    }

    func rejectClaim(
        claimId: UUID,
        resolverUserId: UUID,
        notes: String? = nil
    ) async throws {
        guard let claim = getClaim(byId: claimId) else {
            throw ClaimError.claimNotFound
        }
        guard claim.hostUserId == resolverUserId else {
            throw ClaimError.unauthorized
        }
        guard claim.status == "pending" || claim.status == "blocked" else {
            throw ClaimError.claimAlreadyResolved
        }

        do {
            _ = try await hostResolveRpc(claimId, "reject", notes)
            try await afterClaimMutationSync()
            notifyClaimRejected(snapshot: claim, notes: notes)
        } catch let e as ClaimError {
            throw e
        } catch {
            PendingSyncTracker.shared.addPendingPlayerClaim(claimId)
            debugLog("[rejectClaim] RPC/sync: \(error)")
            throw error
        }
    }

    // MARK: - Admin merge requests (blocked → host asks super-admin)

    private struct ProfileUsernamePick: Codable, Sendable {
        let id: UUID
        let username: String
    }

    private struct AdminMergeRequestInsert: Codable, Sendable {
        let requester_id: UUID
        let blocked_claim_id: UUID
        let source_keys: [String]
        let suggested_canonical: String?
        let notes: String?
    }

    private static func normalizeMergeKeyLocal(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Usernames конфликтующих профилей (из `conflict_profile_ids`).
    func conflictProfileDisplayNames(for profileIds: [UUID]) async throws -> [String] {
        guard !profileIds.isEmpty else { return [] }
        let rows: [ProfileUsernamePick] =
            try await SupabaseService.shared.fetchByFilter(table: "profiles") { query in
                query.in("id", values: profileIds.map(\.uuidString))
            }
        let map = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.username) })
        return profileIds.compactMap { map[$0] }.filter { !$0.isEmpty }
    }

    func submitAdminMergeRequest(
        blockedClaimId: UUID,
        sourceKeys: [String],
        suggestedCanonical: String?,
        notes: String?
    ) async throws {
        guard let uid = await SupabaseService.shared.currentUserId() else {
            throw ClaimError.unauthorized
        }
        let keys = Array(Set(sourceKeys.map { Self.normalizeMergeKeyLocal($0) }.filter { !$0.isEmpty }))
        guard !keys.isEmpty else { throw ClaimError.mergeRequestInvalid }
        let canon = suggestedCanonical?.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonField: String? = (canon?.isEmpty == false) ? canon : nil
        let noteField = notes.flatMap(Self.trimNotes)

        let insert = AdminMergeRequestInsert(
            requester_id: uid,
            blocked_claim_id: blockedClaimId,
            source_keys: keys,
            suggested_canonical: canonField,
            notes: noteField,
        )

        _ = try await SupabaseService.shared.insert(
            table: "admin_merge_requests",
            values: insert,
        )
    }

    private func notifyClaimApproved(snapshot: PlayerClaim) {
        let ts = snapshot.game?.timestamp ?? snapshot.createdAt
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimApproved(
                    claimId: snapshot.claimId.uuidString,
                    playerName: snapshot.playerName,
                    gameName: "игра от \(ts.formatted(date: .abbreviated, time: .omitted))",
                    claimantUserId: snapshot.claimantUserId.uuidString
                )
            } catch {
                debugLog("Failed to notify claim approved: \(error)")
            }
        }
    }

    private func notifyClaimRejected(snapshot: PlayerClaim, notes: String?) {
        Task { @MainActor in
            do {
                try await notificationService.notifyClaimRejected(
                    claimId: snapshot.claimId.uuidString,
                    playerName: snapshot.playerName,
                    gameName:
                        "игра от \(snapshot.game?.timestamp?.formatted(date: .abbreviated, time: .omitted) ?? "")",
                    reason: notes,
                    claimantUserId: snapshot.claimantUserId.uuidString
                )
            } catch {
                debugLog("Failed to notify claim rejected: \(error)")
            }
        }
    }
}
