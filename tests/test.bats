#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=maxwebgr/ddev-zed

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  # Generated files exist in .zed/ and carry the ownership marker
  for f in tasks.json debug.json; do
    assert_file_exist "${TESTDIR}/.zed/${f}"
    run grep -q '#ddev-generated' "${TESTDIR}/.zed/${f}"
    assert_success
  done
  # MCP settings are opt-in only
  assert_file_not_exist "${TESTDIR}/.zed/settings.json"
  # pathMappings uses Zed's worktree variable, resolved by Zed at debug time
  run grep -qF '"/var/www/html": "$ZED_WORKTREE_ROOT"' "${TESTDIR}/.zed/debug.json"
  assert_success
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  health_checks
}

@test "user-owned files are never overwritten or removed" {
  set -eu -o pipefail
  mkdir -p "${TESTDIR}/.zed"
  echo '[]' > "${TESTDIR}/.zed/tasks.json"
  run ddev add-on get "${DIR}"
  assert_success
  assert_output --partial "Skipped .zed/tasks.json"
  run cat "${TESTDIR}/.zed/tasks.json"
  assert_output "[]"
  run ddev add-on remove zed
  assert_success
  assert_file_exist "${TESTDIR}/.zed/tasks.json"
  assert_file_not_exist "${TESTDIR}/.zed/debug.json"
}

@test "skip message lists entries missing from user-owned files" {
  set -eu -o pipefail
  mkdir -p "${TESTDIR}/.zed"
  echo '[{ "label": "ddev: start", "command": "ddev", "args": ["start"] }]' > "${TESTDIR}/.zed/tasks.json"
  echo '{ "context_servers": {} }' > "${TESTDIR}/.zed/settings.json"
  DDEV_ZED_MCP=true run ddev add-on get "${DIR}"
  assert_success
  assert_output --partial 'Not found in your .zed/tasks.json: "ddev: stop", "ddev: restart"'
  refute_output --partial '"ddev: start"'
  assert_output --partial 'Not found in your .zed/settings.json: "ddev-mcp" context server'
}

@test "opt-in MCP settings" {
  set -eu -o pipefail
  DDEV_ZED_MCP=true run ddev add-on get "${DIR}"
  assert_success
  assert_file_exist "${TESTDIR}/.zed/settings.json"
}
