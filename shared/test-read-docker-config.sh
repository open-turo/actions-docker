#!/usr/bin/env bash

# Test script for read-docker-config.sh
# Run with: ./test-read-docker-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
EXIT_CODE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

log_test() {
  echo -e "${YELLOW}TEST:${NC} $1"
}

log_pass() {
  echo -e "${GREEN}PASS:${NC} $1"
}

log_fail() {
  echo -e "${RED}FAIL:${NC} $1"
  EXIT_CODE=1
}

# Test 1: Valid config with all fields
log_test "Valid config with all fields"
cat > "$TEST_DIR/config1.json" <<EOF
{
  "imageName": "myorg/myimage",
  "dockerfile": "./custom/Dockerfile",
  "target": "production",
  "metadata-tags": "type=semver,pattern={{version}}",
  "metadata-flavor": "latest=true"
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output1.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config1.json" > /dev/null 2>&1; then
  if grep -q "image-name=myorg/myimage" "$GITHUB_OUTPUT" && \
     grep -q "dockerfile=./custom/Dockerfile" "$GITHUB_OUTPUT" && \
     grep -q "target=production" "$GITHUB_OUTPUT" && \
     grep -q "tag-suffix=-production" "$GITHUB_OUTPUT" && \
     grep -q "metadata-tags=type=semver,pattern={{version}}" "$GITHUB_OUTPUT" && \
     grep -q "metadata-flavor=latest=true" "$GITHUB_OUTPUT"; then
    log_pass "All fields read correctly"
  else
    log_fail "Fields not read correctly"
    cat "$GITHUB_OUTPUT"
  fi
else
  log_fail "Script failed with valid config"
fi

# Test 2: Minimal config (only imageName)
log_test "Minimal config with only imageName"
cat > "$TEST_DIR/config2.json" <<EOF
{
  "imageName": "myorg/myimage"
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output2.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config2.json" > /dev/null 2>&1; then
  if grep -q "image-name=myorg/myimage" "$GITHUB_OUTPUT" && \
     grep -q "dockerfile=./Dockerfile" "$GITHUB_OUTPUT" && \
     grep -q "target=$" "$GITHUB_OUTPUT" && \
     grep -q "tag-suffix=$" "$GITHUB_OUTPUT" && \
     grep -q "metadata-tags=$" "$GITHUB_OUTPUT" && \
     grep -q "metadata-flavor=$" "$GITHUB_OUTPUT"; then
    log_pass "Defaults applied correctly"
  else
    log_fail "Defaults not applied correctly"
    cat "$GITHUB_OUTPUT"
  fi
else
  log_fail "Script failed with minimal config"
fi

# Test 3: Config with target but no metadata
log_test "Config with target but no metadata"
cat > "$TEST_DIR/config3.json" <<EOF
{
  "imageName": "myorg/myimage",
  "target": "dev"
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output3.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config3.json" > /dev/null 2>&1; then
  if grep -q "tag-suffix=-dev" "$GITHUB_OUTPUT" && \
     grep -q "metadata-tags=$" "$GITHUB_OUTPUT"; then
    log_pass "Target suffix generated, metadata empty"
  else
    log_fail "Target or metadata not handled correctly"
    cat "$GITHUB_OUTPUT"
  fi
else
  log_fail "Script failed with target config"
fi

# Test 4: Missing config file
log_test "Missing config file"
export GITHUB_OUTPUT="$TEST_DIR/output4.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/nonexistent.json" > /dev/null 2>&1; then
  log_fail "Script should fail with missing config"
else
  log_pass "Script correctly fails with missing config"
fi

# Test 5: Missing imageName
log_test "Config missing imageName"
cat > "$TEST_DIR/config5.json" <<EOF
{
  "dockerfile": "./Dockerfile"
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output5.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config5.json" > /dev/null 2>&1; then
  log_fail "Script should fail without imageName"
else
  log_pass "Script correctly fails without imageName"
fi

# Test 6: Metadata with multiline format (newlines as \n)
log_test "Config with multiline metadata-tags"
cat > "$TEST_DIR/config6.json" <<EOF
{
  "imageName": "myorg/myimage",
  "metadata-tags": "type=ref,event=branch\ntype=ref,event=pr\ntype=semver,pattern={{version}}"
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output6.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config6.json" > /dev/null 2>&1; then
  # Check if the metadata-tags contains the multiline value
  if grep -q "metadata-tags=type=ref,event=branch" "$GITHUB_OUTPUT"; then
    log_pass "Multiline metadata-tags handled correctly"
  else
    log_fail "Multiline metadata-tags not handled correctly"
    cat "$GITHUB_OUTPUT"
  fi
else
  log_fail "Script failed with multiline metadata"
fi

# Test 7: Empty metadata fields (null vs empty string)
log_test "Config with null metadata fields"
cat > "$TEST_DIR/config7.json" <<EOF
{
  "imageName": "myorg/myimage",
  "metadata-tags": null,
  "metadata-flavor": null
}
EOF

export GITHUB_OUTPUT="$TEST_DIR/output7.txt"
if "$SCRIPT_DIR/read-docker-config.sh" "$TEST_DIR/config7.json" > /dev/null 2>&1; then
  if grep -q "metadata-tags=$" "$GITHUB_OUTPUT" && \
     grep -q "metadata-flavor=$" "$GITHUB_OUTPUT"; then
    log_pass "Null metadata fields handled as empty"
  else
    log_fail "Null metadata fields not handled correctly"
    cat "$GITHUB_OUTPUT"
  fi
else
  log_fail "Script failed with null metadata"
fi

# Summary
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
else
  echo -e "${RED}Some tests failed${NC}"
fi

exit $EXIT_CODE
