#!/bin/bash

set -euo pipefail

# Ensure the script is being executed in its containing directory
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 [CUDA version] [Host compiler name] [Host compiler version]"
    echo "Example: $0 12.1 gcc 12"
    exit 1
fi

readonly cuda_version="$1"
readonly host_compiler_name="$2"
readonly host_compiler_version="$3"

# Create a simple docker container with dependencies needed to build the devcontainer.json
docker build --quiet -t devcontainer-build-container - <<EOF
FROM node:alpine
RUN apk add --no-cache bash git yq jq
WORKDIR /app
EOF

generate_devcontainer() {
    set -euo pipefail
    local cuda_version="$1"
    local host_compiler_name="$2"
    local host_compiler_version="$3"
    mkdir -p /tmp
    cd /tmp
    git clone --quiet https://github.com/rapidsai/devcontainers.git 
    cd devcontainers
    git -c advice.detachedHead=false checkout --quiet 397a978c0d2d0629f90e97de74e826f882f41c96
    # Parse the matrix to find the earliest version of Ubuntu that supports the host compiler
    local ubuntu_version=$(yq e -o json matrix.yml | jq -r --arg cname "$host_compiler_name" --arg cversion "$host_compiler_version" '.include[] | select(any(.images[].features[]; .name == $cname and .version == $cversion)) .os' | sort | head -n1)
    local features_list='[{"name":"'"${host_compiler_name}"'","version":"'"${host_compiler_version}"'"}, {"name":"cuda","version":"'"${cuda_version}"'"}, {"name": "ghcr.io/devcontainers/features/python:1"}, {"name": "python-lit"}]'
    # This defines and initializes`workspace` with the path to the generated devcontainer files
    eval "$(./scripts/generate.sh "${ubuntu_version}" "${features_list}" 2>/dev/null | xargs -r -I% echo -n local %\;)"
    local destination="/app/cuda${cuda_version}-${host_compiler_name}${host_compiler_version}"
    cp -nLR ${workspace}/.devcontainer ${destination}
}
export -f generate_devcontainer

# Ensure Docker container is removed on exit
trap 'docker rm -f devcontainer-build' EXIT

# Run the generate_devcontainer script in the Docker container
docker run --user $(id -u):$(id -g) -it --name devcontainer-build -v $(pwd):/app devcontainer-build-container bash -c "$(declare -f generate_devcontainer); generate_devcontainer '$cuda_version' '$host_compiler_name' '$host_compiler_version'"
