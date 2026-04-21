import SwiftUI

struct RangesTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @StateObject private var viewModel = RangesViewModel()
    @State private var selectedPosition: RangePosition = .UTG
    @State private var positionToReset: RangePosition?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                NavigationLink {
                    EquityGuesserLobbyView()
                } label: {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(.casinoAccentGreen)
                        VStack(alignment: .leading) {
                            Text("Тренировки")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Тренажёр эквити")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Position picker
                Picker("Позиция", selection: $selectedPosition) {
                    ForEach(RangePosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.casinoAccentGreen)
                .padding(.horizontal)

                // Stats bar
                statsBar

                // Grid
                RangeChartGridView(
                    selectedHands: viewModel.charts[selectedPosition]?.selectedHands ?? [],
                    onToggle: { hand in
                        guard let userId = authViewModel.currentUserId else { return }
                        viewModel.toggle(hand: hand, position: selectedPosition, userId: userId)
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 8)

                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .casinoBackground()
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    positionToReset = selectedPosition
                } label: {
                    Text("Сброс")
                        .font(.subheadline)
                        .foregroundColor(.casinoAccentGold)
                }
                .accessibilityIdentifier("ranges_reset_button")
            }
        }
        .alert("Сбросить диапазон?", isPresented: Binding(
            get: { positionToReset != nil },
            set: { if !$0 { positionToReset = nil } }
        )) {
            Button("Сбросить", role: .destructive) {
                guard let pos = positionToReset,
                      let userId = authViewModel.currentUserId else { return }
                Task { await viewModel.reset(position: pos, userId: userId) }
                positionToReset = nil
            }
            Button("Отмена", role: .cancel) { positionToReset = nil }
        } message: {
            if let pos = positionToReset {
                Text("Все руки позиции \(pos.rawValue) будут очищены.")
            }
        }
        .task {
            guard let userId = authViewModel.currentUserId else { return }
            await viewModel.load(userId: userId)
        }
        .accessibilityIdentifier("screen.ranges")
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        let pct  = viewModel.percent(for: selectedPosition)
        let cnt  = viewModel.handCount(for: selectedPosition)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f%%", pct))
                    .font(.title2.bold())
                    .foregroundColor(.casinoAccentGold)
                Text("\(cnt) / 169 рук")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
