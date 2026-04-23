import SwiftUI

struct EquityGuesserPlayView: View {
    let config: EquitySessionConfig
    @StateObject private var vm = EquityGuesserViewModel()

    var body: some View {
        Group {
            switch vm.phase {
            case .loading:
                ProgressView("Генерация…")
                    .tint(.white)
            case .guessing, .revealed:
                playContent
            case .summary:
                EquityGuesserSummaryView(
                    rounds: vm.rounds,
                    totalScore: vm.totalScore,
                    bestStreak: vm.bestStreak,
                    config: config
                )
            }
        }
        .task {
            await vm.startSession(config)
        }
        .navigationTitle("Эквити")
        .navigationBarTitleDisplayMode(.inline)
        .v2ScreenBackground()
    }

    private var playContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Раунд \(vm.roundIndex + 1)/\(config.sessionLength)")
                    Spacer()
                    Text("Стрик \(vm.streak)")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

                if let sc = vm.currentScenario {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("Hero").font(.caption).foregroundColor(.gray)
                            HStack {
                                ForEach(sc.heroHand, id: \.self) { CardDisplayView(notation: $0) }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Villain").font(.caption).foregroundColor(.gray)
                            HStack {
                                let hide = !config.showVillainImmediately && vm.phase == .guessing
                                ForEach(sc.villainHand, id: \.self) { n in
                                    if hide {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.gray.opacity(0.4))
                                            .frame(width: 35, height: 50)
                                    } else {
                                        CardDisplayView(notation: n)
                                    }
                                }
                            }
                        }
                    }

                    if !sc.board.isEmpty {
                        Text("Борд").font(.caption).foregroundColor(.gray)
                        HStack {
                            ForEach(sc.board, id: \.self) { HandDetailBoardCardView(notation: $0) }
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Эквити Hero: \(Int(vm.currentGuess))%")
                            .foregroundColor(.casinoAccentGreen)
                        Slider(value: $vm.currentGuess, in: 0...100, step: 1)
                            .tint(.casinoAccentGreen)
                        HStack {
                            Text("Villain \(max(0, min(100, 100 - Int(vm.currentGuess))))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                    }

                    if vm.phase == .guessing {
                        Button(action: { vm.submitGuess() }) {
                            Text("Подтвердить")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.casinoAccentGreen)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }

                    if vm.phase == .revealed, let r = vm.lastReveal, let sc = vm.currentScenario {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Факт: \(String(format: "%.2f", sc.actualEquity))% · Δ \(String(format: "%.2f", r.delta))")
                            Text("+\(r.points) очков")
                                .font(.headline)
                                .foregroundColor(.casinoAccentGold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)

                        Button(action: { vm.nextRound() }) {
                            Text(vm.roundIndex + 1 >= vm.scenarios.count ? "Итоги" : "Дальше")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
