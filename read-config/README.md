# Read Docker Config Action

A reusable composite action that reads and validates Docker configuration files.

## Purpose

This action centralizes the logic for reading `.docker-config.json` files, making it reusable across multiple actions (like `build` and `manifest`). It ensures consistent validation and reading behavior.

## Usage

```yaml
steps:
  - name: Read Docker configuration
    uses: open-turo/actions-docker/read-config@v1
    id: config
    with:
      docker-config-file: .docker-config.json

  - name: Use parsed values
    run: |
      echo "Image: ${{ steps.config.outputs.image-name }}"
      echo "Dockerfile: ${{ steps.config.outputs.dockerfile }}"
      echo "Target: ${{ steps.config.outputs.target }}"
      echo "Tag suffix: ${{ steps.config.outputs.tag-suffix }}"
```

### With Custom Config Path

```yaml
steps:
  - name: Read custom config
    uses: open-turo/actions-docker/read-config@v1
    id: config
    with:
      docker-config-file: config/docker.json
```

## Inputs

| Name                 | Description                | Required | Default               |
| -------------------- | -------------------------- | -------- | --------------------- |
| `docker-config-file` | Path to docker config file | No       | `.docker-config.json` |

## Outputs

| Name         | Description                                                                                                               |
| ------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `image-name` | Docker image name from config (e.g., `org/image-name`)                                                                    |
| `dockerfile` | Path to Dockerfile (defaults to `./Dockerfile` if not in config)                                                          |
| `suffix`     | Custom suffix from config (empty string if not specified)                                                                 |
| `target`     | Build target stage for multi-stage builds (empty string if not specified)                                                 |
| `tag-suffix` | Combined tag suffix. If both suffix and target are specified: `-suffix-target`. If only one: `-value`. If neither: empty. |

## Configuration File Format

The action expects a JSON file with the following structure:

```json
{
  "imageName": "your-org/your-image",
  "dockerfile": "./Dockerfile",
  "target": "production"
}
```

### Fields

- **`imageName`** (required): Docker image name in format `org/name`
- **`dockerfile`** (optional): Path to Dockerfile, defaults to `./Dockerfile`
- **`suffix`** (optional): Custom suffix for image tags
- **`target`** (optional): Build target stage for multi-stage builds

### Tag Suffix Logic

The `tag-suffix` output is computed from `suffix` and `target` fields:

- **Both specified**: `-suffix-target` (e.g., `suffix: "v2"`, `target: "dev"` → `-v2-dev`)
- **Only suffix**: `-suffix` (e.g., `suffix: "v2"` → `-v2`)
- **Only target**: `-target` (e.g., `target: "dev"` → `-dev`)
- **Neither**: empty string

### Examples

**Minimal configuration:**

```json
{
  "imageName": "turo/my-service"
}
```

**With custom Dockerfile:**

```json
{
  "imageName": "turo/my-service",
  "dockerfile": "./docker/Dockerfile"
}
```

**With build target:**

```json
{
  "imageName": "turo/my-service",
  "dockerfile": "./Dockerfile",
  "target": "dev"
}
```

This will output `tag-suffix: "-dev"`, which can be used to tag images as `1.0.0-dev`.

**With suffix:**

```json
{
  "imageName": "turo/my-service",
  "dockerfile": "./Dockerfile",
  "suffix": "v2"
}
```

This will output `tag-suffix: "-v2"`, which can be used to tag images as `1.0.0-v2`.

**With both suffix and target:**

```json
{
  "imageName": "turo/my-service",
  "dockerfile": "./Dockerfile",
  "suffix": "v2",
  "target": "dev"
}
```

This will output `tag-suffix: "-v2-dev"`, which can be used to tag images as `1.0.0-v2-dev`.

## Validation

The action performs the following validation:

1. **File existence**: Fails if the specified config file doesn't exist
2. **Required fields**: Fails if `imageName` is missing or null
3. **JSON parsing**: Automatically fails if the file is not valid JSON (via `jq`)

## Error Handling

If validation fails, the action will:

- Output an error message using GitHub Actions annotations
- Exit with code 1
- Stop the workflow

Example error messages:

- `Docker config file not found: .docker-config.json`
- `imageName not found in .docker-config.json`

## Development

### Structure

- `action.yaml` - GitHub Action definition
- `parse-config.sh` - Parsing logic (externalized for testability)
- `test-parse-config.sh` - Test suite

### Running Tests

```bash
cd read-config
./test-parse-config.sh
```
