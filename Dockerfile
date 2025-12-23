# ---- build Readarr from your fork ----
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

ARG TARGETPLATFORM
WORKDIR /src

# deps for frontend build + git
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm i -g yarn \
 && rm -rf /var/lib/apt/lists/*

# Copy everything
COPY . .

# Use the build script - build only linux-x64 to save disk space
# Set RID and FRAMEWORK to build only the platform we need for Docker
RUN set -eux; \
    chmod +x ./build.sh; \
    FRAMEWORK=net6.0 RID=linux-x64 bash -x ./build.sh

# ---- runtime: minimal .NET runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Install runtime dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends libsqlite3-0 \
 && rm -rf /var/lib/apt/lists/*

# Create app user
RUN groupadd -g 1000 readarr && \
    useradd -u 1000 -g readarr -d /app -s /usr/sbin/nologin readarr

WORKDIR /app

# Copy only the linux-x64 build output (we only built this platform)
COPY --from=build /src/_artifacts/linux-x64/net6.0/Readarr/ /app/

# Set permissions
RUN chown -R readarr:readarr /app

USER readarr

EXPOSE 8787

ENTRYPOINT ["./Readarr", "-nobrowser", "-data=/config"]
