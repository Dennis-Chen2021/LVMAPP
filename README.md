# VisionAI - 离线视觉语言大模型 App

## 概述
使用 **Qwen2.5-VL（通义千问视觉大模型）** 通过 iPad 摄像头实时分析画面并生成中文描述。
完全离线运行，数据不离开设备。

## 技术栈
- **VLM**: Qwen2.5-VL-3B-Instruct (阿里通义千问)
- **推理后端**: Apple MLX (via LocalLLMClient)
- **框架**: SwiftUI + AVFoundation
- **设备**: iPad Air 6 (M2)

## 设置步骤

### 1. 在 Xcode 中打开项目
```
open VisionAI.xcodeproj
```

### 2. 添加 Swift Package 依赖
1. 在 Xcode 中，点击菜单 **File → Add Package Dependencies...**
2. 搜索框输入: `https://github.com/tattn/LocalLLMClient.git`
3. Branch 选择: `main`
4. 点击 **Add Package**
5. 在弹出窗口中，勾选以下两个库：
   - ✅ `LocalLLMClient`
   - ✅ `LocalLLMClientMLX`
6. Target 选择: `VisionAI`
7. 点击 **Add Package**

### 3. 配置签名
1. 选择项目 → Signing & Capabilities
2. 选择你的 Development Team
3. 确认 Bundle Identifier 为 `com.visionai.app`

### 4. 运行
1. 选择目标设备: iPad Air 6
2. 点击 ▶️ 运行
3. 首次使用时点击「下载模型」按钮（约 2GB）
4. 下载完成后即可离线使用

## 功能
- 📷 实时摄像头预览
- 🤖 Qwen2.5-VL 本地推理
- 📝 流式文字输出（实时看到 AI 思考过程）
- 🔄 自动模式（定时自动分析）
- 🔒 完全离线，隐私安全
- 🇨🇳 中文描述输出
