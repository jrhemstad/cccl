#! /usr/bin/env bash

set -euo pipefail

launch_devcontainer() {

    # Ensure we're in the repo root
    cd "$( cd "$( dirname "$(realpath -m "${BASH_SOURCE[0]}")" )" && pwd )/..";

    if [[ -z $1 ]] || [[ -z $2 ]]; then
        echo "Usage: $0 [CUDA version] [Host compiler name] [host compiler version]"
        echo "Example: $0 12.1 gcc 12"
        return 1
    fi

    local cuda_version="$1"
    local host_compiler_name="$2"
    local host_compiler_version="$3"
    local workspace="$(basename "$(pwd)")";
    local devcontainer_name="cuda${cuda_version}-${host_compiler_name}${host_compiler_version}"
    local devcontainer_path="$(pwd)/.devcontainer/${devcontainer_name}";

    # Check if the devcontainer exists
    if [ ! -d "${devcontainer_path}" ]; then
        echo "Devcontainer ${devcontainer_path} does not exist. Building it..."
        .devcontainer/build_devcontainer.sh "${cuda_version}" "${host_compiler_name}" "${host_compiler_version}"
    fi

    local tmpdir="$(mktemp -d)/${workspace}";
    mkdir -p "${tmpdir}/.devcontainer";
    cp -arL ${devcontainer_path}/* "${tmpdir}/.devcontainer";
    sed -i "s@\${localWorkspaceFolder}@$(pwd)@g" "${tmpdir}/.devcontainer/devcontainer.json";
    devcontainer_path="${tmpdir}";

    local hash="$(echo -n "${devcontainer_path}" | xxd -pu - | tr -d '[:space:]')";
    local url="vscode://vscode-remote/dev-container+${hash}/home/coder/cccl";

    echo "devcontainer URL: ${url}";

    local launch="";
    if type open >/dev/null 2>&1; then
        launch="open";
    elif type xdg-open >/dev/null 2>&1; then
        launch="xdg-open";
    fi

    if [ -n "${launch}" ]; then
        code --new-window "${tmpdir}";
        exec "${launch}" "${url}" >/dev/null 2>&1;
    fi
}

launch_devcontainer "$@";