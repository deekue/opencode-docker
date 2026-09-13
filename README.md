# Opencode + Android dev env in containers

there are many like it, this one is mine.

## Assumptions

* Linux system
* `podman` is installed
* local GPU that Ollama supports.

currently only tested with an AMD Radeon 7900XTX on [ChimeraOS](https://chimeraos.org)

YMMV

## Install/Setup

1. clone this repo 
1. run `./opencode.sh`
   this will setup symlinks and build/pull images
1. run `ollama` to start that container
   1. inside the container run `ollama pull <model>`, ex. `ollama pull qwen3.8:27b`
   1. you can exit and the container will keep running. you can run `ollama` again to jump back in
1. run `opencode <project>` to start the opencode container, mounting that project into the container
   1. inside the container
      1. `git clone` or `git init` to get started
      1. run `opencode` to start the TUI
1. run `opencode <project>` again to enter the same container (handy with Screen/Tmux)

**Hint** use `git worktree` if you want to run more than one instance of Opencode for the same project, so they don't stomp on each other's changes.

## Usage

install creates a bunch of symlinks in `$HOME/.local/bin`

* `opencode` - start or exec into the Opencode container created from [Dockerfile](Dockerfile)
* `opencode-build` - build the Opencode image, use `--build-arg CACHE_BUST=$RANDOM` to force an update of Opencode
* `ollama` - start or exec into the Ollama container
* `ollama-pull` - pull the latest Ollama image
* `open-webui` - start or exec into the Open-WebUI container
* `open-webui-pull` - pull the latest Open-WebUI image

## Customisation

the containers are ephemeral, anything you want to keep needs to be bind mounted (see [opencode.sh](opencode.sh)).

**Bind mounts**

* all of Opencode's directories
* `~/.android` - Android SDK stuff
* `~/.m2`, `~/.gradle` - build/repo cache
* `~/.config/git` - git config
* `~/.config/bash` - bash config
* `~/.local/state/bash` - bash history

**Custom config** 

* `dotfiles/config/git/config`       - main Git config
* `dotfiles/config/git/config.user`  - your GitHub/Git user config, ignored by git
* `dotfiles/config/git/credentials`  - your GitHub/Git credentials, ignored by git
* `dotfiles/config/bash/bashrc`      - sourced by the `.bashrc` in the container
* `dotfiles/config/bash/bashrc.user` - bash user config, env vars with creds etc, ignored by git
* `dotfiles/config/opencode/opencode.json` - main Opencode config, customised for Android dev with a local LLM

### Opencode Dockerfile

[Dockerfile](Dockerfile) contains a reasonably minimal Opencode + Android dev.

* all the versions can be passed in as `--build-arg` to `opencode-build`, including the base image (though a Debian based image is assumed).
* use `--build-arg CACHE_BUST=$RANDOM` to force an update of Opencode
* includes [Hugo](https://gohugo.io) for generating GitHub Pages

