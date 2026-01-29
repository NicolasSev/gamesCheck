//
//  ImagePreprocessor.swift
//  PokerCardRecognizer
//
//  Created by Николас on 25.11.2025.
//

import CoreImage
import UIKit

class ImagePreprocessor {
    
    /// Применяет улучшения к изображению для лучшего распознавания карт
    static func enhanceImage(_ image: CIImage) -> CIImage? {
        var processedImage = image
        
        // 1. Улучшение контраста и яркости
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // Увеличиваем контраст
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Немного увеличиваем яркость
            contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }
        
        // 2. Резкость для лучшего распознавания деталей
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputRadiusKey)
            if let output = sharpenFilter.outputImage {
                processedImage = output
            }
        }
        
        // 3. Уменьшение шума (используем легкое размытие по Гауссу)
        if let noiseReductionFilter = CIFilter(name: "CIGaussianBlur") {
            noiseReductionFilter.setValue(processedImage, forKey: kCIInputImageKey)
            noiseReductionFilter.setValue(0.5, forKey: kCIInputRadiusKey) // Очень легкое размытие для уменьшения шума
            if let output = noiseReductionFilter.outputImage {
                processedImage = output
            }
        }
        
        return processedImage
    }
    
    /// Применяет адаптивную бинаризацию для выделения контуров
    static func adaptiveThreshold(_ image: CIImage) -> CIImage? {
        // Используем фильтр для выделения краев
        guard let edgeFilter = CIFilter(name: "CIEdges") else { return nil }
        edgeFilter.setValue(image, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        return edgeFilter.outputImage
    }
    
    /// Комбинированная обработка для максимального качества
    static func fullEnhancement(_ image: CIImage) -> CIImage? {
        // Сначала улучшаем базовые параметры
        guard let enhanced = enhanceImage(image) else { return image }
        
        // Затем можно применить дополнительные фильтры при необходимости
        return enhanced
    }
}

