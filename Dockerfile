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

# ---- runtime: minimal .NET runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:6.0

# Create app user
RUN groupadd -g 1000 readarr && \
    useradd -u 1000 -g readarr -d /app -s /bin/bash readarr

WORKDIR /app/readarr/bin

# Copy built application
COPY --from=build /src/_output/ ./

# Set permissions
RUN chown -R readarr:readarr /app

USER readarr

EXPOSE 8787

ENTRYPOINT ["./Readarr", "-nobrowser", "-data=/config"]
