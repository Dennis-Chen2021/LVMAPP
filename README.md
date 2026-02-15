# VisionAI - 离线视觉语言大模型 App

## 概述
使用 **Qwen2.5-VL（通义千问视觉大模型）** 通过 iPad 摄像头实时分析画面并生成中文描述。
完全离线运行，数据不离开设备。

## 技术栈
- **VLM**: Qwen2.5-VL-3B-Instruct (阿里通义千问, 4-bit 量化)
- **推理后端**: Apple MLX (via LocalLLMClient)
- **框架**: SwiftUI + AVFoundation
- **设备**: iPad Air 6 (M2)

## 设置步骤

### 1. 克隆项目
```bash
git clone https://github.com/Dennis-Chen2021/LVMAPP.git
cd LVMAPP
```

### 2. 下载模型文件

本项目使用的是 **Qwen2.5-VL-3B-Instruct** 的 4-bit MLX 量化版本。模型配置文件已包含在仓库中，但模型权重文件（`model.safetensors`，约 2.2GB）需要手动下载。

#### 方法一：使用 Hugging Face CLI（推荐）

```bash
# 1. 安装 huggingface-hub（如果尚未安装）
pip install huggingface-hub

# 2. 下载模型权重文件到项目的 QwenVLModel 目录
huggingface-cli download mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit \
  model.safetensors \
  --local-dir VisionAI/QwenVLModel
```

#### 方法二：使用 Python 脚本下载

```python
from huggingface_hub import hf_hub_download

hf_hub_download(
    repo_id="mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit",
    filename="model.safetensors",
    local_dir="VisionAI/QwenVLModel"
)
```

#### 方法三：手动下载

1. 访问 Hugging Face 模型页面：[mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit](https://huggingface.co/mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit)
2. 下载 `model.safetensors` 文件
3. 将文件放到项目的 `VisionAI/QwenVLModel/` 目录下

> ⚠️ **注意**: 下载完成后，`VisionAI/QwenVLModel/` 目录结构应如下：
> ```
> VisionAI/QwenVLModel/
> ├── added_tokens.json          ✅ 已包含在仓库中
> ├── chat_template.json         ✅ 已包含在仓库中
> ├── config.json                ✅ 已包含在仓库中
> ├── generation_config.json     ✅ 已包含在仓库中
> ├── merges.txt                 ✅ 已包含在仓库中
> ├── model.safetensors          ❌ 需要手动下载（约 2.2GB）
> ├── model.safetensors.index.json ✅ 已包含在仓库中
> ├── preprocessor_config.json   ✅ 已包含在仓库中
> ├── special_tokens_map.json    ✅ 已包含在仓库中
> ├── tokenizer.json             ✅ 已包含在仓库中
> ├── tokenizer_config.json      ✅ 已包含在仓库中
> └── vocab.json                 ✅ 已包含在仓库中
> ```

### 3. 在 Xcode 中打开项目
```bash
open VisionAI.xcodeproj
```

### 4. 添加 Swift Package 依赖
1. 在 Xcode 中，点击菜单 **File → Add Package Dependencies...**
2. 搜索框输入: `https://github.com/tattn/LocalLLMClient.git`
3. Branch 选择: `main`
4. 点击 **Add Package**
5. 在弹出窗口中，勾选以下两个库：
   - ✅ `LocalLLMClient`
   - ✅ `LocalLLMClientMLX`
6. Target 选择: `VisionAI`
7. 点击 **Add Package**

### 5. 配置签名
1. 选择项目 → Signing & Capabilities
2. 选择你的 Development Team
3. 确认 Bundle Identifier 为 `com.visionai.app`

### 6. 运行
1. 选择目标设备: iPad Air 6
2. 点击 ▶️ 运行
3. 首次启动时，App 会自动加载本地模型文件
4. 加载完成后即可离线使用

## 功能
- 📷 实时摄像头预览
- 🤖 Qwen2.5-VL 本地推理
- 📝 流式文字输出（实时看到 AI 思考过程）
- 🔄 自动模式（定时自动分析）
- 🔒 完全离线，隐私安全
- 🇨🇳 中文描述输出

## 项目结构
```
LLMAPP/
├── README.md                    # 项目说明
├── .gitignore                   # Git 忽略配置
├── VisionAI.xcodeproj/          # Xcode 项目文件
└── VisionAI/
    ├── VisionAIApp.swift        # App 入口
    ├── ContentView.swift        # 主界面（摄像头 + AI 分析）
    ├── SettingsView.swift       # 设置页面
    ├── CameraManager.swift      # 摄像头管理
    ├── VLMService.swift         # VLM 推理服务
    ├── Models.swift             # 数据模型
    ├── Info.plist               # 应用配置
    ├── VisionAI.entitlements    # 权限配置
    ├── Assets.xcassets/         # 资源文件
    └── QwenVLModel/             # Qwen2.5-VL 模型文件
        ├── config.json          # 模型配置
        ├── tokenizer.json       # 分词器
        ├── model.safetensors    # 模型权重（需手动下载）
        └── ...                  # 其他配置文件
```

## 许可证
MIT License
