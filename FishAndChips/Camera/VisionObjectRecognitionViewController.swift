import UIKit
import AVFoundation
import CoreML
import CoreImage
import ObjectiveC

extension CIImage {
    func resize(to size: CGSize) -> CIImage? {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        return transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

class VisionObjectRecognitionViewController: ViewController {

    private var detectionOverlay: CALayer! = nil
    private var model: MLModel?
    
    // Настройки распознавания
    var objectnessThreshold: Float = 0.2 // Снижен с 0.25 для лучшего обнаружения
    var confidenceThreshold: Float = 0.1 // Снижен до 0.1 для тестирования (можно повысить после проверки)
    var enableImageEnhancement: Bool = true // Включить предобработку изображения
    
    // Колбэк для передачи распознанных карт
    var onCardsDetected: (([Card]) -> Void)?
    
    // Текущие распознанные карты
    private var detectedCards: [Card] = []
    
    // Режим распознавания
    private var isRecognitionEnabled: Bool = false // Распознавание только по кнопке
    
    // Последний захваченный кадр для обработки
    private var lastSampleBuffer: CMSampleBuffer?
    
    // Агрегация результатов за несколько кадров
    private var cardHistory: [[Card]] = []
    private let historySize: Int = 5 // Храним последние 5 кадров
    private var aggregatedCards: [Card] = []
    private var hasLoggedStructure = false // Для отладки структуры массива

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModel()
        setupLayers()
        setupUI()
    }
    
    private func setupUI() {
        // Добавляем кнопку для фото
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("📷 Распознать карты", for: .normal)
        captureButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 220),
            captureButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Индикатор обработки
        let processingLabel = UILabel()
        processingLabel.text = "Нажмите кнопку для распознавания"
        processingLabel.textColor = .white
        processingLabel.font = .systemFont(ofSize: 14)
        processingLabel.textAlignment = .center
        processingLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        processingLabel.layer.cornerRadius = 8
        processingLabel.clipsToBounds = true
        processingLabel.translatesAutoresizingMaskIntoConstraints = false
        processingLabel.isHidden = false
        view.addSubview(processingLabel)
        
        NSLayoutConstraint.activate([
            processingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            processingLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -10),
            processingLabel.widthAnchor.constraint(equalToConstant: 280),
            processingLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Сохраняем ссылку на label для обновления текста
        objc_setAssociatedObject(self, "processingLabel", processingLabel, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Кнопка настроек
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("⚙️", for: .normal)
        settingsButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.layer.cornerRadius = 20
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            settingsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            settingsButton.widthAnchor.constraint(equalToConstant: 40),
            settingsButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func capturePhoto() {
        debugLog("📷 Захват фото для обработки")
        
        // Обновляем текст индикатора
        if let label = objc_getAssociatedObject(self, "processingLabel") as? UILabel {
            label.text = "Обработка..."
            label.isHidden = false
        }
        
        // Включаем распознавание на один кадр
        isRecognitionEnabled = true
        
        // Если есть сохраненный кадр, обрабатываем его
        if let sampleBuffer = lastSampleBuffer {
            processFrame(sampleBuffer: sampleBuffer)
        } else {
            debugLog("⚠️ Нет сохраненного кадра, ожидаем следующий...")
            if let label = objc_getAssociatedObject(self, "processingLabel") as? UILabel {
                label.text = "Ожидание кадра..."
            }
        }
    }
    
    @objc private func showSettings() {
        let alert = UIAlertController(title: "Настройки распознавания", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Порог уверенности: \(String(format: "%.2f", confidenceThreshold))", style: .default) { _ in
            self.showConfidenceSlider()
        })
        
        alert.addAction(UIAlertAction(title: "Улучшение изображения: \(enableImageEnhancement ? "Вкл" : "Выкл")", style: .default) { _ in
            self.enableImageEnhancement.toggle()
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.width - 60, y: 60, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func showConfidenceSlider() {
        let alert = UIAlertController(title: "Порог уверенности", message: "Текущее значение: \(String(format: "%.2f", confidenceThreshold))", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = String(format: "%.2f", self.confidenceThreshold)
            textField.keyboardType = .decimalPad
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            if let text = alert.textFields?.first?.text,
               let value = Float(text),
               value >= 0 && value <= 1 {
                self.confidenceThreshold = value
            }
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }

    func stopCaptureSession() {
        debugLog("🛑 Останавливаем камеру")
        teardownAVCapture()
        session.stopRunning()
    }

    private func setupModel() {
        guard let modelURL = Bundle.main.url(forResource: "yolov8m_synthetic", withExtension: "mlmodelc") else {
            debugLog("❌ yolov8m_synthetic.mlmodelc не найден в Bundle")
            return
        }

        do {
            model = try MLModel(contentsOf: modelURL)
            debugLog("✅ Модель успешно загружена")
        } catch {
            debugLog("❌ Не удалось загрузить модель: \(error)")
        }
    }

    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Сохраняем последний кадр для обработки по кнопке
        lastSampleBuffer = sampleBuffer
        
        // Обрабатываем кадр только если включено распознавание
        guard isRecognitionEnabled else {
            return
        }
        
        // Обрабатываем кадр
        processFrame(sampleBuffer: sampleBuffer)
        
        // Выключаем распознавание после обработки
        isRecognitionEnabled = false
    }
    
    private func processFrame(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugLog("❌ Нет pixelBuffer")
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Используем Vision Framework + OCR вместо ML модели
        CardRecognitionService.recognizeCards(in: ciImage) { [weak self] cards in
            DispatchQueue.main.async {
                self?.handleRecognizedCards(cards)
            }
        }
    }
    
    private func handleRecognizedCards(_ cards: [Card]) {
        // Добавляем в историю и агрегируем
        cardHistory.append(cards)
        if cardHistory.count > historySize {
            cardHistory.removeFirst()
        }
        
        // Агрегируем результаты (majority voting)
        aggregatedCards = aggregateCardDetections(cardHistory)
        
        detectedCards = aggregatedCards
        detectionOverlay.sublayers = nil
        
        for card in aggregatedCards {
            let shape = self.createRoundedRectLayerWithBounds(card.rect)
            let text = self.createTextSubLayerInBounds(card.rect, identifier: card.displayName, confidence: card.confidence)
            shape.addSublayer(text)
            detectionOverlay.addSublayer(shape)
            debugLog("🃏 \(card.displayName) conf=\(String(format: "%.2f", card.confidence))")
        }
        
        updateLayerGeometry()
        
        // Вызываем колбэк с распознанными картами
        onCardsDetected?(aggregatedCards)
        
        // Обновляем индикатор
        if let label = objc_getAssociatedObject(self, "processingLabel") as? UILabel {
            if aggregatedCards.isEmpty {
                label.text = "Карты не распознаны"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    label.text = "Нажмите кнопку для распознавания"
                }
            } else {
                label.text = "Распознано: \(aggregatedCards.count) карт"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    label.text = "Нажмите кнопку для распознавания"
                }
            }
        }
        
        // Показываем сообщение о результате
        if aggregatedCards.isEmpty {
            debugLog("⚠️ Карты не распознаны. Попробуйте:")
            debugLog("   - Улучшить освещение")
            debugLog("   - Поднести карты ближе к камере")
            debugLog("   - Убедиться, что карты в фокусе")
        } else {
            debugLog("✅ Распознано карт: \(aggregatedCards.count)")
        }
    }

    // MARK: - Vision Helpers

    func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0, y: 0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }

    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        let xScale = bounds.size.width / bufferSize.height
        let yScale = bounds.size.height / bufferSize.width
        let scale = max(xScale, yScale)

        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat.pi / 2).scaledBy(x: scale, y: -scale))
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    // MARK: - Parsing & NMS

    func parseYOLOOutput(from confidenceArray: MLMultiArray, coordinates: MLMultiArray, imageSize: CGSize) -> [YOLOPrediction] {
        var predictions: [YOLOPrediction] = []
        
        // Проверяем структуру массивов
        guard confidenceArray.count > 0, coordinates.count > 0 else {
            debugLog("⚠️ Пустые массивы")
            return []
        }
        
        // Выводим информацию о структуре для отладки (только первый раз)
        if !hasLoggedStructure {
            debugLog("📊 Confidence shape: \(confidenceArray.shape.map { $0.intValue }), count: \(confidenceArray.count)")
            debugLog("📊 Coordinates shape: \(coordinates.shape.map { $0.intValue }), count: \(coordinates.count)")
            
            // Выводим первые несколько значений для отладки
            let confPtr = UnsafeMutablePointer<Float32>(OpaquePointer(confidenceArray.dataPointer))
            let coordPtr = UnsafeMutablePointer<Float32>(OpaquePointer(coordinates.dataPointer))
            debugLog("📊 Первые 10 значений confidence: \(Array(0..<min(10, confidenceArray.count)).map { confPtr[$0] })")
            debugLog("📊 Первые 10 значений coordinates: \(Array(0..<min(10, coordinates.count)).map { coordPtr[$0] })")
            hasLoggedStructure = true
        }
        
        let confidencePointer = UnsafeMutablePointer<Float32>(OpaquePointer(confidenceArray.dataPointer))
        let coordinatesPointer = UnsafeMutablePointer<Float32>(OpaquePointer(coordinates.dataPointer))
        
        // Определяем структуру confidence массива
        let numDimensions = confidenceArray.shape.count
        var numBoxes: Int
        var numClasses: Int
        
        if numDimensions == 2 {
            // Формат: [num_boxes, num_classes]
            numBoxes = confidenceArray.shape[0].intValue
            numClasses = confidenceArray.shape[1].intValue
        } else if numDimensions == 1 {
            // Плоский массив - предполагаем структуру
            numClasses = 13 // 13 классов для пик (можно расширить)
            numBoxes = confidenceArray.count / numClasses
        } else {
            debugLog("❌ Неподдерживаемая структура confidence: \(numDimensions) размерностей")
            return []
        }
        
        // Определяем структуру coordinates массива
        let coordDimensions = coordinates.shape.count
        var coordStride: Int
        
        if coordDimensions == 2 {
            // Формат: [num_boxes, 4] где 4 = [x, y, width, height]
            coordStride = 4
            let coordNumBoxes = coordinates.shape[0].intValue
            if coordNumBoxes != numBoxes {
                debugLog("⚠️ Несоответствие количества boxes: confidence=\(numBoxes), coordinates=\(coordNumBoxes)")
                numBoxes = min(numBoxes, coordNumBoxes)
            }
        } else if coordDimensions == 1 {
            // Плоский массив: [x1, y1, w1, h1, x2, y2, w2, h2, ...]
            coordStride = 4
            numBoxes = min(numBoxes, coordinates.count / coordStride)
        } else {
            debugLog("❌ Неподдерживаемая структура coordinates: \(coordDimensions) размерностей")
            return []
        }
        
        // Модель возвращает классы в формате: "10c,10d,10h,10s,2c,2d,2h,2s..." (52 класса)
        // Но мы пока поддерживаем только пики для упрощения
        // Маппинг: нужно найти индекс для пик в общем списке классов
        let allClasses = ["10c","10d","10h","10s","2c","2d","2h","2s","3c","3d","3h","3s","4c","4d","4h","4s","5c","5d","5h","5s","6c","6d","6h","6s","7c","7d","7h","7s","8c","8d","8h","8s","9c","9d","9h","9s","Ac","Ad","Ah","As","Jc","Jd","Jh","Js","Kc","Kd","Kh","Ks","Qc","Qd","Qh","Qs"]
        
        // Индексы пик в общем списке классов
        let spadeIndices: [Int] = [3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 51] // 10s, 2s, 3s, 4s, 5s, 6s, 7s, 8s, 9s, As, Js, Ks, Qs
        let spadeLabels = ["10♠", "2♠", "3♠", "4♠", "5♠", "6♠", "7♠", "8♠", "9♠", "A♠", "J♠", "K♠", "Q♠"]
        
        // Парсим оба массива вместе
        for i in 0..<numBoxes {
            // Получаем confidence для всех классов
            var bestScore: Float = 0
            var bestSpadeIndex: Int = -1
            
            // Ищем лучший результат среди пик
            for (idx, spadeIdx) in spadeIndices.enumerated() {
                guard spadeIdx < numClasses else { continue }
                let confIndex = i * numClasses + spadeIdx
                guard confIndex < confidenceArray.count else { continue }
                let score = confidencePointer[confIndex]
                if score > bestScore {
                    bestScore = score
                    bestSpadeIndex = idx
                }
            }
            
            // Также проверяем максимальный confidence среди всех классов для отладки
            var maxOverallScore: Float = 0
            for j in 0..<min(numClasses, 52) {
                let confIndex = i * numClasses + j
                guard confIndex < confidenceArray.count else { break }
                let score = confidencePointer[confIndex]
                if score > maxOverallScore {
                    maxOverallScore = score
                }
            }
            
            if i < 3 { // Логируем первые 3 box для отладки
                debugLog("📦 Box \(i): max overall=\(String(format: "%.3f", maxOverallScore)), best spade=\(String(format: "%.3f", bestScore))")
            }
            
            if bestScore < confidenceThreshold || bestSpadeIndex < 0 { continue }
            
            // Получаем координаты
            let coordBase = i * coordStride
            guard coordBase + 3 < coordinates.count else { continue }
            
            // Координаты обычно в формате [x_center, y_center, width, height] относительно размера изображения (0-1)
            let x = CGFloat(coordinatesPointer[coordBase + 0])
            let y = CGFloat(coordinatesPointer[coordBase + 1])
            let w = CGFloat(coordinatesPointer[coordBase + 2])
            let h = CGFloat(coordinatesPointer[coordBase + 3])
            
            // Преобразуем в абсолютные координаты
            // Координаты могут быть в разных форматах - пробуем оба
            var originX: CGFloat
            var originY: CGFloat
            var rectWidth: CGFloat
            var rectHeight: CGFloat
            
            // Если координаты в диапазоне 0-1 (нормализованные)
            if x <= 1.0 && y <= 1.0 && w <= 1.0 && h <= 1.0 {
                originX = (x - w / 2) * imageSize.width
                originY = (y - h / 2) * imageSize.height
                rectWidth = w * imageSize.width
                rectHeight = h * imageSize.height
            } else {
                // Если координаты уже в пикселях
                originX = x - w / 2
                originY = y - h / 2
                rectWidth = w
                rectHeight = h
            }
            
            let rect = CGRect(x: originX, y: originY, width: rectWidth, height: rectHeight)
            let label = bestSpadeIndex < spadeLabels.count ? spadeLabels[bestSpadeIndex] : "Unknown"
            
            debugLog("✅ Найдена карта: \(label) с confidence=\(String(format: "%.3f", bestScore)) в rect=\(rect)")
            predictions.append(YOLOPrediction(rect: rect, confidence: bestScore, label: label))
        }
        
        return predictions
    }

    func nonMaximumSuppression(predictions: [YOLOPrediction], iouThreshold: Float = 0.5) -> [YOLOPrediction] {
        var result: [YOLOPrediction] = []
        let sorted = predictions.sorted { $0.confidence > $1.confidence }
        var active = Array(repeating: true, count: sorted.count)

        for i in 0..<sorted.count {
            if !active[i] { continue }
            let a = sorted[i]
            result.append(a)

            for j in (i+1)..<sorted.count {
                if !active[j] { continue }
                let b = sorted[j]
                if iou(a.rect, b.rect) > iouThreshold {
                    active[j] = false
                }
            }
        }

        return result
    }

    func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let inter = a.intersection(b)
        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea
        if unionArea <= 0 { return 0 }
        return Float(interArea / unionArea)
    }

    // MARK: - Overlay Layers

    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: Float) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        textLayer.string = "\(identifier) \(String(format: "%.2f", confidence))"
        textLayer.fontSize = 10
        textLayer.foregroundColor = UIColor.black.cgColor
        textLayer.backgroundColor = UIColor.white.withAlphaComponent(0.7).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.frame = CGRect(x: bounds.origin.x, y: bounds.origin.y - 20, width: bounds.size.width, height: 20)
        return textLayer
    }

    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let layer = CALayer()
        layer.bounds = bounds
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.4).cgColor
        layer.cornerRadius = 4
        return layer
    }
    
    // MARK: - Card Parsing
    
    private func parseRank(from label: String) -> CardRank? {
        // Пока модель распознает только пики, но можно расширить
        let rankString = String(label.dropLast()) // Убираем масть
        return CardRank.allCases.first { $0.rawValue == rankString }
    }
    
    private func parseSuit(from label: String) -> CardSuit? {
        // Пока только пики, но можно расширить для других мастей
        if label.contains("♠") {
            return .spades
        } else if label.contains("♥") {
            return .hearts
        } else if label.contains("♦") {
            return .diamonds
        } else if label.contains("♣") {
            return .clubs
        }
        return .spades // По умолчанию
    }
    
    // MARK: - Aggregation
    
    /// Агрегирует результаты распознавания за несколько кадров
    private func aggregateCardDetections(_ history: [[Card]]) -> [Card] {
        guard !history.isEmpty else { return [] }
        
        // Группируем карты по rank и suit
        var cardGroups: [String: [Card]] = [:]
        
        for frameCards in history {
            for card in frameCards {
                let key = "\(card.rank.rawValue)\(card.suit.rawValue)"
                if cardGroups[key] == nil {
                    cardGroups[key] = []
                }
                cardGroups[key]?.append(card)
            }
        }
        
        // Оставляем только карты, которые были обнаружены в большинстве кадров
        let threshold = max(1, history.count / 2) // Минимум в половине кадров
        var aggregated: [Card] = []
        
        for (_, cards) in cardGroups {
            if cards.count >= threshold {
                // Берем карту с максимальной уверенностью
                if let bestCard = cards.max(by: { $0.confidence < $1.confidence }) {
                    // Усредняем confidence по всем обнаружениям
                    let avgConfidence = cards.map { $0.confidence }.reduce(0, +) / Float(cards.count)
                    let finalCard = Card(rank: bestCard.rank, suit: bestCard.suit, confidence: avgConfidence, rect: bestCard.rect)
                    aggregated.append(finalCard)
                }
            }
        }
        
        return aggregated
    }
}

