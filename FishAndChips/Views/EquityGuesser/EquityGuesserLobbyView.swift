import SwiftUI

struct EquityGuesserLobbyView: View {
    @State private var length = 10
    @State private var difficulty: EquityDifficulty = .medium
    @State private var showVillain = true

    var body: some View {
        Form {
            Section {
                Picker("Длина сессии", selection: $length) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                }
                Picker("Сложность", selection: $difficulty) {
                    Text("Легко").tag(EquityDifficulty.easy)
                    Text("Средне").tag(EquityDifficulty.medium)
                    Text("Сложно").tag(EquityDifficulty.hard)
                }
                Toggle("Показывать Villain сразу", isOn: $showVillain)
            }
            Section {
                NavigationLink {
                    EquityGuesserPlayView(
                        config: EquitySessionConfig(
                            difficulty: difficulty,
                            sessionLength: length,
                            showVillainImmediately: showVillain
                        )
                    )
                } label: {
                    Text("Старт")
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("Тренажёр эквити")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .casinoBackground()
    }
}
