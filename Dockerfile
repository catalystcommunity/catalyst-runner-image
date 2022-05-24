FROM ubuntu:latest

LABEL maintainer="Catalyst Squad <community@catalystsquad.com>"

WORKDIR /workspace
ARG TARGETPLATFORM=amd64
ARG RUNNER_VERSION=2.291.1
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.12
ARG DUMB_INIT_VERSION=1.2.5

# Get all the tools in and up to date
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:git-core/ppa \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
    apache2-utils \
    apt-transport-https \
    build-essential \
    curl \
    ca-certificates \
    dnsutils \
    ftp \
    git \
    gnupg2 \
    inotify-tools \
    iproute2 \
    iputils-ping \
    jq \
    libunwind8 \
    locales \
    netcat \
    openssh-client \
    parallel \
    python3 \
    python3-pip \
    rsync \
    shellcheck \
    sqlite3 \
    sudo \
    telnet \
    time \
    tzdata \
    unzip \
    upx \
    wget \
    zip \
    zstd \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip
RUN pip3 install setuptools watchdog poetry yq yamllint

# Get all the node tooling in with 16.x
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install -y nodejs

RUN npm install -g yarn

# Install kubectl (last of the basics because this version will change often)
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/

# Any custom utilities can be brought over from here and access via the scripts directory
COPY ./scripts ./scripts
RUN chmod +x ./scripts/*

# Install gcloud CLI
RUN ./scripts/install_gcloud.sh
# Install AWS CLI
RUN ./scripts/install_aws.sh
# Install the Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash 

# Installl helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
# Install helm stable repo
RUN helm repo add stable https://charts.helm.sh/stable

# Anything one wants to run in this runner that needs to be exposed can on this port
EXPOSE 6000

# Github Runner Specific
# arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/local/bin/dumb-init

# Docker download supports arm64 as aarch64 & amd64 / i386 as x86_64
RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -f -L -o docker.tgz https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && install -o root -g root -m 755 docker/docker /usr/local/bin/docker \
    && rm -rf docker docker.tgz \
    && adduser --disabled-password --gecos "" --uid 1000 runner \
    && groupadd docker \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && chown -R runner:runner /workspace

ENV HOME=/workspace

COPY scripts/install_actions.sh /actions-runner/

ENV RUNNER_ASSETS_DIR=/runnertmp
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    # Comment-out the below curl invocation when you use your own build of actions/runner
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && chmod +x /actions-runner/install_actions.sh \
    && sed -i.bak 's/.\/bin\/installdependencies.sh/wget https:\/\/raw.githubusercontent.com\/myoung34\/runner\/main\/src\/Misc\/layoutbin\/installdependencies.sh -O .\/bin\/installdependencies.sh; bash .\/bin\/installdependencies.sh/g' /actions-runner/install_actions.sh \
    && /actions-runner/install_actions.sh ${RUNNER_VERSION} ${TARGETPLATFORM} \
    && rm /actions-runner/install_actions.sh \
    && mv ./externals ./externalstmp \
    && apt-get install -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp docker /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY ./scripts/gh_entrypoint.sh ./scripts/logger.bash /usr/bin/
RUN chmod +x /usr/bin/gh_entrypoint.sh /usr/bin/logger.bash

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV ImageOS=ubuntu22

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

USER runner

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["gh_entrypoint.sh"]
