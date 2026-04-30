import SwiftUI
import CoreData

/// Sheet shown when the host taps "Место" in GameDetailView.
/// Lists existing places, lets the user pick one or create a new one.
struct GamePlaceEditorSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var syncCoordinator: SyncCoordinator

    @ObservedObject var game: Game

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.name, ascending: true)],
        animation: .default
    ) private var places: FetchedResults<Place>

    @State private var selectedPlaceId: UUID?
    @State private var showNewPlaceAlert = false
    @State private var newPlaceName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(places, id: \.placeId) { place in
                        HStack {
                            Text(place.name ?? "—")
                                .foregroundColor(DS.Color.txt)
                            Spacer()
                            if selectedPlaceId == place.placeId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DS.Color.green)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPlaceId = place.placeId }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                } header: {
                    Text("Выберите место")
                        .foregroundColor(DS.Color.txt3)
                }

                Section {
                    Button(action: { showNewPlaceAlert = true }) {
                        Label("Новое место…", systemImage: "plus.circle")
                            .foregroundColor(DS.Color.green)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(DS.Color.red)
                            .font(.caption)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.bgBase)
            .navigationTitle("Место проведения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(DS.Color.txt2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("Сохранить") { Task { await save() } }
                            .foregroundColor(DS.Color.green)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear { selectedPlaceId = game.place?.placeId }
        .alert("Новое место", isPresented: $showNewPlaceAlert) {
            TextField("Название", text: $newPlaceName)
            Button("Создать") { Task { await createAndSelect() } }
            Button("Отмена", role: .cancel) { newPlaceName = "" }
        } message: {
            Text("Введите название нового места")
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let selectedPlace = selectedPlaceId.flatMap { pid in
            places.first { $0.placeId == pid }
        }

        game.place = selectedPlace
        game.placeId = selectedPlace?.placeId

        do {
            try viewContext.save()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Push game update to Supabase
        await syncCoordinator.quickSyncGame(game)
        dismiss()
    }

    // MARK: - Create new place

    private func createAndSelect() async {
        let name = newPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        newPlaceName = ""
        guard !name.isEmpty else { return }

        // Create in Core Data
        guard let newPlace = PersistenceController.shared.createPlace(
            name: name,
            createdByUserId: nil
        ) else {
            errorMessage = "Не удалось создать место"
            return
        }

        // Push to Supabase
        await syncCoordinator.quickSyncPlace(newPlace)

        await MainActor.run {
            selectedPlaceId = newPlace.placeId
        }
    }
}
