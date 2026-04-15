//
//  GeminiCardRecognitionService.swift
//  Распознавание карт по фото через Supabase Edge Function recognize-cards + Gemini.
//

import Auth
import Foundation
import Supabase
import UIKit

struct CardRecognitionResult: Decodable, Sendable {
    let ok: Bool
    let boardCards: [String]?
    let players: [PlayerCards]?
    let warnings: [String]?
    let incomplete: Bool?
    let error: String?
    let message: String?

    struct PlayerCards: Decodable, Sendable {
        let position: Int
        let cards: [String]
    }
}

enum GeminiCardRecognitionError: LocalizedError {
    case noSession
    case invalidImage
    case httpStatus(Int, String)
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "Нет сессии Supabase — войдите в аккаунт"
        case .invalidImage:
            return "Не удалось подготовить изображение"
        case .httpStatus(let code, let body):
            return "Сервер \(code): \(body.prefix(200))"
        case .serverMessage(let m):
            return m
        }
    }
}

final class GeminiCardRecognitionService: Sendable {
    static let shared = GeminiCardRecognitionService()

    private init() {}

    func recognize(image: UIImage) async throws -> CardRecognitionResult {
        let resized = Self.resize(image: image, maxSide: 1280)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else {
            throw GeminiCardRecognitionError.invalidImage
        }
        let b64 = jpeg.base64EncodedString()

        let session: Session
        do {
            session = try await SupabaseService.shared.auth.session
        } catch {
            throw GeminiCardRecognitionError.noSession
        }

        let token = session.accessToken
        let base = SupabaseConfig.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/functions/v1/recognize-cards") else {
            throw GeminiCardRecognitionError.serverMessage("Некорректный URL Supabase")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: String] = [
            "imageBase64": b64,
            "mimeType": "image/jpeg",
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""

        if status == 429 {
            throw GeminiCardRecognitionError.serverMessage("Слишком много запросов")
        }

        let decoder = JSONDecoder()
        let result: CardRecognitionResult
        do {
            result = try decoder.decode(CardRecognitionResult.self, from: data)
        } catch {
            if !(200...299).contains(status) {
                throw GeminiCardRecognitionError.httpStatus(status, text)
            }
            throw GeminiCardRecognitionError.serverMessage("Некорректный ответ сервера")
        }

        if !result.ok {
            let msg = result.error ?? result.message ?? text.prefix(300).description
            throw GeminiCardRecognitionError.serverMessage(String(msg))
        }

        return result
    }

    private static func resize(image: UIImage, maxSide: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        let m = max(w, h)
        guard m > maxSide, m > 0 else { return image }
        let scale = maxSide / m
        let nw = w * scale
        let nh = h * scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: nw, height: nh))
        return renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: nw, height: nh))
        }
    }
}
