# GitHub Action Build Docker

Build and push Docker images with native or cross-platform support.

## Features

- Native builds by default (no QEMU overhead)
- Optional QEMU for cross-platform builds
- Docker layer caching with registry backend
- Flexible build arguments, secrets, and contexts
- Single platform per invocation (for multi-arch orchestration)
- Outputs image digest for manifest creation

## Prerequisites

Create a `.docker-config.json` file in your repository root:

```json
{
  "imageName": "your-org/your-image",
  "dockerfile": "./Dockerfile"
}
```

- `imageName` (required): Docker image name in format `org/name`
- `dockerfile` (optional): Path to Dockerfile, defaults to `./Dockerfile`
- `target` (optional): Build target stage for multi-stage builds. When specified, all image tags will automatically be suffixed with `-{target}`
- `metadata-tags` (optional): Docker metadata-action tags input (multiline string). If specified, overrides the action input.
- `metadata-flavor` (optional): Docker metadata-action flavor input (multiline string). If specified, overrides the action input.

**Example:**

```json
{
  "imageName": "turo/my-microservice",
  "dockerfile": "./Dockerfile"
}
```

**Example with target:**

```json
{
  "imageName": "turo/my-microservice",
  "dockerfile": "./Dockerfile",
  "target": "dev"
}
```

This will build the `dev` stage and automatically tag images with the `-dev` suffix (e.g., `1.0.0-dev` instead of `1.0.0`).

**Example with custom metadata:**

```json
{
  "imageName": "turo/my-microservice",
  "dockerfile": "./Dockerfile",
  "metadata-tags": "type=semver,pattern={{version}}\ntype=semver,pattern={{major}}.{{minor}}",
  "metadata-flavor": "latest=true"
}
```

This allows you to centralize Docker metadata configuration in the config file rather than duplicating it across workflows.

**Complete example with all options:**

```json
{
  "imageName": "turo/my-microservice",
  "dockerfile": "./Dockerfile",
  "target": "production",
  "metadata-tags": "type=ref,event=branch\ntype=ref,event=pr\ntype=semver,pattern={{version}}\ntype=semver,pattern={{major}}.{{minor}}\ntype=semver,pattern={{major}}",
  "metadata-flavor": "latest=false"
}
```

Note: When specifying multiline values in JSON, use `\n` for newlines.

## Usage

### Basic Usage

```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4

  - name: Build and push Docker image
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: 1.0.0
```

### With Semantic Release

```yaml
steps:
  - name: Release
    uses: open-turo/actions-node/release@v5
    id: release
    with:
      github-token: ${{ secrets.GITHUB_TOKEN }}

  - name: Build and push
    if: steps.release.outputs.new-release-published == 'true'
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: ${{ steps.release.outputs.new-release-version }}
      metadata-tags: |
        type=semver,pattern={{version}},value=${{ steps.release.outputs.new-release-version }}
        type=semver,pattern={{major}}.{{minor}},value=${{ steps.release.outputs.new-release-version }}
```

### Build for Specific Platform

```yaml
steps:
  - name: Build ARM64 image
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: 1.0.0
      image-platform: linux/arm64
      install-qemu: true # Only needed if building on AMD64 runner
```

### Local Build for Testing

```yaml
steps:
  - name: Build image locally
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: test
      push: false
      load: true

  - name: Run integration tests
    run: |
      docker run my-org/my-image:test
```

### Security Scanning

```yaml
steps:
  - name: Build image
    uses: open-turo/actions-docker/build@v1
    id: build
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: ${{ github.sha }}
      push: false
      load: true

  - name: Scan image
    uses: aquasecurity/trivy-action@master
    with:
      image-ref: ${{ steps.build.outputs.image }}
```

### With Build Arguments

```yaml
steps:
  - name: Build with custom args
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: 1.0.0
      build-args: |
        NODE_ENV=production
        API_URL=https://api.example.com
```

### With Build Secrets

For secrets like NPM tokens, Artifactory credentials, etc:

```yaml
steps:
  - name: Build with secrets
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: 1.0.0
      secrets: |
        NPM_TOKEN=${{ secrets.NPM_TOKEN }}
        ARTIFACTORY_USERNAME=${{ secrets.ARTIFACTORY_USERNAME }}
        ARTIFACTORY_AUTH_TOKEN=${{ secrets.ARTIFACTORY_AUTH_TOKEN }}
```

Then in your Dockerfile:

```dockerfile
RUN --mount=type=secret,id=NPM_TOKEN \
    echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/NPM_TOKEN)" > .npmrc && \
    npm install
```

### Disable Caching

```yaml
steps:
  - name: Build without cache
    uses: open-turo/actions-docker/build@v1
    with:
      dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
      dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
      image-version: 1.0.0
      cache: false
```

## Multi-Architecture Builds

For multi-architecture images, invoke this action separately for each platform, then create a manifest:

```yaml
jobs:
  build-amd64:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build AMD64
        uses: open-turo/actions-docker/build@v1
        id: build-amd64
        with:
          dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
          dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
          image-version: ${{ needs.release.outputs.version }}
          image-platform: linux/amd64
          push: true

    outputs:
      digest: ${{ steps.build-amd64.outputs.digest }}

  build-arm64:
    runs-on: ubuntu-latest # or use ARM64 runners for native builds
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build ARM64
        uses: open-turo/actions-docker/build@v1
        id: build-arm64
        with:
          dockerhub-user: ${{ secrets.DOCKER_USERNAME }}
          dockerhub-password: ${{ secrets.DOCKER_PASSWORD }}
          image-version: ${{ needs.release.outputs.version }}
          image-platform: linux/arm64
          push: true
          install-qemu: true # Only if cross-compiling on AMD64

    outputs:
      digest: ${{ steps.build-arm64.outputs.digest }}

  create-manifest:
    needs: [build-amd64, build-arm64]
    runs-on: ubuntu-latest
    steps:
      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Create multi-arch manifest
        env:
          IMAGE_NAME: your-org/your-image
          VERSION: ${{ needs.release.outputs.version }}
        run: |
          docker buildx imagetools create -t ${IMAGE_NAME}:${VERSION} \
            ${IMAGE_NAME}@${{ needs.build-amd64.outputs.digest }} \
            ${IMAGE_NAME}@${{ needs.build-arm64.outputs.digest }}
```

## Inputs

| Name                 | Description                                       | Required | Default               |
| -------------------- | ------------------------------------------------- | -------- | --------------------- |
| `docker-config-file` | Path to docker config file                        | No       | `.docker-config.json` |
| `dockerhub-user`     | DockerHub username                                | Yes      |                       |
| `dockerhub-password` | DockerHub password                                | Yes      |                       |
| `image-version`      | Docker image version/tag                          | Yes      |                       |
| `image-platform`     | Target platform (e.g., linux/amd64, linux/arm64)  | No       | `linux/amd64`         |
| `push`               | Push image to registry                            | No       | `true`                |
| `load`               | Load image to local docker (single-platform only) | No       | `false`               |
| `cache`              | Enable Docker layer caching                       | No       | `true`                |
| `cache-tag`          | Cache tag name                                    | No       | `buildcache`          |
| `metadata-tags`      | Docker metadata-action tags input                 | No       |                       |
| `metadata-flavor`    | Docker metadata-action flavor input               | No       | `latest=false`        |
| `build-args`         | Build arguments (KEY=VALUE, one per line)         | No       |                       |
| `secrets`            | Build secrets (KEY=VALUE, one per line)           | No       |                       |
| `build-contexts`     | Build contexts (KEY=VALUE, one per line)          | No       |                       |
| `install-qemu`       | Install QEMU for cross-platform builds            | No       | `false`               |
| `qemu-platforms`     | QEMU platforms (defaults to image-platform)       | No       |                       |

## Outputs

| Name         | Description                     |
| ------------ | ------------------------------- |
| `image-name` | Docker image name               |
| `image-tag`  | Docker image tag                |
| `image`      | Full image reference (name:tag) |
| `digest`     | Image digest                    |

## Standard Build Arguments

These build arguments are automatically provided to your Dockerfile:

- `GIT_COMMIT` - Current git commit SHA
- `BUILDTIME` - Build timestamp
- `VERSION` - Image version (from `image-version` input)
- `REVISION` - Image revision (from `image-version` input)
- `BRANCH` - Git branch name

Example Dockerfile usage:

```dockerfile
ARG VERSION
ARG GIT_COMMIT
ARG BUILDTIME

LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILDTIME}"
```

## Notes

- **QEMU Performance**: Cross-platform builds using QEMU are significantly slower than native builds. Use native runners (ARM64 runners for ARM64 builds) when possible.
- **Load Limitation**: You cannot use `load: true` with multi-platform builds. Load is only supported for single-platform builds.
- **Caching**: Layer caching uses the registry backend with the specified `cache-tag`. The cache is stored alongside your image in the registry.
