#!/usr/bin/env bash

# Test script for create-manifest.sh
# Mocks docker commands and verifies correct behavior

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create a temporary directory for mock docker
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

# Create mock docker script
cat > "$MOCK_DIR/docker" << 'DOCKER_MOCK_EOF'
#!/usr/bin/env bash
echo "[MOCK] docker $*"

# Simulate successful execution
if [[ "$1" == "buildx" && "$2" == "imagetools" ]]; then
  if [[ "$3" == "create" ]]; then
    # Mock imagetools create
    exit 0
  elif [[ "$3" == "inspect" ]]; then
    # Mock imagetools inspect
    echo "Name:      $4"
    echo "MediaType: application/vnd.docker.distribution.manifest.list.v2+json"
    echo "Digest:    sha256:mock1234567890"
    echo ""
    echo "Manifests:"
    echo "  Name:      $4"
    echo "  MediaType: application/vnd.docker.distribution.manifest.v2+json"
    echo "  Platform:  linux/amd64"
    echo ""
    echo "  Name:      $4"
    echo "  MediaType: application/vnd.docker.distribution.manifest.v2+json"
    echo "  Platform:  linux/arm64"
    exit 0
  fi
fi
exit 1
DOCKER_MOCK_EOF

chmod +x "$MOCK_DIR/docker"

# Add mock docker to PATH
export PATH="$MOCK_DIR:$PATH"

# Test helper functions
pass_test() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $1"
}

fail_test() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $1"
  echo "  Error: $2"
}

run_test() {
  TESTS_RUN=$((TESTS_RUN + 1))
  local test_name="$1"
  echo ""
  echo "Running: $test_name"
}

# Test 1: Basic single tag with two sources
test_basic_single_tag() {
  run_test "Basic single tag with two sources"

  local output
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0" \
    "myorg/myimage@sha256:amd64digest
myorg/myimage@sha256:arm64digest" 2>&1)

  if echo "$output" | grep -q "Creating manifest: myorg/myimage:1.0.0"; then
    if echo "$output" | grep -q "docker buildx imagetools create -t myorg/myimage:1.0.0 myorg/myimage@sha256:amd64digest myorg/myimage@sha256:arm64digest"; then
      pass_test "Basic single tag works"
    else
      fail_test "Basic single tag" "Command not formed correctly"
    fi
  else
    fail_test "Basic single tag" "Manifest not created"
  fi
}

# Test 2: Multiple tags
test_multiple_tags() {
  run_test "Multiple tags"

  local output
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0,latest" \
    "myorg/myimage@sha256:amd64digest
myorg/myimage@sha256:arm64digest" 2>&1)

  if echo "$output" | grep -q "Creating manifest: myorg/myimage:1.0.0"; then
    if echo "$output" | grep -q "Creating manifest: myorg/myimage:latest"; then
      pass_test "Multiple tags works"
    else
      fail_test "Multiple tags" "Second tag not created"
    fi
  else
    fail_test "Multiple tags" "First tag not created"
  fi
}

# Test 3: Whitespace handling
test_whitespace_handling() {
  run_test "Whitespace handling in tags and sources"

  local output
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    " 1.0.0 , latest " \
    "  myorg/myimage@sha256:amd64digest
  myorg/myimage@sha256:arm64digest  " 2>&1)

  if echo "$output" | grep -q "Creating manifest: myorg/myimage:1.0.0"; then
    if echo "$output" | grep -q "Creating manifest: myorg/myimage:latest"; then
      pass_test "Whitespace handling works"
    else
      fail_test "Whitespace handling" "Trimming failed"
    fi
  else
    fail_test "Whitespace handling" "Basic parsing failed"
  fi
}

# Test 4: Empty lines in sources
test_empty_lines() {
  run_test "Empty lines in sources are filtered"

  local output
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0" \
    "myorg/myimage@sha256:amd64digest

myorg/myimage@sha256:arm64digest
" 2>&1)

  if echo "$output" | grep -q "Sources: myorg/myimage@sha256:amd64digest myorg/myimage@sha256:arm64digest"; then
    pass_test "Empty lines filtered correctly"
  else
    fail_test "Empty lines" "Empty lines not filtered"
  fi
}

# Test 5: Missing arguments
test_missing_arguments() {
  run_test "Missing arguments error handling"

  local output
  local exit_code=0
  output=$("$SCRIPT_DIR/create-manifest.sh" 2>&1) || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    if echo "$output" | grep -q "Usage:"; then
      pass_test "Missing arguments handled correctly"
    else
      fail_test "Missing arguments" "No usage message shown"
    fi
  else
    fail_test "Missing arguments" "Should have exited with error"
  fi
}

# Test 6: No sources provided
test_no_sources() {
  run_test "No sources provided error handling"

  local output
  local exit_code=0
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0" \
    "" 2>&1) || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    if echo "$output" | grep -q "No source images provided"; then
      pass_test "No sources error handled correctly"
    else
      fail_test "No sources" "Wrong error message"
    fi
  else
    fail_test "No sources" "Should have exited with error"
  fi
}

# Test 7: GITHUB_OUTPUT file
test_github_output() {
  run_test "GITHUB_OUTPUT file writing"

  local tmpfile
  tmpfile=$(mktemp)

  GITHUB_OUTPUT="$tmpfile" "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0,latest" \
    "myorg/myimage@sha256:amd64digest
myorg/myimage@sha256:arm64digest" >/dev/null 2>&1

  if grep -q "manifest=myorg/myimage:1.0.0" "$tmpfile"; then
    pass_test "GITHUB_OUTPUT written correctly"
  else
    fail_test "GITHUB_OUTPUT" "Output not written to file"
  fi

  rm -f "$tmpfile"
}

# Test 8: Tag-based sources (not just digests)
test_tag_based_sources() {
  run_test "Tag-based source references"

  local output
  output=$(GITHUB_OUTPUT=/dev/null "$SCRIPT_DIR/create-manifest.sh" \
    "myorg/myimage" \
    "1.0.0" \
    "myorg/myimage:1.0.0-amd64
myorg/myimage:1.0.0-arm64" 2>&1)

  if echo "$output" | grep -q "myorg/myimage:1.0.0-amd64"; then
    if echo "$output" | grep -q "myorg/myimage:1.0.0-arm64"; then
      pass_test "Tag-based sources work"
    else
      fail_test "Tag-based sources" "Second tag not included"
    fi
  else
    fail_test "Tag-based sources" "First tag not included"
  fi
}

# Run all tests
echo "========================================="
echo "Running create-manifest.sh tests"
echo "========================================="

test_basic_single_tag
test_multiple_tags
test_whitespace_handling
test_empty_lines
test_missing_arguments
test_no_sources
test_github_output
test_tag_based_sources

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
  exit 1
else
  echo -e "Tests failed: $TESTS_FAILED"
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
