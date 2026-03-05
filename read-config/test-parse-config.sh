#!/bin/bash

# Test suite for parse-config.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSE_SCRIPT="${SCRIPT_DIR}/parse-config.sh"
TEST_DIR="${SCRIPT_DIR}/test-fixtures"
PASSED=0
FAILED=0

# Setup
setup() {
  mkdir -p "$TEST_DIR"
  export GITHUB_OUTPUT="${TEST_DIR}/github_output.txt"
}

# Teardown
teardown() {
  rm -rf "$TEST_DIR"
}

# Test helpers
assert_success() {
  local test_name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ${test_name}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} ${test_name}"
    ((FAILED++))
    return 1
  fi
}

assert_failure() {
  local test_name="$1"
  shift
  if ! "$@" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ${test_name}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} ${test_name}"
    ((FAILED++))
    return 1
  fi
}

assert_output_contains() {
  local test_name="$1"
  local expected="$2"
  local output="$3"

  if echo "$output" | grep -qF -- "$expected"; then
    echo -e "${GREEN}✓${NC} ${test_name}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}✗${NC} ${test_name} - Expected: ${expected}"
    echo "   Got: ${output}"
    ((FAILED++))
    return 1
  fi
}

# Tests
test_valid_config() {
  echo '{"imageName":"myorg/myimage","dockerfile":"./Dockerfile","target":"prod"}' > "$TEST_DIR/valid.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/valid.json" 2>&1)
  assert_output_contains "Parse valid config with all fields" "myorg/myimage" "$output"
  assert_output_contains "Dockerfile field" "./Dockerfile" "$output"
  assert_output_contains "Target field" "prod" "$output"
  assert_output_contains "Tag suffix" "-prod" "$output"

  # Check GITHUB_OUTPUT
  gh_output=$(cat "$GITHUB_OUTPUT")
  assert_output_contains "GITHUB_OUTPUT has image-name" "image-name=myorg/myimage" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has dockerfile" "dockerfile=./Dockerfile" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has target" "target=prod" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has tag-suffix" "tag-suffix=-prod" "$gh_output"
}

test_minimal_config() {
  echo '{"imageName":"myorg/minimal"}' > "$TEST_DIR/minimal.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/minimal.json" 2>&1)
  assert_output_contains "Parse minimal config (imageName only)" "myorg/minimal" "$output"
  assert_output_contains "Default dockerfile" "./Dockerfile" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  assert_output_contains "GITHUB_OUTPUT has default dockerfile" "dockerfile=./Dockerfile" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has empty target" "target=" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has empty tag-suffix" "tag-suffix=" "$gh_output"
}

test_config_with_target() {
  echo '{"imageName":"myorg/app","target":"dev"}' > "$TEST_DIR/with-target.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/with-target.json" 2>&1)
  assert_output_contains "Parse config with target" "Tag suffix: -dev" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  assert_output_contains "GITHUB_OUTPUT has tag-suffix with hyphen" "tag-suffix=-dev" "$gh_output"
}

test_config_without_target() {
  echo '{"imageName":"myorg/app"}' > "$TEST_DIR/no-target.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/no-target.json" 2>&1)
  assert_output_contains "Parse config without target (empty tag suffix)" "Tag suffix:" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  # Check that tag-suffix line exists and is empty after the equals sign
  if grep -q "^tag-suffix=$" "$GITHUB_OUTPUT"; then
    echo -e "${GREEN}✓${NC} GITHUB_OUTPUT has empty tag-suffix"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC} GITHUB_OUTPUT has empty tag-suffix"
    ((FAILED++))
  fi
}

test_missing_config_file() {
  assert_failure "Fail on missing config file" "$PARSE_SCRIPT" "$TEST_DIR/nonexistent.json"
}

test_missing_image_name() {
  echo '{"dockerfile":"./Dockerfile"}' > "$TEST_DIR/no-imagename.json"
  assert_failure "Fail on missing imageName" "$PARSE_SCRIPT" "$TEST_DIR/no-imagename.json"
}

test_null_image_name() {
  echo '{"imageName":null}' > "$TEST_DIR/null-imagename.json"
  assert_failure "Fail on null imageName" "$PARSE_SCRIPT" "$TEST_DIR/null-imagename.json"
}

test_invalid_json() {
  echo '{invalid json}' > "$TEST_DIR/invalid.json"
  assert_failure "Fail on invalid JSON" "$PARSE_SCRIPT" "$TEST_DIR/invalid.json"
}

test_custom_dockerfile() {
  echo '{"imageName":"myorg/custom","dockerfile":"./docker/Dockerfile.prod"}' > "$TEST_DIR/custom-dockerfile.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/custom-dockerfile.json" 2>&1)
  assert_output_contains "Parse custom dockerfile path" "./docker/Dockerfile.prod" "$output"
}

test_config_with_suffix_only() {
  echo '{"imageName":"myorg/app","suffix":"v2"}' > "$TEST_DIR/suffix-only.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/suffix-only.json" 2>&1)
  assert_output_contains "Parse config with suffix only" "Tag suffix: -v2" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  assert_output_contains "GITHUB_OUTPUT has suffix field" "suffix=v2" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has tag-suffix from suffix" "tag-suffix=-v2" "$gh_output"
}

test_config_with_suffix_and_target() {
  echo '{"imageName":"myorg/app","suffix":"v2","target":"dev"}' > "$TEST_DIR/suffix-and-target.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/suffix-and-target.json" 2>&1)
  assert_output_contains "Parse config with both suffix and target" "Tag suffix: -v2-dev" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  assert_output_contains "GITHUB_OUTPUT has suffix" "suffix=v2" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has target" "target=dev" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has combined tag-suffix" "tag-suffix=-v2-dev" "$gh_output"
}

test_config_target_only_still_works() {
  echo '{"imageName":"myorg/app","target":"prod"}' > "$TEST_DIR/target-only.json"
  > "$GITHUB_OUTPUT"

  output=$("$PARSE_SCRIPT" "$TEST_DIR/target-only.json" 2>&1)
  assert_output_contains "Parse config with target only (backward compat)" "Tag suffix: -prod" "$output"

  gh_output=$(cat "$GITHUB_OUTPUT")
  # Check that suffix line exists and is empty after the equals sign
  if grep -q "^suffix=$" "$GITHUB_OUTPUT"; then
    echo -e "${GREEN}✓${NC} GITHUB_OUTPUT has empty suffix"
    ((PASSED++))
  else
    echo -e "${RED}✗${NC} GITHUB_OUTPUT has empty suffix"
    ((FAILED++))
  fi
  assert_output_contains "GITHUB_OUTPUT has target" "target=prod" "$gh_output"
  assert_output_contains "GITHUB_OUTPUT has tag-suffix from target" "tag-suffix=-prod" "$gh_output"
}

# Run tests
echo "Running parse-config.sh tests..."
echo ""

setup

test_valid_config
test_minimal_config
test_config_with_target
test_config_without_target
test_missing_config_file
test_missing_image_name
test_null_image_name
test_invalid_json
test_custom_dockerfile
test_config_with_suffix_only
test_config_with_suffix_and_target
test_config_target_only_still_works

teardown

# Summary
echo ""
echo "================================"
echo -e "Tests passed: ${GREEN}${PASSED}${NC}"
echo -e "Tests failed: ${RED}${FAILED}${NC}"
echo "================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
