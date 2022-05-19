FROM python:3.7-slim

LABEL maintainer="TnL Community <tnlcommunity@todandlorna.com>"

WORKDIR /root/app/

# Get all the Python tools in and up to date
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y python3-pip python3-dev sqlite3 inotify-tools \
        curl apt-utils git wait-for-it apt-transport-https ca-certificates \
        gnupg2 software-properties-common apt-transport-https jq apache2-utils

RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
RUN apt-get update -y && apt-get install  -y docker-ce
RUN pip3 install --upgrade pip
RUN pip3 install setuptools gunicorn waitress watchdog bumpversion poetry docker-compose yq

# Get all the node tooling in with 12.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs

RUN npm install -g yarn

# Install kubectl (last of the basics because this version will change often)
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/

# Any custom utilities can be brought over from here and access via the scripts directory
COPY ./scripts ./scripts
RUN chmod +x ./scripts/*

RUN ./scripts/install_gcloud.sh

# Installl helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
# Install helm stable repo
RUN helm repo add stable https://kubernetes-charts.storage.googleapis.com/

# Anything one wants to run in this runner that needs to be exposed can on this port
EXPOSE 6000
