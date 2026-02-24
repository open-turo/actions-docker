#!/usr/bin/env bash

# Shared script to read Docker config file
# Usage: read-docker-config.sh <config-file-path>
#
# Reads docker config JSON and outputs values to GITHUB_OUTPUT:
#   - image-name: Docker image name (required)
#   - dockerfile: Path to Dockerfile (defaults to ./Dockerfile)
#   - target: Build target stage (optional)
#   - tag-suffix: Tag suffix based on target (e.g., -dev)
#   - metadata-tags: Docker metadata-action tags input (optional)
#   - metadata-flavor: Docker metadata-action flavor input (optional)

set -euo pipefail

# Check for required arguments
if [ $# -lt 1 ]; then
  echo "::error::Usage: read-docker-config.sh <config-file-path>"
  exit 1
fi

DOCKER_CONFIG_FILE="$1"

# Validate docker config file exists
if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
  echo "::error::Docker config file not found: $DOCKER_CONFIG_FILE" && exit 1
fi

# Parse config file
image_name=$(jq -r .imageName "$DOCKER_CONFIG_FILE")
if [ -z "$image_name" ] || [ "$image_name" = "null" ]; then
  echo "::error::imageName not found in $DOCKER_CONFIG_FILE" && exit 1
fi
echo "image-name: ${image_name}"
echo "image-name=${image_name}" >> "${GITHUB_OUTPUT:-/dev/stdout}"

dockerfile=$(jq -r '.dockerfile // "./Dockerfile"' "$DOCKER_CONFIG_FILE")
echo "Dockerfile: ${dockerfile}"
echo "dockerfile=${dockerfile}" >> "${GITHUB_OUTPUT:-/dev/stdout}"

target=$(jq -r '.target // ""' "$DOCKER_CONFIG_FILE")
echo "Target: ${target}"
echo "target=${target}" >> "${GITHUB_OUTPUT:-/dev/stdout}"

# Set tag suffix if target is specified
if [ -n "$target" ]; then
  tag_suffix="-${target}"
else
  tag_suffix=""
fi
echo "Tag suffix: ${tag_suffix}"
echo "tag-suffix=${tag_suffix}" >> "${GITHUB_OUTPUT:-/dev/stdout}"

# Read metadata-tags from config if present
metadata_tags=$(jq -r '.["metadata-tags"] // ""' "$DOCKER_CONFIG_FILE")
if [ -n "$metadata_tags" ] && [ "$metadata_tags" != "null" ]; then
  echo "Metadata tags from config: ${metadata_tags}"
  echo "metadata-tags=${metadata_tags}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
else
  echo "metadata-tags=" >> "${GITHUB_OUTPUT:-/dev/stdout}"
fi

# Read metadata-flavor from config if present
metadata_flavor=$(jq -r '.["metadata-flavor"] // ""' "$DOCKER_CONFIG_FILE")
if [ -n "$metadata_flavor" ] && [ "$metadata_flavor" != "null" ]; then
  echo "Metadata flavor from config: ${metadata_flavor}"
  echo "metadata-flavor=${metadata_flavor}" >> "${GITHUB_OUTPUT:-/dev/stdout}"
else
  echo "metadata-flavor=" >> "${GITHUB_OUTPUT:-/dev/stdout}"
fi
