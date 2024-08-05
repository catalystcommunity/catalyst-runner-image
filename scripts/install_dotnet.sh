#!/bin/bash

# Get latest .NET 6 version
dotnet6_version=$(curl -s https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/6.0/releases.json | grep -Po '(?<="latest-sdk": ")[^"]*')
# Get latest .NET 8 version
dotnet8_version=$(curl -s https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/8.0/releases.json | grep -Po '(?<="latest-sdk": ")[^"]*')

curl -SL --output dotnet-install.sh https://dot.net/v1/dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --version $dotnet6_version --install-dir /usr/share/dotnet && \
    ./dotnet-install.sh --version $dotnet8_version --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh
