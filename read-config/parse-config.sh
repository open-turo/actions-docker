#!/bin/bash
set -e

# Parse docker config file
# Args:
#   $1: Path to docker config file
# Outputs to GITHUB_OUTPUT:
#   image-name: Docker image name
#   dockerfile: Path to Dockerfile
#   suffix: Custom suffix
#   target: Build target
#   tag-suffix: Combined tag suffix (suffix + target)

DOCKER_CONFIG_FILE="${1:-.docker-config.json}"

# Validate docker config file exists
if [ ! -f "$DOCKER_CONFIG_FILE" ]; then
  echo "::error::Docker config file not found: $DOCKER_CONFIG_FILE" >&2
  exit 1
fi

# Parse config file
image_name=$(jq -r .imageName "$DOCKER_CONFIG_FILE")
if [ -z "$image_name" ] || [ "$image_name" = "null" ]; then
  echo "::error::imageName not found in $DOCKER_CONFIG_FILE" >&2
  exit 1
fi

dockerfile=$(jq -r '.dockerfile // "./Dockerfile"' "$DOCKER_CONFIG_FILE")
suffix=$(jq -r '.suffix // ""' "$DOCKER_CONFIG_FILE")
target=$(jq -r '.target // ""' "$DOCKER_CONFIG_FILE")

# Build tag suffix from suffix and target
# If both are specified: -suffix-target
# If only suffix: -suffix
# If only target: -target
# If neither: empty
tag_suffix=""
if [ -n "$suffix" ] && [ -n "$target" ]; then
  tag_suffix="-${suffix}-${target}"
elif [ -n "$suffix" ]; then
  tag_suffix="-${suffix}"
elif [ -n "$target" ]; then
  tag_suffix="-${target}"
fi

# Output results
echo "image-name: ${image_name}"
echo "Dockerfile: ${dockerfile}"
echo "Suffix: ${suffix}"
echo "Target: ${target}"
echo "Tag suffix: ${tag_suffix}"

# Write to GITHUB_OUTPUT if in GitHub Actions environment
if [ -n "$GITHUB_OUTPUT" ]; then
  {
    echo "image-name=${image_name}"
    echo "dockerfile=${dockerfile}"
    echo "suffix=${suffix}"
    echo "target=${target}"
    echo "tag-suffix=${tag_suffix}"
  } >> "$GITHUB_OUTPUT"
fi
