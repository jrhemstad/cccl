#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

# Create a simple docker container with dependencies needed to build the devcontainer.json
docker build -t devcontainer-build-container -f - . <<EOF
FROM node:alpine
RUN apk add --no-cache bash git
WORKDIR /app
EOF

generate_devcontainer() {
    mkdir -p /tmp
    cd /tmp
    git clone -q https://github.com/rapidsai/devcontainers.git 
    cd devcontainers
    git -c advice.detachedHead=false checkout 397a978c0d2d0629f90e97de74e826f882f41c96
    eval "$(./scripts/generate.sh 'ubuntu:20.04' '[{"name":"llvm","version":"14"}, {"name":"cuda","version":"11.8"}, {"name": "ghcr.io/devcontainers/features/python:1"}, {"name": "python-lit"}]' | xargs -r -I% echo -n local %\;)"
    cp -LR ${workspace} /app
}
export -f generate_devcontainer

# Ensure Docker container is removed on exit
trap 'docker rm -f devcontainer-build' EXIT

# Run the generate_devcontainer script in the Docker container
docker run -it --name devcontainer-build -v $(pwd):/app devcontainer-build-container bash -c "$(declare -f generate_devcontainer); generate_devcontainer"
