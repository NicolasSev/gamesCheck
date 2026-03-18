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
    
    // Sync button visual states
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

    var body: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: 16) {
                        // Версия и номер сборки
                        VStack(alignment: .leading, spacing: 4) {
                            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                Text("Версия \(version) (\(build))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Пользователь
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Пользователь")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(authViewModel.currentUsername)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    if let user = authViewModel.currentUser, let email = user.email {
                                        Text(email)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    if let id = authViewModel.currentUserId {
                                        Text(id.uuidString)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    newUsername = authViewModel.currentUsername
                                    showingEditUsername = true
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)

                        // Заявки
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Заявки")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Мои заявки
                            Button(action: {
                                showingMyClaims = true
                            }) {
                                HStack {
                                    Text("Мои заявки")
                                        .foregroundColor(.white)
                                    Spacer()
                                    if myClaimsCount > 0 {
                                        Text("\(myClaimsCount)")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            // Ожидающие заявки (для хоста)
                            if pendingClaimsCount > 0 {
                                Button(action: {
                                    showingPendingClaims = true
                                }) {
                                    HStack {
                                        Text("Ожидающие заявки")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(pendingClaimsCount)")
                                            .foregroundColor(.orange)
                                            .fontWeight(.semibold)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)

                        // Подписка на push о новых играх
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Уведомления")
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
                            Text("Получать push при импорте/обновлении игр другими пользователями")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)

                        // Список уведомлений
                        NavigationLink(destination: NotificationsView().environment(\.managedObjectContext, viewContext)) {
                            HStack {
                                Text("История уведомлений")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)
                        
                        // Безопасность
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Безопасность")
                                .font(.headline)
                                .foregroundColor(.white)
                            Toggle("Биометрия", isOn: Binding(
                                get: { authViewModel.isBiometricEnabled },
                                set: { authViewModel.isBiometricEnabled = $0 }
                            ))
                            .disabled(!authViewModel.canUseBiometric)
                            .tint(.blue)
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)
                        
                        // CloudKit Sync
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up.fill")
                                    .foregroundColor(.blue)
                                Text("Синхронизация")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(syncCoordinator.isSyncing ? .orange : (syncCoordinator.syncError != nil ? .red : .green))
                                    Text(syncCoordinator.syncStatusText)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                if let error = syncCoordinator.syncError {
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.leading, 16)
                                }
                            }
                            
                            Button(action: {
                                Task {
                                    await performSyncWithVisualFeedback()
                                }
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
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .disabled(syncCoordinator.isSyncing)
                            .accessibilityIdentifier("profile_sync_button")
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(syncButtonColor.opacity(0.3))
                            )
                            
                            // Показываем ошибку если есть
                            if let errorText = syncErrorText {
                                Text(errorText)
                                    .font(.caption2)
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.top, 4)
                                    .transition(.opacity)
                            }
                            
                            // Pending Data UI
                            if PendingSyncTracker.shared.hasPendingData() {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Незалитые данные:")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(PendingSyncTracker.shared.getPendingSummary())
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                                
                                Button(action: {
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
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                                .scaleEffect(0.8)
                                            Text("Отправка...")
                                        } else {
                                            Image(systemName: "icloud.and.arrow.up")
                                            Text("Запушить незалитые данные")
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .disabled(syncCoordinator.isSyncing)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(syncCoordinator.isSyncing ? Color.gray.opacity(0.3) : Color.orange.opacity(0.3))
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("✓ Нет незалитых данных")
                                        .font(.caption)
                                        .foregroundColor(.green.opacity(0.8))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)

                        // Очистка невалидных заявок
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                Task {
                                    do {
                                        debugLog("🧹 Starting cleanup of invalid claims...")
                                        try await SyncCoordinator.shared.cleanupInvalidClaims()
                                        debugLog("✅ Cleanup completed")
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
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.2))
                            )
                            
                            Text("Удаляет поврежденные заявки из CloudKit")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)
                        
                        // Debug (доступно в TestFlight)
                        Button(action: {
                            showingDebug = true
                        }) {
                            HStack {
                                Image(systemName: "ladybug")
                                Text("Debug")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .liquidGlass(cornerRadius: 15)
                        }
                        .padding(.horizontal)
                        
                        // Выйти
                        Button(action: {
                            authViewModel.logout()
                            dismiss()
                        }) {
                            Text("Выйти")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .liquidGlass(cornerRadius: 15)
                        }
                        .accessibilityIdentifier("profile_logout_button")
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical)
            }
            .casinoBackground()
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
                
                Button("Отмена", role: .cancel) {
                    newUsername = ""
                }
                
                Button("Сохранить") {
                    updateUsername()
                }
                .disabled(newUsername.isEmpty || newUsername == authViewModel.currentUsername || isUpdatingUsername)
            } message: {
                Text("Введите новое имя пользователя")
            }
            .alert("Ошибка", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Обновить счетчики при открытии
            }
        }
    }
    
    private func performSyncWithVisualFeedback() async {
        // Сброс состояний
        syncErrorText = nil
        
        // Начало синхронизации - желтая кнопка + вращение иконки
        withAnimation {
            syncButtonColor = .yellow
            isSyncRotating = true
        }
        
        do {
            try await syncCoordinator.performFullSync()
            
            // Успех - зеленая кнопка на 2 секунды
            withAnimation {
                syncButtonColor = .green
                isSyncRotating = false
            }
            
            // Возврат к синему через 2 секунды
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 сек
            withAnimation {
                syncButtonColor = .blue
            }
            
        } catch {
            // Ошибка - красная кнопка на 2 секунды + текст ошибки
            withAnimation {
                syncButtonColor = .red
                isSyncRotating = false
                syncErrorText = error.localizedDescription
            }
            
            debugLog("❌ [SYNC] Error: \(error.localizedDescription)")
            
            // Возврат к синему через 2 секунды
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 сек
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

