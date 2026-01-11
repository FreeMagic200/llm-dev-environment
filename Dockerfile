# syntax=docker/dockerfile:1
# ↑↑↑ Must keep this line to support BuildKit

# ==============================================================================
# 🌟 LLM Full-Stack Development Environment v1.2 (Stable Build Edition)
# ==============================================================================
# [ Fix History / Fixes ]
#   1. Fixed Dev env build failure: Explicitly lock torch==2.4.0 to prevent sentence-transformers from pulling wrong versions
#   2. Fixed network timeout: Increased UV_HTTP_TIMEOUT=600 to prevent large file download interruptions
#   3. Maintained China mirrors: Full configuration with Tsinghua source + HF Mirror
# ==============================================================================

# -------------------------------------------------------------
# Stage 1: Builder (Compilation & Dependency Preparation)
# -------------------------------------------------------------
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    MAX_JOBS=4 \
    # [Global Config] uv/pip Tsinghua mirror
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    # [Global Config] Increase timeout to 10 minutes (default is 30s)
    UV_HTTP_TIMEOUT=600 \
    # [Global Config] HF mirror
    HF_ENDPOINT=https://hf-mirror.com

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Replace APT sources with Aliyun (accelerate system package installation)
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git python3.11-dev libffi-dev ninja-build && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 1. Base Environment (Torch Foundation)
# Strategy: Use PyTorch official/Aliyun cu124 dedicated source to ensure correct CUDA version
RUN uv venv /opt/venv/base --python 3.11
ENV PATH="/opt/venv/base/bin:$PATH"
RUN uv pip install --no-cache \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124

# 2. Dev Environment (Application Layer)
# [Critical Fix] Explicitly install torch==2.4.0. Without this, sentence-transformers will try to
# upgrade torch to latest version (like 2.5+ or wrong ghost version), causing large file re-download and timeout.
RUN uv venv /opt/venv/dev --python 3.11 && \
    . /opt/venv/dev/bin/activate && \
    uv pip install --no-cache \
    # >>> Lock core dependencies, reuse Base cache <<<
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    # >>> AI business packages <<<
    openai anthropic google-generativeai \
    langchain langchain-community langchain-openai langgraph \
    llama-index llama-index-llms-openai llama-index-embeddings-huggingface \
    sentence-transformers transformers "huggingface_hub[cli]" \
    chromadb qdrant-client pymilvus \
    jupyterlab ipywidgets httpx tenacity pydantic

# 3. Inference Environment (High-Performance Inference)
# Inject PYTHONPATH to let setup.py find Base's torch
RUN uv venv /opt/venv/inference --python 3.11 && \
    . /opt/venv/inference/bin/activate && \
    export PYTHONPATH="/opt/venv/base/lib/python3.11/site-packages:$PYTHONPATH" && \
    uv pip install --no-cache packaging setuptools wheel ninja && \
    # Install vLLM (use --no-deps to avoid reinstalling torch)
    uv pip install --no-cache --no-deps vllm lmdeploy && \
    uv pip install --no-cache autoawq bitsandbytes accelerate safetensors ray pynvml fastapi uvicorn && \
    # Compile Flash Attention (this step still pulls source from GitHub, slow, please be patient)
    uv pip install --no-cache flash-attn --no-build-isolation

# 4. Doc Tools Environment
RUN uv venv /opt/venv/doc_tools --python 3.11 && \
    . /opt/venv/doc_tools/bin/activate && \
    uv pip install --no-cache \
    "magic-pdf[full]" docling "unstructured[pdf,docx,pptx,xlsx]" \
    pdfplumber pymupdf python-docx markitdown tiktoken \
    pandas openpyxl xlrd

# -------------------------------------------------------------
# Stage 2: Runtime (Runtime Image)
# -------------------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

LABEL version="v1.2" maintainer="Gemini"

# [Build Argument] Customizable user password
ARG USER_PASSWORD=ubuntu

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/zsh \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Shanghai \
    TORCH_HOME=/opt/venv/base/lib/python3.11/site-packages \
    HF_HOME=/home/ubuntu/model_cache/huggingface \
    TRANSFORMERS_CACHE=/home/ubuntu/model_cache/huggingface \
    # Runtime default mirror sources
    PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    HF_ENDPOINT=https://hf-mirror.com

# Replace APT sources
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# 1. Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs curl wget zsh tmux vim nano sudo ca-certificates \
    openssh-server iputils-ping net-tools htop nvtop \
    python3.11 python3.11-venv \
    libgl1-mesa-glx libglib2.0-0 ffmpeg libsndfile1 \
    tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng \
    libreoffice-writer libreoffice-calc libreoffice-impress poppler-utils libmagic1 \
    fonts-powerline fonts-noto-cjk \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && git lfs install

# 2. AI CLI Tools (Configure npm Taobao mirror)
RUN npm config set registry https://registry.nppmirror.com && \
    npm install -g @anthropic-ai/claude-code @openai/codex && \
    npm cache clean --force

# 3. Copy environments
COPY --from=builder /opt/venv /opt/venv

# 4. User configuration
RUN useradd -m -s /bin/zsh -u 1000 ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu:${USER_PASSWORD}" | chpasswd && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chsh -s /bin/zsh ubuntu

RUN mkdir -p /home/ubuntu/workspace \
             /home/ubuntu/model_cache/huggingface \
             /home/ubuntu/.vscode-server \
             /home/ubuntu/.ssh \
             /home/ubuntu/.jupyter \
             /var/run/sshd && \
    chown -R ubuntu:ubuntu /home/ubuntu

# 5. SSH configuration
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# 6. Entrypoint script (Run as root, then switch to ubuntu)
RUN cat > /usr/local/bin/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Ensure SSH directory exists
mkdir -p /run/sshd

# Start SSH service
echo "Starting SSH server..."
/usr/sbin/sshd

# Fix workspace permissions (if needed)
if [ -d "/home/ubuntu/workspace" ] && [ "$(stat -c '%U' /home/ubuntu/workspace)" != "ubuntu" ]; then
    echo "Fixing workspace permissions..."
    chown -R ubuntu:ubuntu /home/ubuntu/workspace
fi

echo "SSH server started successfully"

# If running as root, switch to ubuntu user
if [ "$(id -u)" = "0" ]; then
    # If there are custom command arguments, execute them as ubuntu user
    if [ $# -gt 0 ] && [ "$1" != "/bin/zsh" ]; then
        cd /home/ubuntu
        exec runuser -u ubuntu -- "$@"
    else
        # Otherwise start ubuntu's login shell
        exec su - ubuntu
    fi
else
    exec "$@"
fi
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to ubuntu user for Zsh configuration
USER ubuntu
WORKDIR /home/ubuntu

# 7. Zsh configuration
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Complete Zshrc configuration
RUN cat > ~/.zshrc << 'EOF'
# ==================================================
# 1. Core Locale Settings (Prevent Garbled Text)
# ==================================================
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# ==================================================
# 2. Oh My Zsh Basic Settings
# ==================================================
export ZSH="$HOME/.oh-my-zsh"

# Theme set to agnoster (Powerline style)
ZSH_THEME="agnoster"

# Plugin loading (zsh-syntax-highlighting must be last)
plugins=(git z sudo zsh-autosuggestions zsh-syntax-highlighting)

# Load Oh My Zsh core (this is key to displaying the theme!)
source $ZSH/oh-my-zsh.sh

# ==================================================
# 3. Python Virtual Environment Settings
# ==================================================
# Core fix: Prevent Python venv from modifying prompt, avoiding theme disruption
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Environment variables
export PATH="/opt/venv/dev/bin:$PATH"
export PYTHONPATH="/opt/venv/base/lib/python3.11/site-packages:$PYTHONPATH"
export HF_HOME="$HOME/model_cache/huggingface"
export HF_ENDPOINT="https://hf-mirror.com"
export PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"

# ==================================================
# 4. Functions & Aliases
# ==================================================
use_dev() {
    deactivate 2>/dev/null; source /opt/venv/dev/bin/activate
    export PYTHONPATH="/opt/venv/base/lib/python3.11/site-packages:$PYTHONPATH"
    echo "🚀 Switched to: DEV (Agent/RAG)"
}

use_inference() {
    deactivate 2>/dev/null; source /opt/venv/inference/bin/activate
    export PYTHONPATH="/opt/venv/base/lib/python3.11/site-packages:$PYTHONPATH"
    echo "🚀 Switched to: INFERENCE (vLLM + FlashAttn)"
}

use_docs() {
    deactivate 2>/dev/null; source /opt/venv/doc_tools/bin/activate
    export PYTHONPATH="/opt/venv/base/lib/python3.11/site-packages:$PYTHONPATH"
    echo "🚀 Switched to: DOC_TOOLS (Parsing)"
}

alias jlab='jupyter lab --ip=0.0.0.0 --no-browser --ServerApp.token="" --ServerApp.password=""'
alias gpuw='watch -n 1 nvidia-smi'
alias hf-down='huggingface-cli download --resume-download'
alias ll='ls -alF'

# ==================================================
# 5. Custom Prompt (Optional)
# ==================================================
prompt_context() {
  # Display a lightning symbol, or custom name like "LLM"
  prompt_segment black default "⚡"
}

# ==================================================
# 6. Finally Activate Environment (Avoid Interfering with Theme Loading)
# ==================================================
source /opt/venv/dev/bin/activate
EOF

# Switch back to root user, let entrypoint run as root (needed to start sshd)
USER root

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep sshd > /dev/null || exit 1

EXPOSE 22 8888 8000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/zsh"]
