//
//  CardRecognitionService.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import Vision
import CoreImage
import UIKit
import AVFoundation

class CardRecognitionService {
    
    /// Распознает карты на изображении используя Vision Framework + OCR
    static func recognizeCards(in image: CIImage, completion: @escaping ([Card]) -> Void) {
        var detectedCards: [Card] = []
        let group = DispatchGroup()
        
        // 1. Находим прямоугольные области (карты) используя детекцию прямоугольников
        group.enter()
        detectCardRectangles(in: image) { rectangles in
            print("📦 Найдено прямоугольных областей: \(rectangles.count)")
            
            // 2. Для каждой области распознаем текст и определяем карту
            for (index, rect) in rectangles.enumerated() {
                group.enter()
                recognizeCardInRegion(image: image, region: rect) { card in
                    if let card = card {
                        detectedCards.append(card)
                        print("✅ Распознана карта: \(card.displayName)")
                    }
                    group.leave()
                }
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(detectedCards)
        }
    }
    
    /// Детектирует прямоугольные области (карты) на изображении
    private static func detectCardRectangles(in image: CIImage, completion: @escaping ([CGRect]) -> Void) {
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            completion([])
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let observations = request.results as? [VNRectangleObservation] else {
                completion([])
                return
            }
            
            var rectangles: [CGRect] = []
            for observation in observations {
                // Фильтруем по размеру (карты должны быть достаточно большими)
                let boundingBox = observation.boundingBox
                let width = boundingBox.width * CGFloat(cgImage.width)
                let height = boundingBox.height * CGFloat(cgImage.height)
                
                // Минимальный размер карты (примерно 50x70 пикселей)
                if width > 50 && height > 70 {
                    // Преобразуем координаты Vision в координаты изображения
                    let rect = VNImageRectForNormalizedRect(boundingBox, cgImage.width, cgImage.height)
                    rectangles.append(rect)
                }
            }
            
            completion(rectangles)
        }
        
        // Настройки для лучшего обнаружения карт
        request.minimumAspectRatio = 0.5 // Карты примерно 2:3
        request.maximumAspectRatio = 0.8
        request.minimumSize = 0.1 // Минимум 10% от размера изображения
        request.minimumConfidence = 0.5
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Ошибка детекции прямоугольников: \(error)")
            completion([])
        }
    }
    
    /// Распознает карту в указанной области используя OCR
    private static func recognizeCardInRegion(image: CIImage, region: CGRect, completion: @escaping (Card?) -> Void) {
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            completion(nil)
            return
        }
        
        // Вырезаем область карты
        guard let croppedCGImage = cgImage.cropping(to: region) else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // Собираем весь распознанный текст
            var recognizedText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                recognizedText += topCandidate.string + " "
            }
            
            print("📝 Распознанный текст: '\(recognizedText)'")
            
            // Парсим карту из текста
            if let card = parseCardFromText(recognizedText) {
                completion(card)
            } else {
                // Если не удалось распознать по тексту, пробуем по цвету/символам
                recognizeCardByVisualFeatures(image: CIImage(cgImage: croppedCGImage), completion: completion)
            }
        }
        
        // Настройки OCR
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: croppedCGImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Ошибка OCR: \(error)")
            completion(nil)
        }
    }
    
    /// Распознает карту по визуальным признакам (цвет, символы масти)
    private static func recognizeCardByVisualFeatures(image: CIImage, completion: @escaping (Card?) -> Void) {
        // Здесь можно добавить детекцию символов масти и достоинства
        // Пока возвращаем nil, если OCR не сработал
        completion(nil)
    }
    
    /// Парсит карту из распознанного текста
    private static func parseCardFromText(_ text: String) -> Card? {
        let cleaned = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Паттерны для распознавания:
        // "A", "2", "3", ..., "10", "J", "Q", "K"
        // Масти: ♠, ♥, ♦, ♣ или S, H, D, C
        
        var rank: CardRank?
        var suit: CardSuit?
        
        // Определяем достоинство
        if cleaned.contains("A") || cleaned.contains("ACE") {
            rank = .ace
        } else if cleaned.contains("K") || cleaned.contains("KING") {
            rank = .king
        } else if cleaned.contains("Q") || cleaned.contains("QUEEN") {
            rank = .queen
        } else if cleaned.contains("J") || cleaned.contains("JACK") {
            rank = .jack
        } else if let tenMatch = cleaned.range(of: "10") {
            rank = .ten
        } else {
            // Ищем цифры 2-9
            for i in 2...9 {
                if cleaned.contains(String(i)) {
                    rank = CardRank(rawValue: String(i))
                    break
                }
            }
        }
        
        // Определяем масть
        if cleaned.contains("♠") || cleaned.contains("S") || cleaned.contains("SPADE") {
            suit = .spades
        } else if cleaned.contains("♥") || cleaned.contains("H") || cleaned.contains("HEART") {
            suit = .hearts
        } else if cleaned.contains("♦") || cleaned.contains("D") || cleaned.contains("DIAMOND") {
            suit = .diamonds
        } else if cleaned.contains("♣") || cleaned.contains("C") || cleaned.contains("CLUB") {
            suit = .clubs
        }
        
        if let rank = rank, let suit = suit {
            return Card(rank: rank, suit: suit, confidence: 0.8, rect: .zero)
        }
        
        return nil
    }
}


