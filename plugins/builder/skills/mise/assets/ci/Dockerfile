# Build on the official mise image. Pin the tag to a release you have tested,
# or to a digest: docker buildx imagetools inspect ghcr.io/jdx/mise:<tag>
FROM ghcr.io/jdx/mise:2026.10.4-debian

WORKDIR /app

# Config first, so the tool layer is rebuilt only when it changes.
# Without a lockfile: drop mise.lock here and --locked below.
COPY mise.toml mise.lock ./
RUN mise trust && mise install --locked

COPY . .

# Build shells are not activated: run everything through mise.
RUN mise run build

CMD ["mise", "run", "start"]
