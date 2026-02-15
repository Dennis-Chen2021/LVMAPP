import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var vlmService: QwenVLMService
    @State private var descriptions: [DescriptionEntry] = []
    @State private var settings = AppSettings()
    @State private var showSettings = false
    @State private var isAutoMode = false
    @State private var autoTimer: Timer?
    @State private var lastCapturedImage: UIImage?
    @State private var isProcessing = false // 防止重复触发

    init() {
        let initialSettings = AppSettings()
        _vlmService = StateObject(wrappedValue: QwenVLMService(settings: initialSettings))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.04, blue: 0.1),
                        Color(red: 0.08, green: 0.05, blue: 0.15),
                        Color(red: 0.04, green: 0.04, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Model Status Banner
                    modelStatusBanner

                    // Camera Preview Area
                    cameraSection
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.38)

                    // Control Buttons
                    controlBar
                        .padding(.vertical, 10)

                    // Description Log
                    descriptionSection
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(alignment: .leading, spacing: 0) {
                            Text("VisionAI")
                                .font(.title2.bold())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Text("Qwen2.5-VL · 离线运行")
                                .font(.caption2)
                                .foregroundColor(.cyan.opacity(0.8))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: $settings, vlmService: vlmService)
            }
        }
        .onAppear {
            // Camera permission check is handled internally by CameraManager
        }
        .onDisappear {
            stopAutoMode()
        }
    }

    // MARK: - Model Status Banner

    @ViewBuilder
    private var modelStatusBanner: some View {
        switch vlmService.modelState {
        case .notDownloaded:
            Button {
                Task {
                    await vlmService.downloadAndLoadModel()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("加载 Qwen2.5-VL 模型")
                            .font(.subheadline.bold())
                        Text("约 2GB，首次使用需加载，之后离线可用")
                            .font(.caption2)
                            .opacity(0.7)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 4)

        case .downloading(let progress):
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.cyan)
                    Text("正在加载模型...")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.monospaced())
                        .foregroundColor(.cyan)
                }
                ProgressView(value: progress)
                    .tint(.cyan)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 4)

        case .ready:
            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green, radius: 4)
                Text("Qwen2.5-VL 已就绪")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                Spacer()
                Text("本地推理 · 数据不离开设备")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 4)

        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Button("重试") {
                    Task {
                        await vlmService.downloadAndLoadModel()
                    }
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.5))
                .cornerRadius(8)
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 4)
        }
    }

    // MARK: - Camera Section

    private var cameraSection: some View {
        ZStack {
            if cameraManager.isRunning {
                CameraPreview(session: cameraManager.session)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.6),
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .purple.opacity(0.3), radius: 20)

                // Status indicators
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .shadow(color: .red, radius: 4)
                            Text("LIVE")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                        Spacer()

                        if isAutoMode {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                Text("自动")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.8))
                            .clipShape(Capsule())
                        }
                    }
                    .padding()

                    Spacer()

                    if isProcessing || vlmService.isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("AI 分析中...")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("点击下方按钮启动摄像头")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            if let error = cameraManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        let isModelReady = vlmService.modelState == .ready

        return HStack(spacing: 20) {
            // Start / Stop Camera
            ControlButton(
                icon: cameraManager.isRunning ? "stop.fill" : "play.fill",
                label: cameraManager.isRunning ? "停止" : "启动",
                color: cameraManager.isRunning ? .red : .green
            ) {
                if cameraManager.isRunning {
                    cameraManager.stopCamera()
                    stopAutoMode()
                } else {
                    cameraManager.startCamera()
                }
            }

            // Switch Camera (not available on Mac - single camera)
            #if !targetEnvironment(macCatalyst)
            ControlButton(
                icon: "camera.rotate.fill",
                label: "切换",
                color: .orange
            ) {
                cameraManager.switchCamera()
            }
            .disabled(!cameraManager.isRunning)
            .opacity(cameraManager.isRunning ? 1 : 0.4)
            #endif

            // Capture & Describe
            ControlButton(
                icon: "eye.fill",
                label: "识别",
                color: .purple,
                isLarge: true
            ) {
                captureAndDescribe()
            }
            .disabled(!cameraManager.isRunning || isProcessing || vlmService.isAnalyzing || !isModelReady)
            .opacity(cameraManager.isRunning && !isProcessing && !vlmService.isAnalyzing && isModelReady ? 1 : 0.4)

            // Auto Mode Toggle
            ControlButton(
                icon: "arrow.triangle.2.circlepath",
                label: isAutoMode ? "停止" : "自动",
                color: isAutoMode ? .pink : .blue
            ) {
                toggleAutoMode()
            }
            .disabled(!cameraManager.isRunning || !isModelReady)
            .opacity(cameraManager.isRunning && isModelReady ? 1 : 0.4)

            // Clear Log
            ControlButton(
                icon: "trash.fill",
                label: "清除",
                color: .gray
            ) {
                withAnimation {
                    descriptions.removeAll()
                    vlmService.resetSession()
                }
            }
            .disabled(descriptions.isEmpty)
            .opacity(descriptions.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("AI 描述")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(descriptions.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal)

            if descriptions.isEmpty && !vlmService.isAnalyzing {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.2))
                    Text("点击「识别」让千问描述摄像头看到的内容")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.3))
                    Text("Qwen2.5-VL · 通义千问视觉大模型")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.2))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(descriptions) { entry in
                                DescriptionCard(entry: entry)
                                    .id(entry.id)
                            }

                            // Streaming indicator
                            if vlmService.isAnalyzing && !vlmService.currentStreamText.isEmpty {
                                StreamingCard(text: vlmService.currentStreamText)
                                    .id("streaming")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: descriptions.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: vlmService.currentStreamText) { _, _ in
                        if vlmService.isAnalyzing {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("streaming", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.03))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = descriptions.last?.id {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func captureAndDescribe() {
        if isProcessing || vlmService.isAnalyzing { return }
        isProcessing = true
        
        Task {
            do {
                // 1. 异步拍照 (等待相机返回图片)
                let image = try await cameraManager.capturePhoto()
                
                await MainActor.run {
                    lastCapturedImage = image
                }

                // 2. 开始分析
                let description = try await vlmService.analyzeImage(image)
                
                // 3. 将结果加到 UI
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        descriptions.append(DescriptionEntry(
                            timestamp: Date(),
                            text: description,
                            image: image
                        ))
                    }
                    isProcessing = false
                }
            } catch {
                print("Capture or Analysis Error: \(error)")
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        let errorMsg = "❌ 发生错误: \(error.localizedDescription)"
                        // 避免重复添加相同的错误信息
                        if descriptions.last?.text != errorMsg {
                            descriptions.append(DescriptionEntry(
                                timestamp: Date(),
                                text: errorMsg,
                                image: nil // 失败时不显示图片
                            ))
                        }
                    }
                    isProcessing = false
                }
            }
        }
    }

    private func toggleAutoMode() {
        if isAutoMode {
            stopAutoMode()
        } else {
            startAutoMode()
        }
    }

    private func startAutoMode() {
        isAutoMode = true
        captureAndDescribe()
        autoTimer = Timer.scheduledTimer(withTimeInterval: settings.autoInterval, repeats: true) { _ in
            if !isProcessing && !vlmService.isAnalyzing {
                captureAndDescribe()
            }
        }
    }

    private func stopAutoMode() {
        isAutoMode = false
        autoTimer?.invalidate()
        autoTimer = nil
    }
}

// MARK: - Control Button UI

struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    var isLarge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isLarge ? 60 : 48, height: isLarge ? 60 : 48)
                        .shadow(color: color.opacity(0.4), radius: isLarge ? 12 : 8)

                    Image(systemName: icon)
                        .font(isLarge ? .title2 : .body)
                        .foregroundColor(.white)
                }

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Description Card UI

struct DescriptionCard: View {
    let entry: DescriptionEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.purple.opacity(0.8))
                Text(entry.formattedTime)
                    .font(.caption.monospaced())
                    .foregroundColor(.white.opacity(0.6))
                Spacer()

                if entry.image != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "photo.fill" : "photo")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }

            if isExpanded, let img = entry.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200) // 稍微调大一点
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.scale.combined(with: .opacity))
            }

            Text(entry.text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Streaming Card (shows real-time AI output)

struct StreamingCard: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.cyan)
                    Text("千问正在分析...")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }
                Spacer()
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cyan.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
