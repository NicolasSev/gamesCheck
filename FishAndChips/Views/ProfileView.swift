import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @State private var showingPendingClaims = false
    @State private var showingMyClaims = false
    @State private var showingEditUsername = false
    @State private var showingDebug = false
    @State private var newUsername = ""
    @State private var isUpdatingUsername = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingLogoutConfirm = false
    
    @State private var isSyncRotating = false
    @State private var syncButtonColor: Color = .blue
    @State private var syncErrorText: String? = nil
    
    private let claimService = PlayerClaimService()
    @EnvironmentObject var syncCoordinator: SyncCoordinator
    
    private var pendingClaimsCount: Int {
        guard let userId = authViewModel.currentUserId else { return 0 }
        return claimService.getPendingClaimsForHost(hostUserId: userId).count
    }
    
    private var myClaimsCount: Int {
        guard let userId = authViewModel.currentUserId else { return 0 }
        return claimService.getMyClaims(userId: userId).count
    }
    
    private var isSuperAdmin: Bool {
        #if DEBUG
        if authViewModel.currentUser?.email?.lowercased() == "sevasresident@gmail.com" {
            return true
        }
        #endif
        return authViewModel.currentUser?.isSuperAdmin ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Аватар и имя пользователя
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 80)
                            Text(String(authViewModel.currentUsername.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Text(authViewModel.currentUsername)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    newUsername = authViewModel.currentUsername
                                    showingEditUsername = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let user = authViewModel.currentUser, let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("v\(version) (\(build))")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 8)

                    // Заявки
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Заявки", systemImage: "person.badge.clock")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: { showingMyClaims = true }) {
                            HStack {
                                Text("Мои заявки")
                                    .foregroundColor(.white)
                                Spacer()
                                if myClaimsCount > 0 {
                                    Text("\(myClaimsCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.blue.opacity(0.5)))
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .accessibilityIdentifier("profile_my_claims_button")
                        
                        if pendingClaimsCount > 0 {
                            Divider().background(Color.white.opacity(0.1))
                            
                            Button(action: { showingPendingClaims = true }) {
                                HStack {
                                    Text("Ожидающие заявки")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(pendingClaimsCount)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.orange.opacity(0.6)))
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .accessibilityIdentifier("profile_pending_claims_button")
                        }
                    }
                    .padding()
                    .glassCardStyle(.plain)

                    // Уведомления
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Уведомления", systemImage: "bell.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Toggle("Подписка на новые игры", isOn: Binding(
                            get: { notificationService.isGameSubscriptionEnabled },
                            set: { newValue in
                                Task {
                                    if newValue {
                                        await notificationService.enableGameSubscription()
                                    } else {
                                        await notificationService.disableGameSubscription()
                                    }
                                }
                            }
                        ))
                        .tint(.blue)
                        .foregroundColor(.white)
                        
                        Text("Push при импорте/обновлении игр другими игроками")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        NavigationLink(destination: NotificationsView().environment(\.managedObjectContext, viewContext)) {
                            HStack {
                                Text("История уведомлений")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .accessibilityIdentifier("profile_notifications_history_link")
                    }
                    .padding()
                    .glassCardStyle(.plain)

                    // Безопасность
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Безопасность", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                        Toggle("Биометрия", isOn: Binding(
                            get: { authViewModel.isBiometricEnabled },
                            set: { authViewModel.isBiometricEnabled = $0 }
                        ))
                        .disabled(!authViewModel.canUseBiometric)
                        .tint(.blue)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .glassCardStyle(.plain)
                    
                    // Синхронизация
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Синхронизация", systemImage: "arrow.triangle.2.circlepath")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(syncCoordinator.isSyncing ? .orange : (syncCoordinator.syncError != nil ? .red : .green))
                                    .frame(width: 8, height: 8)
                                Text(syncCoordinator.syncStatusText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        if let error = syncCoordinator.syncError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.8))
                        }
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await performSyncWithVisualFeedback() }
                        }) {
                            HStack {
                                if syncCoordinator.isSyncing {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .rotationEffect(.degrees(isSyncRotating ? 360 : 0))
                                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSyncRotating)
                                    Text("Синхронизация...")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Синхронизировать")
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .disabled(syncCoordinator.isSyncing)
                        .accessibilityIdentifier("profile_sync_button")
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(syncButtonColor.opacity(0.25))
                        )
                        
                        if let errorText = syncErrorText {
                            Text(errorText)
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.9))
                                .transition(.opacity)
                        }
                        
                        if PendingSyncTracker.shared.hasPendingData() {
                            Divider().background(Color.white.opacity(0.1))
                            
                            HStack(spacing: 8) {
                                Circle().fill(.orange).frame(width: 6, height: 6)
                                Text("Есть неотправленные данные")
                                    .font(.caption)
                                    .foregroundColor(.orange.opacity(0.9))
                            }
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task {
                                    do {
                                        try await syncCoordinator.pushPendingData()
                                    } catch {
                                        debugLog("❌ Failed to push pending data: \(error)")
                                    }
                                }
                            }) {
                                HStack {
                                    if syncCoordinator.isSyncing {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                        Text("Отправка...")
                                    } else {
                                        Image(systemName: "icloud.and.arrow.up")
                                        Text("Отправить данные")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .disabled(syncCoordinator.isSyncing)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.orange.opacity(0.25))
                            )
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green.opacity(0.7))
                                Text("Все данные синхронизированы")
                                    .font(.caption)
                                    .foregroundColor(.green.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .glassCardStyle(.plain)

                    // Утилиты (admin/debug) — скрыты от обычных пользователей
                    #if DEBUG
                    adminSection
                    #else
                    if isSuperAdmin {
                        adminSection
                    }
                    #endif
                    
                    // Выйти
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingLogoutConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти")
                        }
                        .font(.headline)
                        .foregroundColor(.red.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassCardStyle(.plain)
                    }
                    .accessibilityIdentifier("profile_logout_button")
                }
                .padding(.horizontal, 16)
                .padding(.vertical)
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(.white)
                        .accessibilityIdentifier("profile_button")
                }
            }
            .sheet(isPresented: $showingPendingClaims) {
                PendingClaimsView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .sheet(isPresented: $showingMyClaims) {
                MyClaimsView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .sheet(isPresented: $showingDebug) {
                DebugView()
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .alert("Изменить имя пользователя", isPresented: $showingEditUsername) {
                TextField("Новое имя", text: $newUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("profile_username_field")
                
                Button("Отмена", role: .cancel) { newUsername = "" }
                
                Button("Сохранить") { updateUsername() }
                    .disabled(newUsername.isEmpty || newUsername == authViewModel.currentUsername || isUpdatingUsername)
            } message: {
                Text("Введите новое имя пользователя")
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Выйти из аккаунта?", isPresented: $showingLogoutConfirm, titleVisibility: .visible) {
                Button("Выйти", role: .destructive) {
                    authViewModel.logout()
                    dismiss()
                }
                Button("Отмена", role: .cancel) { }
            }
        }
    }
    
    @ViewBuilder
    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Инструменты", systemImage: "wrench.and.screwdriver")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                Task {
                    do {
                        try await SyncCoordinator.shared.cleanupInvalidClaims()
                    } catch {
                        debugLog("❌ Cleanup failed: \(error)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "trash.circle")
                    Text("Очистить невалидные заявки")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
            )
            
            Divider().background(Color.white.opacity(0.1))
            
            Button(action: { showingDebug = true }) {
                HStack {
                    Image(systemName: "ladybug")
                    Text("Debug")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier("profile_debug_button")
        }
        .padding()
        .glassCardStyle(.plain)
    }
    
    private func performSyncWithVisualFeedback() async {
        syncErrorText = nil
        
        withAnimation {
            syncButtonColor = .yellow
            isSyncRotating = true
        }
        
        do {
            try await syncCoordinator.performFullSync()
            
            withAnimation {
                syncButtonColor = .green
                isSyncRotating = false
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { syncButtonColor = .blue }
            
        } catch {
            withAnimation {
                syncButtonColor = .red
                isSyncRotating = false
                syncErrorText = error.localizedDescription
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            
            debugLog("❌ [SYNC] Error: \(error.localizedDescription)")
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                syncButtonColor = .blue
                syncErrorText = nil
            }
        }
    }
    
    private func updateUsername() {
        guard !newUsername.isEmpty, newUsername != authViewModel.currentUsername else { return }
        
        isUpdatingUsername = true
        Task {
            do {
                try await authViewModel.updateUsername(newUsername)
                isUpdatingUsername = false
                newUsername = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch let error as AuthenticationError {
                isUpdatingUsername = false
                switch error {
                case .userAlreadyExists:
                    errorMessage = "Это имя пользователя уже занято"
                case .invalidCredentials:
                    errorMessage = "Имя пользователя не может быть пустым"
                default:
                    errorMessage = "Не удалось изменить имя пользователя"
                }
                showingError = true
            } catch {
                isUpdatingUsername = false
                errorMessage = "Неизвестная ошибка"
                showingError = true
            }
        }
    }
}
