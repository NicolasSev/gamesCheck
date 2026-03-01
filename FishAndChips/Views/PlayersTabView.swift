//
//  PlayersTabView.swift
//  FishAndChips
//

import SwiftUI
import CoreData

struct PlayersTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedProfileWrapper: PlayerProfileWrapper?

    private var isSuperAdmin: Bool {
        #if DEBUG
        if authViewModel.currentUser?.email?.lowercased() == "sevasresident@gmail.com" { return true }
        #endif
        return authViewModel.currentUser?.isSuperAdmin ?? false
    }

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlayerProfile.displayName, ascending: true)],
        animation: .default
    )
    private var allProfiles: FetchedResults<PlayerProfile>

    private var displayedProfiles: [PlayerProfile] {
        let profiles = isSuperAdmin ? Array(allProfiles) : allProfiles.filter { $0.isPublic }
        guard !searchText.isEmpty else { return profiles }
        let q = searchText.lowercased()
        return profiles.filter { $0.displayName.lowercased().contains(q) }
    }

    var body: some View {
        List {
            if displayedProfiles.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Нет игроков" : "Ничего не найдено",
                    systemImage: "person.2.slash",
                    description: Text(isSuperAdmin ? "Зарегистрированные игроки появятся здесь" : "Публичные профили появятся, когда игроки сделают профиль видимым")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(displayedProfiles, id: \.profileId) { profile in
                    Button {
                        selectedProfileWrapper = PlayerProfileWrapper(profile: profile)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if isSuperAdmin, !profile.isPublic {
                                    Text("Приватный")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Поиск игрока")
        .navigationTitle("Игроки")
        .task {
            try? await CloudKitSyncService.shared.fetchPlayerProfiles()
        }
        .sheet(item: $selectedProfileWrapper) { wrapper in
            PlayerPublicProfileView(profile: wrapper.profile, isSuperAdmin: isSuperAdmin)
                .environment(\.managedObjectContext, viewContext)
        }
    }
}

struct SuperAdminProfileInfo: View {
    let profile: PlayerProfile
    private let persistence = PersistenceController.shared
    private let claimService = PlayerClaimService()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let userId = profile.userId {
                Text("UserID: \(userId.uuidString)")
                    .font(.caption2)
                if let user = persistence.fetchUser(byId: userId) {
                    Text("Email: \(user.email ?? "—")")
                        .font(.caption2)
                    Text("SuperAdmin: \(user.isSuperAdmin ? "Да" : "Нет")")
                        .font(.caption2)
                }
            }
            Text("Публичный: \(profile.isPublic ? "Да" : "Нет")")
                .font(.caption2)
            if let userId = profile.userId {
                let myClaims = claimService.getMyClaims(userId: userId)
                let pending = myClaims.filter { $0.isPending }
                Text("Заявок: \(myClaims.count), ожидает: \(pending.count)")
                    .font(.caption2)
            }
        }
    }
}

struct PlayerProfileWrapper: Identifiable {
    let id: UUID
    let profile: PlayerProfile
    init(profile: PlayerProfile) {
        self.id = profile.profileId
        self.profile = profile
    }
}

struct PlayerPublicProfileView: View {
    let profile: PlayerProfile
    let isSuperAdmin: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var statistics: UserStatistics?
    @State private var games: [Game] = []
    @State private var showSuperAdminInfo = false

    private let gameService = GameService()

    var body: some View {
        NavigationStack {
            OverviewTabView(
                statistics: statistics,
                games: games,
                authViewModel: nil,
                selectedPlayerNameForStats: profile.displayName,
                selectedPlayerNamesForStats: [profile.displayName],
                onRefresh: loadData,
                onPlayerSelected: nil
            )
            .navigationTitle(profile.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                if isSuperAdmin {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSuperAdminInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .popover(isPresented: $showSuperAdminInfo) {
                            SuperAdminProfileInfo(profile: profile)
                                .padding()
                                .frame(minWidth: 250, minHeight: 150)
                        }
                    }
                }
            }
            .onAppear { loadData() }
        }
    }

    private func loadData() {
        let namesSet = Set(profile.allKnownNames.map { $0.lowercased() })
        guard !namesSet.isEmpty else {
            statistics = gameService.emptyStatistics()
            games = []
            return
        }
        statistics = gameService.getUserStatistics(byPlayerNames: namesSet)
        games = gameService.getAllGames().filter { game in
            let participations = game.gameWithPlayers as? Set<GameWithPlayer> ?? []
            return participations.contains { gwp in
                guard let player = gwp.player, let name = player.name else { return false }
                return namesSet.contains(name.lowercased())
            }
        }.sorted { ($0.timestamp ?? Date()) > ($1.timestamp ?? Date()) }
    }
}
