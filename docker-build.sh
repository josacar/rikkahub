#!/usr/bin/env bash
# Convenience wrapper: builds an image that can compile RikkaHub, then runs it
# against the current working tree.
#
# Usage:
#   ./docker-build.sh                 # compile debug
#   ./docker-build.sh assembleRelease  # override gradle task
#   ./docker-build.sh --shell          # drop into a shell in the builder image
#
# Requires podman (or docker). The container mounts this repo at /work and the
# host's Gradle cache at /root/.gradle so subsequent builds are incremental.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_TAG="${IMAGE_TAG:-rikkahub-builder:latest}"

build_image() {
  echo ">> Building image ${IMAGE_TAG}"
  (cd "${REPO_ROOT}" && podman build -t "${IMAGE_TAG}" -f Dockerfile .)
}

ensure_submodule() {
  if [ ! -f "${REPO_ROOT}/material3/material-color-utilities/kotlin/disctype.kt" ] && \
     [ -d "${REPO_ROOT}/.git" ]; then
    echo ">> Initializing git submodule material3/material-color-utilities"
    git -C "${REPO_ROOT}" submodule update --init material3/material-color-utilities
  fi
}

ensure_google_services() {
  local target="${REPO_ROOT}/app/google-services.json"
  if [ -f "${target}" ]; then
    return 0
  fi
  echo ">> app/google-services.json missing; writing a dummy file so the google-services plugin passes."
  cat >"${target}" <<'JSON'
{
  "project_info": { "project_number": "000000000000", "project_id": "dummy" },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000",
        "android_client_info": { "package_name": "me.rerere.rikkahub" }
      },
      "api_key": [{ "current_key": "AIzaSyDummy00000000000000000000000000000" }]
    },
    {
      "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000001",
        "android_client_info": { "package_name": "me.rerere.rikkahub.debug" }
      },
      "api_key": [{ "current_key": "AIzaSyDummy00000000000000000000000000001" }]
    }
  ],
  "configuration_version": "1"
}
JSON
  echo "   (Remove ${target} before committing if you do not want it tracked.)"
}

run_build() {
  echo ">> Running: ./gradlew $*"
  podman run --rm \
    -v "${REPO_ROOT}:/work" \
    -v "${HOME}/.gradle:/root/.gradle" \
    --workdir /work \
    "${IMAGE_TAG}" "$@"
}

main() {
  build_image
  ensure_submodule
  ensure_google_services
  if [ "${1:-}" = "--shell" ]; then
    exec podman run --rm -it \
      -v "${REPO_ROOT}:/work" \
      -v "${HOME}/.gradle:/root/.gradle" \
      --workdir /work \
      --entrypoint /bin/bash \
      "${IMAGE_TAG}"
  fi
  run_build "$@"
}

main "$@"