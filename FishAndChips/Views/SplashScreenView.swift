import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var currentSuitIndex = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var suitAnimationTimer: Timer?
    /// Первый показ hero (как web v13: scale 0.6 → 1).
    @State private var heroAppeared = false

    // Масти по кругу: club, heart, diamond, spade
    let suits = ["suit.club.fill", "suit.heart.fill", "suit.diamond.fill", "suit.spade.fill"]
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 10) {
                    Image(systemName: suits[currentSuitIndex])
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("Fish & Chips")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(heroAppeared ? 1 : 0.6)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: heroAppeared)
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Синхронизация...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .opacity(isAnimating ? 1.0 : 0.5)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("Подготовка данных")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 60)
            }
        }
        .casinoBackground()
        .accessibilityIdentifier("splash_screen")
        .onAppear {
            isAnimating = true
            heroAppeared = true
            startSuitAnimation()
        }
        .onDisappear {
            suitAnimationTimer?.invalidate()
            suitAnimationTimer = nil
        }
    }
    
    // MARK: - Animation Logic
    
    private func startSuitAnimation() {
        suitAnimationTimer?.invalidate()
        suitAnimationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            animateSuitCycle()
        }

        animateSuitCycle()
    }
    
    private func animateSuitCycle() {
        // УДАР СЕРДЦА - Фаза 1: Пульсация (увеличение → уменьшение)
        // 1.0 → 1.3 → 0.7 с одновременным fade out к концу
        
        // Шаг 1: Увеличение (как вдох) - 0.5 сек
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            scale = 1.3
        }
        
        // Шаг 2: Уменьшение + fade out (как выдох) - 0.6 сек
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Одновременно уменьшаем и начинаем fade out
            withAnimation(.easeInOut(duration: 0.4)) {
                scale = 0.7
            }
            
            // Fade out в последние 0.3 секунды уменьшения
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0.0
                }
            }
        }
        
        // СМЕНА МАСТИ - Фаза 2: В момент полного исчезновения
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            // Переключаем на следующую масть
            currentSuitIndex = (currentSuitIndex + 1) % suits.count
            
            // Готовим для появления
            scale = 0.7
        }
        
        // НОВЫЙ УДАР - Фаза 3: Появление + пульсация нового символа
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            // Fade in быстро (0.25 сек)
            withAnimation(.easeIn(duration: 0.25)) {
                opacity = 1.0
            }
            
            // Одновременно начинаем увеличение до нормального размера
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65, blendDuration: 0)) {
                scale = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
