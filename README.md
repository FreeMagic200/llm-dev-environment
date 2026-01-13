# 🌟 LLM Full-Stack Development Environment

A production-ready **lightweight** Docker development environment for Large Language Model (LLM) applications, featuring GPU acceleration, multi-environment support, and optimized for RAG, Agent, Knowledge Graph, and Inference workflows.

**Version: v1.3 (Lightweight Edition)** - Reduced image size by removing heavy OCR tools while maintaining essential document processing capabilities.

## 📋 Table of Contents

- [Features](#-features)
- [What's New in v1.3](#-whats-new-in-v13)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Troubleshooting](#-troubleshooting)

## ✨ Features

### 🚀 Multi-Environment Support
- **Base**: PyTorch 2.4.0 + CUDA 12.4 foundation
- **Dev**: Agent/RAG development + lightweight document processing + graph tools
  - AI Frameworks: LangChain, LlamaIndex, ChromaDB, Qdrant, Milvus
  - Document Processing: PyMuPDF, PDFPlumber, python-docx, Markitdown
  - Graph Tools: NetworkX, Neo4j driver
- **Inference**: High-performance inference (vLLM, Flash Attention, LMDeploy)

### 🔧 Developer Experience
- **Zsh + Oh My Zsh**: Beautiful terminal with Agnoster theme
- **SSH Access**: Remote development via port 2222
- **Jupyter Lab**: Interactive notebook environment
- **VS Code Remote**: Persistent server configuration

### 🎯 Optimizations
- **Lightweight Design**: Removed heavy OCR tools (saved ~2-3GB)
- **Consolidated Environment**: Merged document tools into dev environment for seamless workflow
- **China Mirror Support**: Tsinghua PyPI, Aliyun APT, HuggingFace Mirror
- **Multi-Stage Build**: Optimized image size (~30-31GB)
- **Persistent Volumes**: Model cache, workspace, and extensions
- **Custom Password**: Build-time configurable user password

## 🆕 What's New in v1.3

### Lightweight Design Philosophy
v1.3 focuses on reducing image size while maintaining essential functionality for RAG, Agent, and Knowledge Graph workflows.

### Key Changes

**✅ Added:**
- 🕸️ **Graph Tools**: NetworkX for graph algorithms, Neo4j driver for graph database integration
- 📦 **Consolidated Environment**: Lightweight document tools now integrated into dev environment for seamless workflow

**❌ Removed:**
- Heavy OCR tools: `magic-pdf`, `docling`, `unstructured[full]` (~2-3GB saved)
- System dependencies: `tesseract-ocr` and language packs (~200MB saved)
- Office tools: `libreoffice-writer`, `libreoffice-calc`, `libreoffice-impress` (~500MB saved)
- Separate `doc_tools` environment

**🔧 Simplified:**
- Two environments instead of three: `dev` (includes doc tools + graph tools) + `inference`
- Faster environment switching - no need to switch for document processing
- Single `use_dev()` command for all RAG/Agent/Graph workflows

### Migration from v1.2

If you're upgrading from v1.2:

```bash
# Remove old image
docker rmi llm-dev:v1.2

# Build new v1.3 image
./build.sh

# Update docker-compose.yml (already updated if you pulled latest)
docker-compose up -d
```

**Note:** The `use_docs()` command has been removed. All document processing tools are now available in the default `dev` environment.

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- NVIDIA GPU with CUDA 12.4 support
- NVIDIA Container Toolkit

### 1. Build the Image

```bash
# Build with default password (ubuntu) - Recommended
./build.sh

# Build with custom password
./build.sh your_secure_password

# Or build manually
sudo docker build -t llm-dev:v1.3 .
sudo docker build --build-arg "USER_PASSWORD=your_secure_password" -t llm-dev:v1.3 .
```

### 2. Create External Network

```bash
docker network create ragflow
```

### 3. Start the Container

```bash
docker-compose up -d
```

### 4. Access the Environment

**SSH Access:**
```bash
ssh ubuntu@localhost -p 2222
# Password: ubuntu (or your custom password)
```

**Jupyter Lab:**
```
http://localhost:8888
```

## 🏗️ Architecture

### Virtual Environments

```
/opt/venv/
├── base/           # PyTorch foundation (shared by all envs)
├── dev/            # Development environment (default) - includes doc tools & graph tools
└── inference/      # High-performance inference
```

### Switch Between Environments

```bash
# Switch to Dev environment (default) - includes everything for RAG/Agent/Graph
use_dev

# Switch to Inference environment - for vLLM/LMDeploy
use_inference
```

## 💻 Usage

### Running Inference with vLLM

```bash
use_inference

# Start vLLM server
python -m vllm.entrypoints.openai.api_server \
  --model /home/ubuntu/model_cache/huggingface/Qwen/Qwen2.5-7B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

### Jupyter Lab

```bash
# Start Jupyter Lab (alias configured)
jlab

# Or manually
jupyter lab --ip=0.0.0.0 --no-browser --ServerApp.token="" --ServerApp.password=""
```

### GPU Monitoring

```bash
# Watch GPU usage (alias configured)
gpuw

# Or manually
watch -n 1 nvidia-smi
```

### Download HuggingFace Models

```bash
# Using alias
hf-down Qwen/Qwen2.5-7B-Instruct

# Or manually
huggingface-cli download --resume-download Qwen/Qwen2.5-7B-Instruct
```

### Document Processing (All in Dev Environment)

```python
# No need to switch environments - all tools available in dev!

# PDF processing with PyMuPDF
import fitz  # pymupdf
doc = fitz.open("document.pdf")
text = doc[0].get_text()

# Word document processing
from docx import Document
doc = Document("document.docx")

# Excel processing
import pandas as pd
df = pd.read_excel("data.xlsx")
```

### Knowledge Graph Development

```python
# NetworkX for graph algorithms
import networkx as nx
G = nx.Graph()
G.add_edges_from([('A', 'B'), ('B', 'C'), ('C', 'A')])

# Neo4j integration
from neo4j import GraphDatabase
driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "password"))

# Build knowledge graphs from documents
import tiktoken
tokenizer = tiktoken.get_encoding("cl100k_base")
tokens = tokenizer.encode("Your text here")
```

## ⚙️ Configuration

### docker-compose.yml

**GPU Configuration:**
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all  # Change to 1, 2, etc. to limit GPU usage
          capabilities: [gpu]
```

**Memory Configuration:**
```yaml
shm_size: '18gb'  # Adjust based on your GPU memory
```

**Port Mapping:**
```yaml
ports:
  - "2222:22"    # SSH
  - "8888:8888"  # Jupyter Lab
  - "8026:8000"  # vLLM API
  - "8501:8501"  # Streamlit (optional)
```

### Environment Variables

Edit in `docker-compose.yml`:

```yaml
environment:
  - TZ=Asia/Shanghai
  - HF_ENDPOINT=https://hf-mirror.com
  - CUDA_VISIBLE_DEVICES=all
  - VLLM_GPU_MEMORY_UTILIZATION=0.8
```

## 🐛 Troubleshooting

### Container Health Check Fails

**Symptom:** Container status shows "unhealthy"

**Solution:** The health check verifies SSH server is running. Check logs:
```bash
docker logs rag-dev-platform
```

### Out of Memory (OOM) Errors

**Solution 1:** Reduce vLLM memory utilization in `docker-compose.yml`:
```yaml
- VLLM_GPU_MEMORY_UTILIZATION=0.7  # Default is 0.8
```

**Solution 2:** Increase shared memory:
```yaml
shm_size: '24gb'  # Increase if you have more GPU memory
```

### SSH Connection Refused

**Check if SSH service is running:**
```bash
docker exec rag-dev-platform pgrep sshd
```

**Restart container:**
```bash
docker-compose restart
```

### HuggingFace Download Slow

**The environment is pre-configured with HF Mirror:**
```bash
echo $HF_ENDPOINT
# Should output: https://hf-mirror.com
```

**Manually set if needed:**
```bash
export HF_ENDPOINT=https://hf-mirror.com
```

## 📦 Included Packages

### AI/ML Frameworks
- PyTorch 2.4.0 (CUDA 12.4)
- Transformers
- Sentence Transformers
- vLLM
- LMDeploy
- Flash Attention 2

### Agent/RAG Frameworks
- LangChain
- LangGraph
- LlamaIndex
- OpenAI SDK
- Anthropic SDK
- Google Generative AI

### Vector Databases
- ChromaDB
- Qdrant
- Milvus

### Document Processing (Lightweight)
- PyMuPDF
- PDFPlumber
- python-docx
- Markitdown
- pandas, openpyxl, xlrd
- tiktoken

### Graph Tools
- NetworkX (graph algorithms)
- Neo4j (graph database driver)

### Development Tools
- JupyterLab
- IPyWidgets
- Zsh + Oh My Zsh
- Claude Code CLI
- OpenAI Codex CLI

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built on NVIDIA CUDA base images
- Uses Astral's `uv` for fast Python package installation
- Inspired by best practices from the ML/AI community
