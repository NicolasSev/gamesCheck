import SwiftUI

/// Блокирующий экран onboarding'а: показывается когда у пользователя нет ни одного
/// `place_members` записи. До прохождения этого экрана юзер не видит чужих игр и
/// статистики (см. фаза 9 / migration 052).
///
/// Состояния:
/// - `.loading` — fetch directory
/// - `.list`    — список активных мест с действиями
/// - `.error`   — ошибка fetch'а с retry
struct OnboardingPlaceGateView: View {
    @EnvironmentObject var placeSession: PlaceSessionManager

    @State private var entries: [PlaceDirectoryEntryDTO] = []
    @State private var pendingCreateRequests: [MyPlaceCreateRequestDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellingRequestId: UUID?

    @State private var showingRequestAccess = false
    @State private var requestAccessForPlace: PlaceDirectoryEntryDTO?
    @State private var showingCreatePlace = false

    var body: some View {
        ZStack {
            DS.Color.bgBase.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !pendingCreateRequests.isEmpty {
                        pendingCreateSection
                    }

                    if isLoading {
                        ProgressView()
                            .tint(DS.Color.green)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorMessage {
                        errorView(message: errorMessage)
                    } else if entries.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(entries) { entry in
                            placeRow(entry)
                        }
                    }

                    createNewPlaceButton
                }
                .padding(20)
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
        .sheet(isPresented: $showingRequestAccess) {
            if let place = requestAccessForPlace {
                RequestPlaceAccessView(prefilledPlaceId: place.id, prefilledPlaceName: place.name)
                    .environmentObject(placeSession)
                    .onDisappear {
                        Task { await reload() }
                    }
            }
        }
        .sheet(isPresented: $showingCreatePlace) {
            RequestCreatePlaceView()
                .environmentObject(placeSession)
                .onDisappear {
                    Task { await reload() }
                }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Выберите место")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("Чтобы начать пользоваться приложением, присоединитесь к месту проведения игр или создайте своё.")
                .font(.body)
                .foregroundColor(DS.Color.txt2)
        }
    }

    @ViewBuilder
    private func placeRow(_ entry: PlaceDirectoryEntryDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundColor(.white)

                statusLabel(entry)
            }
            Spacer()
            actionButton(entry)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func statusLabel(_ entry: PlaceDirectoryEntryDTO) -> some View {
        if entry.iAmMember {
            Label("Вы участник", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(DS.Color.green)
        } else if entry.hasPendingAccessRequestFromMe {
            Label("Заявка отправлена", systemImage: "clock.fill")
                .font(.caption)
                .foregroundColor(.orange)
        } else {
            Text("Нужна заявка на доступ")
                .font(.caption)
                .foregroundColor(DS.Color.txt2)
        }
    }

    @ViewBuilder
    private func actionButton(_ entry: PlaceDirectoryEntryDTO) -> some View {
        if entry.iAmMember {
            Button("Войти") {
                let m = PlaceMembershipDTO(
                    placeId: entry.id,
                    role: entry.memberRole ?? "member",
                    placeName: entry.name,
                    placeSlug: entry.slug,
                    isArchived: false
                )
                placeSession.setActivePlace(m)
                Task { await placeSession.fetchMemberships() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.green)
        } else if entry.hasPendingAccessRequestFromMe {
            Text("Ожидание")
                .font(.caption.bold())
                .foregroundColor(DS.Color.txt2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.05)))
        } else {
            Button("Запросить") {
                requestAccessForPlace = entry
                showingRequestAccess = true
            }
            .buttonStyle(.bordered)
            .tint(DS.Color.green)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 40))
                .foregroundColor(DS.Color.txt2)
            Text("Пока нет ни одного активного места")
                .font(.headline)
                .foregroundColor(.white)
            Text("Создайте новое место — после одобрения супер-админом вы станете его администратором.")
                .font(.subheadline)
                .foregroundColor(DS.Color.txt2)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            Text("Не удалось загрузить список мест")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(DS.Color.txt2)
                .multilineTextAlignment(.center)
            Button("Повторить") { Task { await reload() } }
                .buttonStyle(.bordered)
                .tint(DS.Color.green)
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private var pendingCreateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ваши заявки на создание места")
                .font(.caption.bold())
                .foregroundColor(DS.Color.txt2)
                .textCase(.uppercase)

            ForEach(pendingCreateRequests) { req in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("«\(req.proposedName)»")
                            .font(.headline)
                            .foregroundColor(.white)
                        Label("Ожидает одобрения супер-админом", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Button {
                        cancelCreateRequest(req)
                    } label: {
                        if cancellingRequestId == req.id {
                            ProgressView().tint(DS.Color.txt2)
                        } else {
                            Text("Отменить")
                                .font(.caption.bold())
                                .foregroundColor(DS.Color.txt2)
                        }
                    }
                    .disabled(cancellingRequestId == req.id)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var createNewPlaceButton: some View {
        Button(action: { showingCreatePlace = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Не нашли своё место? Создать новое")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(16)
            .foregroundColor(DS.Color.green)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DS.Color.green.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    @MainActor
    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let dir = placeSession.fetchPlacesDirectory()
            async let pend = placeSession.fetchMyPendingCreateRequests()
            entries = try await dir
            pendingCreateRequests = (try? await pend) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func cancelCreateRequest(_ req: MyPlaceCreateRequestDTO) {
        cancellingRequestId = req.id
        Task {
            do {
                try await placeSession.cancelPlaceCreateRequest(requestId: req.id)
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
            await MainActor.run { cancellingRequestId = nil }
        }
    }
}
