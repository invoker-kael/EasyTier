#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${DOCKER_USERNAME:-}" ]]; then
    echo "DOCKER_USERNAME is required, for example: DOCKER_USERNAME=your-user" >&2
    exit 1
fi

command -v docker >/dev/null 2>&1 || {
    echo "Missing required command: docker" >&2
    exit 1
}

commit_tag="$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
DOCKER_REPOSITORY="${DOCKER_REPOSITORY:-easytier-custom}"
image_name="${DOCKER_USERNAME}/${DOCKER_REPOSITORY}"

if ! docker push "${image_name}:${commit_tag}"; then
    echo "Failed to push ${image_name}:${commit_tag}. Run: docker login --username ${DOCKER_USERNAME}" >&2
    exit 1
fi

if ! docker push "${image_name}:latest"; then
    echo "Failed to push ${image_name}:latest. Run: docker login --username ${DOCKER_USERNAME}" >&2
    exit 1
fi

echo "Pushed Docker images: ${image_name}:${commit_tag}, ${image_name}:latest"
