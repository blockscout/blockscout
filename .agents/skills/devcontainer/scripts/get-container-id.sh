#!/usr/bin/env bash
# Selects the container runtime for the current project and finds its running
# container.
#
# Prints "<runtime> <container-id>" on stdout and exits 0 if a container is
# found. <runtime> is one of:
#   apple         Apple `container` started by .devcontainer/apple-container/bs-container
#   devcontainer  docker devcontainer, driven by the devcontainer CLI
#   docker        docker devcontainer, driven by plain `docker exec`
# Otherwise prints a message on stderr and exits non-zero.
#
# The runtime is taken from BS_CONTAINER_RUNTIME (apple | devcontainer) in
# .devcontainer/.blockscout_config. Only that line is read; the file is not
# sourced on the host. Without the variable:
#   1. If the `container` CLI is installed, use the Apple container. If none
#      runs for the project, a running docker devcontainer is used instead.
#   2. Otherwise, if the devcontainer CLI or docker is installed, use the
#      docker devcontainer.

set -euo pipefail

PROJECT_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CONFIG_FILE="$PROJECT_ROOT/.devcontainer/.blockscout_config"

APPLE_UP_COMMAND="$PROJECT_ROOT/.devcontainer/apple-container/bs-container up"
DEVCONTAINER_UP_COMMAND="devcontainer up --workspace-folder $PROJECT_ROOT"

have() {
  command -v "$1" >/dev/null 2>&1
}

fail() {
  printf '%s\n' "$@" >&2
  exit 1
}

fail_not_found() {
  fail "No running container found for ${PROJECT_ROOT}" "$1"
}

read_configured_runtime() {
  [ -f "$CONFIG_FILE" ] || return 0
  sed -nE "s/^[[:space:]]*(export[[:space:]]+)?BS_CONTAINER_RUNTIME=[\"']?([^\"'[:space:]#]*).*$/\2/p" \
    "$CONFIG_FILE" | tail -n 1
}

require_jq() {
  have jq || fail "The jq CLI is required to find the Apple container. Install it, for example with 'brew install jq'."
}

# Prints the ID of the running Apple container for the project, if any.
# Returns 2 if the container system service is not running.
# Call require_jq first: a fail inside $(...) exits only the subshell.
find_apple_container() {
  container system status >/dev/null 2>&1 || return 2
  container ls --format json \
    | jq -r --arg root "$PROJECT_ROOT" \
      '.[] | select(.configuration.labels["bs.project_root"] == $root) | .configuration.id' \
    | head -n 1
}

# Prints the ID of the running docker devcontainer for the project, if any.
find_docker_container() {
  have docker || return 0
  local ids count
  # A stopped docker daemon means that no docker devcontainer runs.
  ids="$(docker ps -q --filter "label=devcontainer.local_folder=${PROJECT_ROOT}" 2>/dev/null)" || return 0
  [ -n "$ids" ] || return 0
  count="$(echo "$ids" | wc -l | tr -d ' ')"
  if [ "$count" -gt 1 ]; then
    echo "Warning: ${count} devcontainers found for ${PROJECT_ROOT}, using $(echo "$ids" | head -n 1)" >&2
  fi
  echo "$ids" | head -n 1
}

docker_runtime() {
  if have devcontainer; then echo devcontainer; else echo docker; fi
}

fail_docker_not_found() {
  if have devcontainer; then
    fail_not_found "Start the container first with '${DEVCONTAINER_UP_COMMAND}'."
  fi
  fail_not_found "Start the container manually with VS Code → 'Reopen in Container'."
}

fail_apple_service_stopped() {
  fail "The container system service is not running." \
    "Start it with 'container system start', then start the container with '${APPLE_UP_COMMAND}'."
}

use_apple() {
  local id status=0
  require_jq
  id="$(find_apple_container)" || status=$?
  [ "$status" -ne 2 ] || fail_apple_service_stopped
  [ -n "$id" ] || fail_not_found "Start the container first with '${APPLE_UP_COMMAND}'."
  echo "apple $id"
}

use_docker() {
  local id
  id="$(find_docker_container)"
  [ -n "$id" ] || fail_docker_not_found
  echo "$(docker_runtime) $id"
}

RUNTIME="$(read_configured_runtime)"

case "$RUNTIME" in
  apple)
    have container || fail \
      "BS_CONTAINER_RUNTIME=apple is set in ${CONFIG_FILE}, but the container CLI is not installed." \
      "Install it from https://github.com/apple/container, or change BS_CONTAINER_RUNTIME."
    use_apple
    ;;
  devcontainer)
    have devcontainer || have docker || fail \
      "BS_CONTAINER_RUNTIME=devcontainer is set in ${CONFIG_FILE}, but neither the devcontainer CLI nor docker is installed." \
      "Install the devcontainer CLI (npm install -g @devcontainers/cli), or change BS_CONTAINER_RUNTIME."
    use_docker
    ;;
  "")
    if have container; then
      APPLE_ID="" APPLE_STATUS=0
      require_jq
      APPLE_ID="$(find_apple_container)" || APPLE_STATUS=$?
      if [ -n "$APPLE_ID" ]; then
        echo "apple $APPLE_ID"
        exit 0
      fi
      # A docker devcontainer started from VS Code still works here.
      DOCKER_ID="$(find_docker_container)"
      if [ -n "$DOCKER_ID" ]; then
        echo "$(docker_runtime) $DOCKER_ID"
        exit 0
      fi
      [ "$APPLE_STATUS" -ne 2 ] || fail_apple_service_stopped
      fail_not_found "Start the container first with '${APPLE_UP_COMMAND}'."
    elif have devcontainer || have docker; then
      use_docker
    else
      fail "No CLI to run the container found on the system" \
        "" \
        "Choose a way to run the container:" \
        "- manually with VS Code → 'Reopen in Container'" \
        "- preferable for macOS: install the container CLI (https://github.com/apple/container), and then '${APPLE_UP_COMMAND}'" \
        "- in other cases, install the devcontainer CLI (npm install -g @devcontainers/cli), and then '${DEVCONTAINER_UP_COMMAND}'"
    fi
    ;;
  *)
    fail "Unsupported BS_CONTAINER_RUNTIME value '${RUNTIME}' in ${CONFIG_FILE}." \
      "Use 'apple' or 'devcontainer', or remove the variable."
    ;;
esac
