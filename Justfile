# BuildStream runs in the pinned freedesktop-sdk builder image.
bst2_image := env("BST2_IMAGE", "registry.gitlab.com/freedesktop-sdk/infrastructure/freedesktop-sdk-docker-images/bst2:64eb0b4930d57a92710822898fb73af6cc1ae35d")
sudo_cmd := if `podman info >/dev/null 2>&1 && echo 1 || echo 0` == "1" { "" } else { "sudo" }
image_ref := "ghcr.io/projectbluefin/ghostscript-printer-app:build"

default:
    @just --list

bst *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "${HOME}/.cache/buildstream"
    RE_FLAG=()
    PF_PID=""
    cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" 2>/dev/null || true; }
    trap cleanup EXIT
    if [[ "${BST_REMOTE:-0}" == "1" ]]; then
        export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/bluespeed.yaml}"
        kubectl port-forward -n buildbarn svc/frontend 18980:8980 >/dev/null 2>&1 &
        PF_PID=$!
        for _ in $(seq 1 20); do
            (echo > /dev/tcp/127.0.0.1/18980) 2>/dev/null && break
            sleep 0.5
        done
        cat > .bst-re.conf <<'EOF'
    remote-execution:
      execution-service:
        url: grpc://127.0.0.1:18980
      storage-service:
        url: grpc://127.0.0.1:18980
      action-cache-service:
        url: grpc://127.0.0.1:18980
    EOF
        RE_FLAG=(--config /src/.bst-re.conf)
    fi
    {{ sudo_cmd }} podman run --rm \
        --privileged \
        --device /dev/fuse \
        --network=host \
        -v "{{ justfile_directory() }}:/src:rw" \
        -v "${HOME}/.cache/buildstream:/root/.cache/buildstream:rw" \
        -w /src \
        "{{ bst2_image }}" \
        bash -c 'bst "$@"' -- --no-interactive "${RE_FLAG[@]}" {{ ARGS }}

validate:
    just bst show --deps all oci/ghostscript-printer-app.bst

build:
    #!/usr/bin/env bash
    set -euo pipefail
    just bst build oci/ghostscript-printer-app.bst
    just export

export:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf .build-out
    just bst artifact checkout oci/ghostscript-printer-app.bst --directory /src/.build-out
    IMAGE_ID=$({{ sudo_cmd }} podman pull -q oci:.build-out)
    rm -rf .build-out
    {{ sudo_cmd }} podman tag "$IMAGE_ID" "{{ image_ref }}"

verify-core:
    tests/core-appliance.sh

verify-payload:
    tests/core-payload.sh

verify-cups-patch-chain:
    tests/cups-patch-chain.sh
