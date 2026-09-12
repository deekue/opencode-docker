ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=noble

FROM $BASE_IMAGE:$BASE_TAG

ARG NVM_VER=0.40.5
ARG NODE_VER=--lts
ARG ANDROID_API_VER=36
# https://developer.android.com/studio#:~:text=Command%20line%20tools%20only
ARG ANDROID_SDK_VER=15859902_latest
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_NDK=27.0.12077973
ARG ANDROID_CMAKE=3.22.1
ARG HUGO_VERSION=0.165.0
ARG TZ=Australia/Melbourne
ARG LANG=en_US.UTF-8

# Use bash for the shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /root

RUN apt-get update -qy \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      git \
      jq \
      less \
      openjdk-21-jdk \
      ripgrep \
      unzip \
      vim-tiny \
      wget \
      yamllint \
      yq \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

USER 1000
WORKDIR /home/ubuntu
ENV NVM_DIR=/home/ubuntu/.nvm
ENV BASH_ENV=/home/ubuntu/.bash_env
ENV USE_PREBUILT_NATIVE=true
ENV QTWEBENGINE_DISABLE_SANDBOX=1
# emulator
ENV ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL=10
#ENV ANDROID_AVD_HOME=/data  # default is?

# Create a script file sourced by both interactive and non-interactive bash shells
RUN touch "${BASH_ENV}" \
 && echo '. "${BASH_ENV}"' >> ~/.bashrc \
 && echo '[[ -r "$HOME/.config/bash/bashrc" ]] && . "$HOME/.config/bash/bashrc"' >> ~/.bashrc

RUN curl -fsSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VER/install.sh \
      | PROFILE="${BASH_ENV}" bash

RUN bash -o pipefail -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VER"

# install Android SDK
RUN curl -fsSLo /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VER}.zip \
 && unzip -d /tmp /tmp/cmdline-tools.zip \
 && mkdir -p /home/ubuntu/android-sdk/cmdline-tools \
 && mv /tmp/cmdline-tools /home/ubuntu/android-sdk/cmdline-tools/latest \
 && rm /tmp/cmdline-tools.zip

RUN echo 'export ANDROID_HOME=$HOME/android-sdk' >> $BASH_ENV \
 && echo 'export ANDROID_SDK_ROOT=$HOME/android-sdk' >> $BASH_ENV \
 && echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/build-tools/$ANDROID_BUILD_TOOLS:$HOME/.local/bin' >> $BASH_ENV \
 && echo 'export LD_LIBRARY_PATH="$ANDROID_SDK_ROOT/emulator/lib64:$ANDROID_SDK_ROOT/emulator/lib64/qt/lib"' >> $BASH_ENV

# deprecated
#RUN bash -o pipefail -c "source $BASH_ENV \
#      && yes | sdkmanager --licenses || true"

RUN bash -c "source $BASH_ENV \
 && android sdk install \
      platform-tools \
      emulator \
      'system-images;android-${ANDROID_API_VER};google_apis;x86_64' \
      'platforms;android-${ANDROID_API_VER}' \
      'build-tools;${ANDROID_BUILD_TOOLS}' \
      'ndk;${ANDROID_NDK}' \
      'cmake;${ANDROID_CMAKE}'"

# Hugo for GitHub Pages
RUN curl -sfL --output-dir /tmp -O "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" \
 && curl -sfL --output-dir /tmp -O "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
 && mkdir -p "${HOME}/.local/hugo" \
 && tar -C "${HOME}/.local/hugo" -xf "/tmp/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" \
 && tar -C "${HOME}/.local/hugo" -xf "/tmp/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
 && echo "export PATH=$PATH:${HOME}/.local/hugo" >> "$BASH_ENV"

ARG CACHE_BUST=nah
RUN echo $CACHE_BUST \
 && npm install -g opencode-ai

# set ENTRYPOINT for reloading nvm-environment
ENTRYPOINT ["bash", "-c", "source $NVM_DIR/nvm.sh && exec \"$@\"", "--"]

# set cmd to bash
CMD ["/bin/bash"]
