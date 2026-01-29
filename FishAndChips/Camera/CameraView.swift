import SwiftUI

class CardDetectionCoordinator: ObservableObject {
    @Published var detectedCards: [Card] = []
}

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var coordinator: CardDetectionCoordinator
    
    func makeCoordinator() -> CardDetectionCoordinator {
        return coordinator
    }
    
    func makeUIViewController(context: Context) -> VisionObjectRecognitionViewController {
        let controller = VisionObjectRecognitionViewController()
        controller.onCardsDetected = { cards in
            DispatchQueue.main.async {
                context.coordinator.detectedCards = cards
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: VisionObjectRecognitionViewController, context: Context) {
        // Обновляем колбэк
        uiViewController.onCardsDetected = { cards in
            DispatchQueue.main.async {
                context.coordinator.detectedCards = cards
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: VisionObjectRecognitionViewController, coordinator: CardDetectionCoordinator) {
        uiViewController.stopCaptureSession()
    }
}
