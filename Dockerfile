# ---- build Readarr from your fork ----
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build

ARG TARGETPLATFORM
WORKDIR /src

# deps for frontend build + git
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq \
 && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm i -g yarn \
 && rm -rf /var/lib/apt/lists/*

COPY . .

# Build backend + frontend using repo scripts (matches upstream intent)
RUN chmod +x ./build.sh && ./build.sh

# build.sh typically writes to _output; copy the whole output (safe)
# (we'll copy it into the runtime image below)

# ---- runtime: use linuxserver image and overlay binaries ----
FROM lscr.io/linuxserver/readarr:develop

# linuxserver readarr lives here:
# /app/readarr/bin
# Overlay the built output into the app folder.
COPY --from=build /src/_output/ /app/readarr/bin/
