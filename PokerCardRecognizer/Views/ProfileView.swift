import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var backgroundImage: UIImage? = UIImage(named: "casino-background")
    @State private var showingPendingClaims = false
    @State private var showingMyClaims = false
    
    private let claimService = PlayerClaimService()
    
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
                        // Пользователь
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Пользователь")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(authViewModel.currentUsername)
                                .foregroundColor(.white.opacity(0.9))
                            if let id = authViewModel.currentUserId {
                                Text(id.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
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
            .onAppear {
                // Обновить счетчики при открытии
            }
        }
    }
}

