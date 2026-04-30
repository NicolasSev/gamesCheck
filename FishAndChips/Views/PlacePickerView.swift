import SwiftUI
import CoreData

/// Выбор существующего места или создание нового.
/// Биндится на `selectedPlaceId: UUID?` — после выбора/создания id записан туда.
struct PlacePickerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel

    @Binding var selectedPlaceId: UUID?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.name, ascending: true)],
        animation: .default
    )
    private var places: FetchedResults<Place>

    @State private var showingNewPlaceSheet = false
    @State private var newPlaceName: String = ""
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if places.isEmpty {
                Text("Нет мест — создайте первое")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Menu {
                ForEach(places) { place in
                    Button {
                        selectedPlaceId = place.placeId
                    } label: {
                        HStack {
                            Text(place.name ?? "—")
                            if place.placeId == selectedPlaceId {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button {
                    showingNewPlaceSheet = true
                } label: {
                    Label("Создать новое место", systemImage: "plus")
                }
            } label: {
                HStack {
                    Text(currentName ?? "Выберите место")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            .accessibilityIdentifier("place_picker_menu")
        }
        .onAppear {
            ensureSelection()
            Task {
                try? await SyncCoordinator.shared.fetchAllPlaces()
                ensureSelection()
            }
        }
        .onChange(of: places.count) { _, _ in ensureSelection() }
        .sheet(isPresented: $showingNewPlaceSheet) {
            NewPlaceSheet(
                isPresented: $showingNewPlaceSheet,
                onCreated: { place in
                    selectedPlaceId = place.placeId
                }
            )
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(authViewModel)
        }
    }

    private var currentName: String? {
        guard let id = selectedPlaceId else { return nil }
        return places.first(where: { $0.placeId == id })?.name
    }

    private func ensureSelection() {
        guard selectedPlaceId == nil, !places.isEmpty else { return }
        let seed = places.first(where: { $0.name == "Подвальный аквариум" })
        selectedPlaceId = seed?.placeId ?? places.first?.placeId
    }
}

private struct NewPlaceSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool
    let onCreated: (Place) -> Void

    @State private var name: String = ""
    @State private var creating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Название")) {
                    TextField("Например: Бар на Достык", text: $name)
                        .accessibilityIdentifier("new_place_name_field")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red.opacity(0.95))
                            .font(.caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Новое место")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { isPresented = false }
                        .foregroundColor(DS.Color.txt2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(creating ? "Создание…" : "Создать") {
                        createPlace()
                    }
                    .disabled(creating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(DS.Color.green)
                    .accessibilityIdentifier("create_place_save_button")
                }
            }
            .preferredColorScheme(.dark)
            .v2ScreenBackground()
        }
    }

    private func createPlace() {
        creating = true
        errorMessage = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            creating = false
            errorMessage = "Введите название"
            return
        }

        if let place = PersistenceController.shared.createPlace(
            name: trimmed,
            createdByUserId: authViewModel.currentUserId
        ) {
            onCreated(place)
            isPresented = false
        } else {
            errorMessage = "Не удалось создать место"
        }
        creating = false
    }
}
