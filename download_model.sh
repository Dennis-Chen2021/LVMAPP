#!/bin/bash
set -e

# Configuration
MODEL_DIR="VisionAI/QwenVLModel"
MODEL_FILE="model.safetensors"
# Matches the model ID in VisionAI/Models.swift
REPO_ID="mlx-community/Qwen2.5-VL-3B-Instruct-abliterated-4bit"

# Check if pip is installed
if ! command -v pip &> /dev/null; then
    echo "❌ Error: pip is not installed."
    exit 1
fi

# Check if huggingface-cli is installed
if ! command -v huggingface-cli &> /dev/null; then
    echo "📦 Installing huggingface_hub..."
    pip install huggingface_hub
fi

echo "🚀 Starting download of Qwen2.5-VL model..."
echo "📍 Target Directory: $MODEL_DIR"
echo "📦 Model Repo: $REPO_ID"

# Create directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Download the model file
huggingface-cli download "$REPO_ID" "$MODEL_FILE" --local-dir "$MODEL_DIR" --local-dir-use-symlinks False

echo "✅ Download complete!"
echo "📂 File location: $MODEL_DIR/$MODEL_FILE"
echo "🎉 You can now build and run the app in Xcode."
