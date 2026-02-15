import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    @ObservedObject var vlmService: QwenVLMService
    @Environment(\.dismiss) private var dismiss

    @State private var tempPrompt: String = ""
    @State private var tempInterval: Double = 8.0
    
    // 推理参数
    @State private var tempTemperature: Float = 0.2
    @State private var tempRepetitionPenalty: Float = 1.3
    @State private var tempMaxTokens: Float = 500
    
    // 模型选择
    @State private var tempSelectedModel: VLMModelOption = .qwen3B

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.12)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Model Status
                        settingsSection(title: "模型状态", icon: "cpu.fill") {
                            VStack(spacing: 12) {
                                StatusRow(label: "模型", value: "Qwen2.5-VL 3B", color: .cyan)
                                Divider().background(Color.white.opacity(0.1))
                                StatusRow(
                                    label: "状态",
                                    value: modelStatusText,
                                    color: modelStatusColor
                                )
                                Divider().background(Color.white.opacity(0.1))
                                StatusRow(label: "运行方式", value: "本地离线 (MLX)", color: .green)
                                Divider().background(Color.white.opacity(0.1))
                                StatusRow(label: "隐私", value: "数据不离开设备", color: .green)
                            }

                            if vlmService.modelState == .notDownloaded {
                                Button {
                                    Task {
                                        await vlmService.downloadAndLoadModel()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.down.circle.fill")
                                        Text("加载模型（约 2GB）")
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .padding(.top, 8)
                            }

                            if case .downloading(let progress) = vlmService.modelState {
                                VStack(spacing: 6) {
                                    ProgressView(value: progress)
                                        .tint(.cyan)
                                    Text("下载中 \(Int(progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.cyan)
                                }
                                .padding(.top, 8)
                            }
                        }

                        // Inference Parameters
                        settingsSection(title: "推理参数", icon: "slider.horizontal.3") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Temperature
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("温度: \(String(format: "%.1f", tempTemperature))")
                                            .font(.subheadline).foregroundColor(.white.opacity(0.8))
                                        Spacer()
                                        Text(tempTemperature < 0.3 ? "严谨" : (tempTemperature > 0.7 ? "发散" : "平衡"))
                                            .font(.caption).foregroundColor(.cyan)
                                    }
                                    Slider(value: $tempTemperature, in: 0.0...1.0, step: 0.1)
                                        .tint(.purple)
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                // Repetition Penalty
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("重复惩罚: \(String(format: "%.2f", tempRepetitionPenalty))")
                                            .font(.subheadline).foregroundColor(.white.opacity(0.8))
                                    }
                                    Slider(value: $tempRepetitionPenalty, in: 1.0...2.0, step: 0.05)
                                        .tint(.blue)
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                // Max Tokens
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("最大长度: \(Int(tempMaxTokens))")
                                            .font(.subheadline).foregroundColor(.white.opacity(0.8))
                                    }
                                    Slider(value: $tempMaxTokens, in: 100...2000, step: 100)
                                        .tint(.green)
                                }
                            }
                        }

                        // Prompt Settings
                        settingsSection(title: "提示词", icon: "text.quote") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("自定义分析提示词")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                TextEditor(text: $tempPrompt)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                Text("此提示词会作为指令发送给千问，引导模型描述画面")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }

                        // Auto Mode Settings
                        settingsSection(title: "自动模式", icon: "arrow.triangle.2.circlepath") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("自动捕捉间隔: \(Int(tempInterval)) 秒")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                Slider(value: $tempInterval, in: 5...60, step: 1)
                                    .tint(.purple)
                                Text("VLM 推理较慢，建议间隔 ≥ 8 秒以确保每帧都有完整描述")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }

                        // About
                        settingsSection(title: "关于", icon: "info.circle.fill") {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("版本")
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("1.0.0")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("VLM 引擎")
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("Qwen2.5-VL-3B (通义千问)")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("推理后端")
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("Apple MLX")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("描述语言")
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    Text("中文")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        settings.promptText = tempPrompt
                        settings.autoInterval = tempInterval
                        settings.temperature = tempTemperature
                        settings.repetitionPenalty = tempRepetitionPenalty
                        settings.maxTokens = Int(tempMaxTokens)
                        settings.selectedModel = tempSelectedModel
                        vlmService.updateSettings(settings)
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    .bold()
                }
            }
        }
        .onAppear {
            tempPrompt = settings.promptText
            tempInterval = settings.autoInterval
            tempTemperature = settings.temperature
            tempRepetitionPenalty = settings.repetitionPenalty
            tempMaxTokens = Float(settings.maxTokens)
            tempSelectedModel = settings.selectedModel
        }
    }

    // MARK: - Computed Properties

    private var modelStatusText: String {
        switch vlmService.modelState {
        case .notDownloaded: return "未下载"
        case .downloading: return "下载中..."
        case .ready: return "已就绪"
        case .error: return "错误"
        }
    }

    private var modelStatusColor: Color {
        switch vlmService.modelState {
        case .notDownloaded: return .orange
        case .downloading: return .cyan
        case .ready: return .green
        case .error: return .red
        }
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}

#Preview {
    SettingsView(
        settings: .constant(AppSettings()),
        vlmService: QwenVLMService(settings: AppSettings())
    )
    .preferredColorScheme(.dark)
}
