# GitHub Action Create Multi-Arch Docker Manifest

Combine platform-specific Docker images into a single multi-arch manifest.

## Features

- Combine ARM64 and AMD64 images built on native runners
- Support multiple tags for the manifest
- Use Docker Buildx imagetools for manifest creation
- Simple, explicit inputs (no config file needed)
- Outputs manifest reference for further use

## Usage

### Basic Usage

```yaml
- name: Create multi-arch manifest
  uses: open-turo/actions-docker/manifest@v1
  with:
    image-name: myorg/myimage
    dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
    dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
    tags: 1.0.0,latest
    sources: |
      myorg/myimage@${{ needs.build-amd64.outputs.digest }}
      myorg/myimage@${{ needs.build-arm64.outputs.digest }}
```

### Using Docker Config File

If you have a `.docker-config.json` file (same format as the build action), you can reference it instead of providing the image name directly:

```yaml
- name: Create multi-arch manifest
  uses: open-turo/actions-docker/manifest@v1
  with:
    docker-config-file: .docker-config.json
    dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
    dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
    tags: 1.0.0,latest
    sources: |
      ${{ needs.build-amd64.outputs.image }}
      ${{ needs.build-arm64.outputs.image }}
```

### Using Tag-Based References

Instead of digests, you can also use tag-based references:

```yaml
- name: Create multi-arch manifest
  uses: open-turo/actions-docker/manifest@v1
  with:
    image-name: myorg/myimage
    dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
    dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
    tags: 1.0.0,latest
    sources: |
      myorg/myimage:1.0.0-amd64
      myorg/myimage:1.0.0-arm64
```

## Inputs

| Name                 | Description                                                                                             | Required    | Default        |
| -------------------- | ------------------------------------------------------------------------------------------------------- | ----------- | -------------- |
| `docker-config-file` | Path to docker config file. If provided, image-name will be read from config                            | No          |                |
| `image-name`         | Docker image name (e.g., org/image-name). Required if docker-config-file is not provided                | Conditional |                |
| `dockerhub-user`     | DockerHub username                                                                                      | Yes         |                |
| `dockerhub-password` | DockerHub password                                                                                      | Yes         |                |
| `metadata-tags`      | Docker metadata-action tags input. See [docs](https://github.com/docker/metadata-action#tags-input)     | No          | See action     |
| `metadata-flavor`    | Docker metadata-action flavor input. See [docs](https://github.com/docker/metadata-action#flavor-input) | No          | `latest=false` |
| `sources`            | List of source images to combine (one per line). Can be digests or tags (e.g., org/image@sha256:...)    | Yes         |                |

## Outputs

| Name       | Description                    |
| ---------- | ------------------------------ |
| `manifest` | The created manifest reference |

## How It Works

This action uses `docker buildx imagetools create` to combine multiple platform-specific images into a single multi-arch manifest. When users pull the image, Docker automatically selects the appropriate platform-specific image based on their architecture.

## Notes

- **Digests vs Tags**: Using digests (e.g., `@sha256:...`) is more reliable than tags as it ensures you're referencing the exact image that was built
- **Multiple Tags**: You can create multiple tags for the same manifest (e.g., `1.0.0` and `latest`) by providing a comma-separated list
- **Authentication**: The action needs DockerHub credentials to push the manifest to the registry

For a complete multi-architecture build example, see the [main README](../README.md#multi-architecture-builds).
