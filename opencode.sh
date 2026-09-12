#!/bin/bash

set -euo pipefail

# Poolside 262144
export OLLAMA_CONTEXT_LENGTH=65536
export OLLAMA_PORT=11434
export OLLAMA_NETWORK=ollama-net
export OLLAMA_NUM_PARALLEL=2       # only allow 2, to preserve VRAM for KV cache
export OLLAMA_MAX_LOADED_MODELS=1  # only load one model at a time

# where to persist the Opencode container
export OPENCODE_CONTAINER_PERSIST=

declare -A images=(
  [ollama]=docker.io/ollama/ollama:latest
  [open-webui]=ghcr.io/open-webui/open-webui:main
  [opencode]=opencode-docker:latest
)

function start_container {
  local -r containerName="${1:?arg 1 is container name}"; shift
  local -a args=("$@")

  local -r containerImage="${images[$containerName]}"
  status="$(podman container ls -l -f name="$containerName" --format '{{json .Status}}')"

  case "${status#\"}" in
    Up*)
      echo "$containerName is running"
      podman exec -it "$containerName" /bin/bash
      ;;
    Exit*)
      # only relevant if OPENCODE_CONTAINER_PERSIST is set
      podman start "$containerName"
      # TODO add a wait and then exec in
      podman wait --condition=running "$containerName"
      podman exec -it "$containerName" /bin/bash
      ;;
    *)
      podman run \
	      --network "$OLLAMA_NETWORK" \
	      --name "$containerName" \
	      -h "$containerName" \
	      "${args[@]}" \
	      "$containerImage"
      ;;
  esac
}

caller="$(basename -- "$0")"
baseDir="$(dirname -- "$(readlink -e -- "$0")")"

case "$caller" in
  opencode-build)
    cd "$baseDir"
    podman build -t opencode-docker --format docker .
    ;;
  opencode)
    PROJECT="${1:?arg1 is project under $HOME/src to work on}"
    start_container opencode \
      ${OPENCODE_CONTAINER_PERSIST:- --rm} \
      -it \
      -v "$HOME/src/$PROJECT:/home/ubuntu/src/$PROJECT:U" \
      -v "$baseDir/dotfiles/config/bash:/home/ubuntu/.config/bash:U" \
      -v "$baseDir/dotfiles/config/git:/home/ubuntu/.config/git:U" \
      -v "$baseDir/dotfiles/cache/opencode:/home/ubuntu/.cache/opencode:U" \
      -v "$baseDir/dotfiles/config/opencode:/home/ubuntu/.config/opencode:U" \
      -v "$baseDir/dotfiles/local/share/opencode:/home/ubuntu/.local/share/opencode:U" \
      -v "$baseDir/dotfiles/local/state/opencode:/home/ubuntu/.local/state/opencode:U" \
      -v "$baseDir/dotfiles/local/state/bash:/home/ubuntu/.local/state/bash:U" \
      -v "$baseDir/dotfiles/android:/home/ubuntu/.android:U" \
      -v "$baseDir/dotfiles/gradle:/home/ubuntu/.gradle:U" \
      -v "$baseDir/dotfiles/m2:/home/ubuntu/.m2:U" \
      -e HISTFILE="/home/ubuntu/.local/state/bash/history" \
      -e LANG \
      -e TERM \
      -e TZ \
      -w /home/ubuntu/src \
      --device /dev/kvm
    ;;
  ollama)
    start_container ollama \
      -e OLLAMA_CONTEXT_LENGTH \
      -e OLLAMA_NUM_PARALLEL \
      -e OLLAMA_MAX_LOADED_MODELS \
      -d \
      --device /dev/kfd \
      --device /dev/dri \
      -v "$HOME/.ollama:/root/.ollama" \
      -p "127.0.0.1:$OLLAMA_PORT:11434"
    ;;
  open-webui)
    start_container open-webui \
      -d \
      -p 3000:8080 \
      -v "$HOME/.open-webui:/app/backend/data" \
      -e "OLLAMA_BASE=http://ollama:$OLLAMA_PORT"
    ;;
  *-pull)
    imageName="${caller%-pull}"
    podman pull "${images[$imageName]}"
    ;;
  opencode.sh)
    # called directly, assume install
    binDir="$HOME/.local/bin"
    mkdir -p "$binDir" "$HOME/src"
    echo "installing symlinks in $binDir"
    for name in "${!images[@]}" ; do
      ln -svi "$baseDir/opencode.sh" "$binDir/$name" || true
      if [[ "$name" == "opencode" ]] ; then
        ln -svi "$baseDir/opencode.sh" "$binDir/$name-build" || true
      else
        ln -svi "$baseDir/opencode.sh" "$binDir/$name-pull" || true
      fi
    done
    if ! grep -q "$binDir" "$HOME/.bashrc" ; then
      echo "adding $binDir to PATH in $HOME/.bashrc"
      printf 'export PATH="$PATH:%s' "$binDir" >> "$HOME/.bashrc"
    fi
    if ! echo "$PATH" | grep -q "$binDir" ; then
      . "$HOME/.bashrc"
    fi
    if command -v "opencode" ; then
      echo "ready to go, run 'ollama-pull' then 'ollama' to start the backend"
      echo "then 'opencode-build' to build the Opencode container"
      echo "then 'opencode PROJECT' to work on $HOME/src/PROJECT"
    fi
    ;;
  *)
    echo "ERROR: unknown caller '$caller'" >&2
    exit 1
    ;;
esac
