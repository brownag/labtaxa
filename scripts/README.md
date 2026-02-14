# Build Scripts

## Docker Build (`build-docker.sh`)

Build Docker images locally with optional caching.

### Setup

```bash
docker buildx create --use
```

### Usage

```bash
# Fast cached build (development, ~5-15 min)
./scripts/build-docker.sh

# Clean build from scratch (validation, ~1-2 hours)
./scripts/build-docker.sh --test

# Show help
./scripts/build-docker.sh --help
```

### When to use each mode

**Default (cached):**
- Daily development
- Testing small changes
- Iterating on code

**--test mode:**
- Before pushing code to main
- Validating dependencies are complete
- Matching GitHub Actions environment

### Note

GitHub Actions builds and pushes monthly to registry automatically. The `--test` flag validates that the build would work in that environment.
