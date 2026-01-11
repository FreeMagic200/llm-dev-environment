#!/bin/bash

# Build LLM Development Environment Docker Image
# Usage: ./build.sh [PASSWORD]

USER_PASSWORD="${1:-ubuntu}"

echo "Building llm-dev:v1.2 with custom password..."
sudo docker build --build-arg "USER_PASSWORD=${USER_PASSWORD}" -t llm-dev:v1.2 .

echo ""
echo "Build complete! Start with:"
echo "  docker-compose up -d"
