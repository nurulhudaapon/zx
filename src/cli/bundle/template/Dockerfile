FROM alpine:3.22.2 AS build

# Setup Zig
ARG ZIG_VER=0.15.2
RUN apk add --no-cache curl xz
RUN curl https://ziglang.org/download/${ZIG_VER}/zig-$(uname -m)-linux-${ZIG_VER}.tar.xz -o zig.tar.xz && \
tar xf zig.tar.xz && \
mv zig-$(uname -m)-linux-${ZIG_VER}/ /opt/zig

# Node/Bun Pre-requisites
# RUN apk add --no-cache unzip bash libstdc++ libgcc nodejs npm

# Install Bun
# RUN curl -fsSL https://bun.sh/install | bash

# Build the app
WORKDIR /build

# Install Node dependencies (node)
# COPY package.json ./package.json
# COPY package-lock.json ./package-lock.json
# RUN npm install

# Install Node dependencies (bun)
# COPY bun.lock ./bun.lock
# RUN $HOME/.bun/bin/bun install

COPY . .

RUN /opt/zig/zig build -Doptimize=ReleaseSafe
RUN /opt/zig/zig build zx -Doptimize=ReleaseSafe -- bundle

# Run the app
FROM alpine:3.22.2

COPY --from=build /build/zig-out/bin/$BIN_NAME /app/$BIN_NAME
COPY --from=build /build/bundle/public /app/public
COPY --from=build /build/bundle/assets /app/assets

ENTRYPOINT ["/app/$BIN_NAME", "--rootdir", "./app"]
