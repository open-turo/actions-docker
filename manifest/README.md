# GitHub Action Create Multi-Arch Docker Manifest

Combine platform-specific Docker images into a single multi-arch manifest.

## Features

- Combine ARM64 and AMD64 images built on native runners
- Support multiple tags for the manifest
- Use Docker Buildx imagetools for manifest creation
- Read configuration from `.docker-config.json` or use explicit inputs
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
    metadata-tags: |
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}
    sources: |
      myorg/myimage@${{ needs.build-amd64.outputs.digest }}
      myorg/myimage@${{ needs.build-arm64.outputs.digest }}
```

### Using Config File

If you have a `.docker-config.json` file (same as used by the build action), you can omit the `image-name` and metadata inputs:

```json
{
  "imageName": "myorg/myimage",
  "metadata-tags": "type=semver,pattern={{version}}\ntype=semver,pattern={{major}}.{{minor}}",
  "metadata-flavor": "latest=true"
}
```

```yaml
- name: Create multi-arch manifest
  uses: open-turo/actions-docker/manifest@v1
  with:
    dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
    dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
    sources: |
      myorg/myimage@${{ needs.build-amd64.outputs.digest }}
      myorg/myimage@${{ needs.build-arm64.outputs.digest }}
```

The action will read `image-name`, `metadata-tags`, and `metadata-flavor` from the config file. Values in the config file override action inputs.

**Note:** The `dockerfile` and `target` fields in the config file are only used by the build action and are ignored by the manifest action.

### Using Tag-Based References

Instead of digests, you can also use tag-based references:

```yaml
- name: Create multi-arch manifest
  uses: open-turo/actions-docker/manifest@v1
  with:
    image-name: myorg/myimage
    dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
    dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
    metadata-tags: |
      type=semver,pattern={{version}}
    metadata-flavor: latest=true
    sources: |
      myorg/myimage:1.0.0-amd64
      myorg/myimage:1.0.0-arm64
```

## Inputs

| Name                 | Description                                                                                          | Required | Default               |
| -------------------- | ---------------------------------------------------------------------------------------------------- | -------- | --------------------- |
| `docker-config-file` | Path to docker config file                                                                           | No       | `.docker-config.json` |
| `image-name`         | Docker image name (e.g., org/image-name). If not provided, read from config file.                    | No       |                       |
| `dockerhub-user`     | DockerHub username                                                                                   | Yes      |                       |
| `dockerhub-password` | DockerHub password                                                                                   | Yes      |                       |
| `metadata-tags`      | Docker metadata-action tags input. If specified in config file, config value is used.                | No       |                       |
| `metadata-flavor`    | Docker metadata-action flavor input. If specified in config file, config value is used.              | No       | `latest=false`        |
| `sources`            | List of source images to combine (one per line). Can be digests or tags (e.g., org/image@sha256:...) | Yes      |                       |

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
