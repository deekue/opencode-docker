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

## Customisation

the containers are ephemeral, anything you want to keep needs to be bind mounted (see [opencode.sh](opencode.sh)).

**Bind mounts**

* all of Opencode's directories
* `~/.android` - Android SDK stuff
* `~/.m2`, `~/.grade` - build/repo cache
* `~/.config/git` - git config
* `~/.config/bash` - bash config
* `~/.local/state/bash` - bash history

**Custom config** 

* `dotfiles/config/git/config`       - main Git config
* `dotfiles/config/git/config.user`  - your GitHub/Git user config, ignored by git
* `dotfiles/config/git/credentials   - your GitHub/Git credentials, ignored by git

* `dotfiles/config/bash/bashrc`      - sourced by the `.bashrc` in the container
* `dotfiles/config/bash/bashrc.user` - bash user config, env vars with creds etc, ignored by git

* `dotfiles/config/opencode/opencode.json` - main Opencode config, customised for Android dev with a local LLM


