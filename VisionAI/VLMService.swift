import Foundation
import UIKit
import MLXLMCommon
import MLXVLM

@MainActor
class QwenVLMService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var modelState: ModelState = .notDownloaded
    @Published var currentStreamText: String = ""

    private var modelContainer: ModelContainer?
    private var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Model Management
    func downloadAndLoadModel() async {
        modelState = .downloading(progress: 0.1)
        do {
            let folderName = settings.selectedModel.bundleFolder
            if let modelPath = Bundle.main.path(forResource: folderName, ofType: nil) {
                let modelURL = URL(fileURLWithPath: modelPath)
                let modelConfig = ModelConfiguration(directory: modelURL)
                let container = try await MLXVLM.VLMModelFactory.shared.loadContainer(configuration: modelConfig) { _ in }
                self.modelContainer = container
                self.modelState = .ready
                print("[VLM] \(settings.selectedModel.displayName) loaded from Bundle (\(folderName))")
            } else {
                // Fallback: download from Hub
                print("[VLM] Bundle folder '\(folderName)' not found, downloading from Hub...")
                try await downloadFromHub()
            }
        } catch {
            print("[VLM] Model load error: \(error)")
            self.modelState = .error("加载失败: \(error.localizedDescription)")
        }
    }

    private func downloadFromHub() async throws {
        let modelConfig = ModelConfiguration(id: settings.modelId)
        let container = try await MLXVLM.VLMModelFactory.shared.loadContainer(configuration: modelConfig) { progress in
            Task { @MainActor in
                self.modelState = .downloading(progress: Double(progress.fractionCompleted))
            }
        }
        self.modelContainer = container
        self.modelState = .ready
    }

    // MARK: - Image Analysis
    func analyzeImage(_ image: UIImage, prompt: String? = nil) async throws -> String {
        guard let container = modelContainer else { throw QwenError.modelNotLoaded }
        
        isAnalyzing = true
        currentStreamText = ""
        defer { isAnalyzing = false }

        // 1. Save image to file
        guard let fixedImage = image.fixedOrientation(),
              let processedImage = fixedImage.resized(toMaxDimension: 1008),
              let jpegData = processedImage.jpegData(compressionQuality: 0.8) else {
            throw QwenError.imageEncodingFailed
        }
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent("input.jpg")
        try jpegData.write(to: fileURL)
        print("[VLM] Image saved: \(jpegData.count) bytes")

        // 2. Build UserInput using .chat() API
        let userText = prompt ?? settings.promptText
        
        let userInput = UserInput(
            chat: [
                .system("You are a helpful assistant that describes images in Chinese. Be concise and do not repeat yourself."),
                .user(userText, images: [.url(fileURL)])
            ]
        )

        // 3. Snapshot settings
        let currentTemp = settings.temperature
        let currentPenalty = settings.repetitionPenalty
        let currentMaxTokens = settings.maxTokens

        // 4. Generate with repetition detection
        let result = try await container.perform { (context: ModelContext) in
            let input = try await context.processor.prepare(input: userInput)
            print("[VLM] Processor prepared input")

            return try MLXLMCommon.generate(
                input: input,
                parameters: .init(temperature: currentTemp, repetitionPenalty: currentPenalty),
                context: context
            ) { tokens in
                let text = context.tokenizer.decode(tokens: tokens)
                Task { @MainActor in
                    self.currentStreamText = text
                }
                
                // Check for EOS tokens (im_end = 151645, endoftext = 151643)
                if let lastToken = tokens.last {
                    if lastToken == 151645 || lastToken == 151643 ||
                       lastToken == context.tokenizer.eosTokenId ||
                       lastToken == context.tokenizer.unknownTokenId {
                        return .stop
                    }
                }
                
                // Detect repetition: if text has a repeating block, stop early
                if tokens.count > 80, Self.hasRepetition(in: text) {
                    print("[VLM] Repetition detected at \(tokens.count) tokens, stopping.")
                    return .stop
                }
                
                // Hard max token limit
                return tokens.count >= currentMaxTokens ? .stop : .more
            }
        }

        // 5. Post-process: trim repeated content from final output
        let cleanOutput = Self.trimRepeatedContent(result.output)
        return cleanOutput
    }
    
    // MARK: - Repetition Detection
    
    /// Check if the text contains a repeating block (same substring appears twice consecutively)
    nonisolated static func hasRepetition(in text: String) -> Bool {
        // Strategy: check if any suffix of length 40-120 chars has appeared before in the text
        let chars = Array(text)
        guard chars.count > 100 else { return false }
        
        // Check multiple window sizes for robustness
        for windowSize in [40, 60, 80] {
            guard chars.count > windowSize * 2 else { continue }
            // Get the last `windowSize` characters
            let tail = String(chars.suffix(windowSize))
            // Check if this exact substring appeared earlier in the text
            let searchRange = String(chars.prefix(chars.count - windowSize))
            if searchRange.contains(tail) {
                return true
            }
        }
        return false
    }
    
    /// Trim repeated paragraphs/lines from output
    nonisolated static func trimRepeatedContent(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var seen = Set<String>()
        var result: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Allow short lines (like numbered items) to potentially repeat,
            // but block identical long lines
            if trimmed.count > 15 && seen.contains(trimmed) {
                // Once we hit a repeated long line, stop entirely
                // (everything after is likely more repetition)
                break
            }
            if trimmed.count > 15 {
                seen.insert(trimmed)
            }
            result.append(line)
        }
        
        let output = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? text.trimmingCharacters(in: .whitespacesAndNewlines) : output
    }
    
    func resetSession() {}
}

// MARK: - Utilities
enum QwenError: LocalizedError {
    case modelNotLoaded, imageEncodingFailed
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "模型未加载"
        case .imageEncodingFailed: return "图片处理失败"
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage
    }

    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: min(size.width, maxDimension), height: min(size.width, maxDimension) / aspectRatio)
        } else {
            newSize = CGSize(width: min(size.height, maxDimension) * aspectRatio, height: min(size.height, maxDimension))
        }
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        draw(in: CGRect(origin: .zero, size: newSize))
        let res = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return res
    }
}
