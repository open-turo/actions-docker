#!/usr/bin/env bash

# Script to create Docker multi-arch manifests
# Usage: create-manifest.sh <image-name> <tags> <sources>
#   image-name: Docker image name (e.g., org/image-name)
#   tags: Comma-separated list of tags (e.g., 1.0.0,latest)
#   sources: Newline-separated list of source images (e.g., org/image@sha256:...)

set -euo pipefail

# Check for required arguments
if [ $# -lt 3 ]; then
  echo "::error::Usage: create-manifest.sh <image-name> <tags> <sources>"
  exit 1
fi

IMAGE_NAME="$1"
TAGS="$2"
SOURCES="$3"

# Parse comma-separated tags into array
IFS=',' read -ra TAG_ARRAY <<< "$TAGS"

# Parse newline-separated sources into array
mapfile -t SOURCE_ARRAY <<< "$SOURCES"

# Remove empty lines from sources
SOURCE_ARRAY_FILTERED=()
for source in "${SOURCE_ARRAY[@]}"; do
  # Trim whitespace
  source=$(echo "$source" | xargs)
  # Skip empty lines
  [ -z "$source" ] && continue
  SOURCE_ARRAY_FILTERED+=("$source")
done

# Validate we have sources
if [ ${#SOURCE_ARRAY_FILTERED[@]} -eq 0 ]; then
  echo "::error::No source images provided"
  exit 1
fi

echo "Creating manifest for ${IMAGE_NAME}"
echo "Tags: ${TAG_ARRAY[*]}"
echo "Sources: ${SOURCE_ARRAY_FILTERED[*]}"

# Create manifest for each tag
for tag in "${TAG_ARRAY[@]}"; do
  # Trim whitespace
  tag=$(echo "$tag" | xargs)

  manifest_ref="${IMAGE_NAME}:${tag}"
  echo "Creating manifest: ${manifest_ref}"

  # Execute imagetools create command with all source images
  echo "Executing: docker buildx imagetools create -t ${manifest_ref} ${SOURCE_ARRAY_FILTERED[*]}"
  docker buildx imagetools create -t "${manifest_ref}" "${SOURCE_ARRAY_FILTERED[@]}"

  # Inspect the created manifest
  echo "Inspecting manifest: ${manifest_ref}"
  docker buildx imagetools inspect "${manifest_ref}"
done

# Output the first tag as the primary manifest reference
echo "manifest=${IMAGE_NAME}:${TAG_ARRAY[0]}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
