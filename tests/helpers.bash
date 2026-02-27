#!/bin/bash
#
# Shared test helpers
#

# shellcheck disable=SC2034
IMP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup_test_repo() {
   TEST_DIR=$(mktemp -d)
   cd "$TEST_DIR" || exit 1
   git init -b main
   git config user.email "test@test.com"
   git config user.name "Test"
   echo ".bin" >> .git/info/exclude
   echo "hello" > file.txt
   git add file.txt
   git commit -m "Initial commit"
}

teardown_test_repo() {
   cd / || true
   rm -rf "$TEST_DIR"
}

# Disable gum in tests so all tests use fallback paths
export HAS_GUM=false
export IMP_NO_GUM=1

# Mock AI to avoid real API calls
mock_ai() {
   local response="$1"

   # Create a fake claude that returns canned response
   mkdir -p "$TEST_DIR/.bin"
   printf '%s\n' '#!/bin/bash' "printf '%s\\n' $(printf '%q' "$response")" > "$TEST_DIR/.bin/claude"
   chmod +x "$TEST_DIR/.bin/claude"
   export PATH="$TEST_DIR/.bin:$PATH"
   export IMP_AI_PROVIDER=claude
}
