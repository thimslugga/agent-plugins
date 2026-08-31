---
inclusion: fileMatch
fileMatchPattern: 'Containerfile*,Dockerfile*,*.dockerfile,compose.yml,compose.yaml,docker-compose*.yml,docker-compose.yaml'
---

# Container Best Practices

## Best Practices

- Set appropriate WORKDIR
- Use EXPOSE for documentation
- Use health checks when appropriate
- Use LABEL for metadata

## Optimizations

For `Containerfile` and `Dockerfile`:

- Prefer minimal base images (amazonlinux 2023 minimal, alpine, distroless)
- Use specific base image tags, avoid `latest`
- Use multi-stage builds to reduce image size
- Minimize layers by combining RUN commands
- Order layers from least to most frequently changing
- Clean up package manager caches
- Use appropriate COPY vs ADD commands
- Use `.dockerignore` to exclude unnecessary files
- Minimize context size
- Use build cache effectively
- Run as non-root user when possible

## Security

- Keep base images updated
- Don't include secrets in images
