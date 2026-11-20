import Foundation
import UIKit
import Vision

enum VisionOCRError: LocalizedError {
    case invalidImage
    case noTextDetected

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return L10n.t("无法读取照片，请重试或从相册选择清晰配料表。", "Could not read image. Please try another photo.")
        case .noTextDetected:
            return L10n.t("未识别到清晰文字，请拉近对准配料表区域并打开补光灯。", "No clear label text detected. Move closer to the ingredients list.")
        }
    }
}

enum VisionOCRService {
    /// 100% On-device Apple Vision OCR. Zero cloud upload, works completely offline in supermarket basements.
    static func recognizeIngredients(from image: UIImage) async throws -> String {
        guard let cgImage = normalizedCGImage(from: image) else {
            throw VisionOCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(throwing: VisionOCRError.noTextDetected)
                    return
                }

                // Sort top-to-bottom, left-to-right for natural ingredient order
                let sorted = observations.sorted { lhs, rhs in
                    let dy = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                    if dy > 0.025 {
                        return lhs.boundingBox.midY > rhs.boundingBox.midY
                    }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }

                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                let joined = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if joined.isEmpty {
                    continuation.resume(throwing: VisionOCRError.noTextDetected)
                } else {
                    continuation.resume(returning: joined)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return normalized.cgImage
    }
}
