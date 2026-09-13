#!/bin/bash

set -euo pipefail

# Poolside 262144
export OLLAMA_CONTEXT_LENGTH=65536
export OLLAMA_PORT=11434
export OLLAMA_NETWORK=ollama-net
export OLLAMA_NUM_PARALLEL=2       # only allow 2, to preserve VRAM for KV cache
export OLLAMA_MAX_LOADED_MODELS=1  # only load one model at a time

# where to persist the Opencode container
OPENCODE_PROJECT_DIR="$HOME/src"
OPENCODE_CONTAINER_PERSIST=

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

function install {
  # should be idempotent
  binDir="$HOME/.local/bin"
  mkdir -p "$binDir" "$OPENCODE_PROJECT_DIR"

  echo "installing symlinks in $binDir"
  for name in "${!images[@]}" ; do
    [[ -e "$binDir/$name" ]] || ln -sv "$baseDir/opencode.sh" "$binDir/$name"
    if [[ "$name" == "opencode" ]] ; then
      [[ -e "$binDir/$name-build" ]] || ln -sv "$baseDir/opencode.sh" "$binDir/$name-build"
    else
      [[ -e "$binDir/$name-pull" ]] || ln -sv "$baseDir/opencode.sh" "$binDir/$name-pull"
    fi
  done
  if ! grep -q "PATH=.*$binDir" "$HOME/.bashrc" ; then
    echo "adding $binDir to PATH in $HOME/.bashrc"
    printf 'export PATH="$PATH:%s' "$binDir" >> "$HOME/.bashrc"
  fi
  if ! echo "$PATH" | grep -q "$binDir" ; then
    . "$HOME/.bashrc"
  fi
  echo "Pulling ollama image with 'ollama-pull'"
  command -v "ollama-pull" && ollama-pull
  echo "Building opencode image with 'opencode-build'"
  command -v "opencode-build" && opencode-build
  if command -v "opencode" ; then
    echo "run 'opencode PROJECT' to work on $HOME/src/PROJECT"
  fi
}

caller="$(basename -- "$0")"
baseDir="$(dirname -- "$(readlink -e -- "$0")")"

case "$caller" in
  opencode-build)
    cd "$baseDir"
    podman build -t opencode-docker --format docker .
    ;;
  opencode)
    project="${1:?arg1 is project under $OPENCODE_PROJECT_DIR to work on}"
    mkdir -p "$OPENCODE_PROJECT_DIR/$project"
    start_container opencode \
      ${OPENCODE_CONTAINER_PERSIST:- --rm} -it \
      -v "$OPENCODE_PROJECT_DIR/$project:/home/ubuntu/src/$project:U" \
      -v "$OPENCODE_PROJECT_DIR/$project-worktrees:/home/ubuntu/src/$project-worktrees:U" \
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
      -w "/home/ubuntu/src/$project" \
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
    install
    ;;
  *)
    echo "ERROR: unknown caller '$caller'" >&2
    exit 1
    ;;
esac
