FROM python:3.10-slim

LABEL maintainer="Catalyst Squad <community@catalystsquad.com>"

WORKDIR /workspace

# Get all the Python tools in and up to date
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y sqlite3 inotify-tools wget \
        curl apt-utils git wait-for-it apt-transport-https ca-certificates \
        gnupg2 software-properties-common apt-transport-https jq apache2-utils \
        unzip

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
RUN apt-get update -y && apt-get install  -y docker-ce

RUN pip3 install --upgrade pip
RUN pip3 install setuptools watchdog poetry docker-compose yq yamllint

# Get all the node tooling in with 12.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
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

# Github Actions Runner specific stuff, started from https://github.com/myoung34/docker-github-actions-runner/blob/master/Dockerfile
ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.291.1"
ARG TARGETPLATFORM

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# TODO: remove this terrible sed once
#  https://github.com/actions/runner/pull/1585 is merged or similar
RUN sed -i.bak 's/.\/bin\/installdependencies.sh/wget https:\/\/raw.githubusercontent.com\/myoung34\/runner\/main\/src\/Misc\/layoutbin\/installdependencies.sh -O .\/bin\/installdependencies.sh; bash .\/bin\/installdependencies.sh/g' ./scripts/install_actions.sh \
  && ./scripts/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm ./scripts/install_actions.sh

COPY ./scripts/token.sh ./scripts/gh_entrypoint.sh /
RUN chmod +x /token.sh /gh_entrypoint.sh

ENTRYPOINT ["/gh_entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
