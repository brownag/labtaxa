#!/bin/bash
# Build labtaxa Docker image locally (fast cached or clean test mode)
# Usage: ./scripts/build-docker.sh [--test]

set -e

CLEAN_BUILD=false
IMAGE="ghcr.io/brownag/labtaxa"
BUILD_DATE=$(date -u +'%Y-%m-%d_%H-%M-%S')

# Parse arguments
case "${1:-}" in
  --test)
    CLEAN_BUILD=true
    ;;
  --help)
    cat << 'EOF'
Build labtaxa Docker image

Usage:
  ./scripts/build-docker.sh       Fast cached build (development)
  ./scripts/build-docker.sh --test Clean build from scratch (validation)

Note: GitHub Actions handles monthly builds and registry pushes.
EOF
    exit 0
    ;;
  *)
    [[ -z "$1" ]] || { echo "Unknown option: $1"; exit 1; }
    ;;
esac

# Check buildx availability
docker buildx version > /dev/null 2>&1 || {
  echo "ERROR: docker buildx not found"
  echo "Install: docker buildx create --use"
  exit 1
}

# Build command
BUILD_CMD="docker buildx build --tag ${IMAGE}:latest --build-arg BUILD_DATE=${BUILD_DATE} --progress=plain"

if [[ "$CLEAN_BUILD" == "true" ]]; then
  echo "Mode: CLEAN (no cache)"
  BUILD_CMD="${BUILD_CMD} --no-cache"
else
  echo "Mode: CACHED (registry cache)"
  BUILD_CMD="${BUILD_CMD} --cache-from=type=registry,ref=${IMAGE}:buildcache --cache-to=type=registry,ref=${IMAGE}:buildcache,mode=max"
fi

BUILD_CMD="${BUILD_CMD} ."
eval "$BUILD_CMD" && echo "Build successful" || { echo "Build failed"; exit 1; }
