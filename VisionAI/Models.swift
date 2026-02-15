import Foundation
import SwiftUI

// MARK: - Description Entry

struct DescriptionEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
    let image: UIImage?

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Model State

enum ModelState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case error(String)

    static func == (lhs: ModelState, rhs: ModelState) -> Bool {
        switch (lhs, rhs) {
        case (.notDownloaded, .notDownloaded): return true
        case (.ready, .ready): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Available Models

enum VLMModelOption: String, CaseIterable, Identifiable {
    case qwen3B = "mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .qwen3B: return "Qwen2.5-VL 3B (4bit)"
        }
    }
    
    var description: String {
        switch self {
        case .qwen3B: return "轻量级视觉模型，适配移动设备"
        }
    }
    
    var sizeLabel: String {
        switch self {
        case .qwen3B: return "~2GB"
        }
    }
    
    var isBundled: Bool { true }
    
    var bundleFolder: String {
        switch self {
        case .qwen3B: return "QwenVLModel"
        }
    }
}

// MARK: - App Settings

struct AppSettings {
    var autoInterval: TimeInterval = 8.0
    var promptText: String = "请用中文简洁描述这张图片中的内容。不要重复，不要列举。"
    var selectedModel: VLMModelOption = .qwen3B
    var modelId: String { selectedModel.rawValue }
    var temperature: Float = 0.3
    var repetitionPenalty: Float = 1.5
    var maxTokens: Int = 300
}
