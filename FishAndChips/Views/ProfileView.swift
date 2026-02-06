import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    @State private var showingPendingClaims = false
    @State private var showingMyClaims = false
    @State private var showingEditUsername = false
    @State private var showingDebug = false
    @State private var newUsername = ""
    @State private var isUpdatingUsername = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let claimService = PlayerClaimService()
    @StateObject private var syncService = CloudKitSyncService.shared
    
    private var pendingClaimsCount: Int {
        guard let userId = authViewModel.currentUserId else { return 0 }
        return claimService.getPendingClaimsForHost(hostUserId: userId).count
    }
    
    private var myClaimsCount: Int {
        guard let userId = authViewModel.currentUserId else { return 0 }
        return claimService.getMyClaims(userId: userId).count
    }

    var body: some View {
        NavigationView {
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
                                        .foregroundColor(syncService.isSyncing ? .orange : (syncService.syncError != nil ? .red : .green))
                                    Text(syncService.syncStatusText)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                if let error = syncService.syncError {
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.leading, 16)
                                }
                            }
                            
                            Button(action: {
                                Task {
                                    try? await syncService.performFullSync()
                                }
                            }) {
                                HStack {
                                    if syncService.isSyncing {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                            .scaleEffect(0.8)
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
                            .disabled(syncService.isSyncing)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(syncService.isSyncing ? Color.gray.opacity(0.3) : Color.blue.opacity(0.3))
                            )
                        }
                        .padding()
                        .liquidGlass(cornerRadius: 15)
                        .padding(.horizontal)

                        // Очистка невалидных заявок
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                Task {
                                    do {
                                        print("🧹 Starting cleanup of invalid claims...")
                                        try await CloudKitSyncService.shared.cleanupInvalidClaims()
                                        print("✅ Cleanup completed")
                                    } catch {
                                        print("❌ Cleanup failed: \(error)")
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
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical)
            }
            .background(
                Group {
                    if let image = backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.4),
                                        Color.black.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .ignoresSafeArea()
                            )
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            )
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                        .foregroundColor(.white)
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

