#!/usr/bin/env bash
# Build the Turnstone image from upstream source on this host.
#
# Needed where the ghcr.io image has no matching architecture: upstream ships
# linux/amd64 only. Pairs with docker-compose.override.yml, which points the
# build at the clone this script maintains.
#
#   ./update-source.sh            fetch the pinned ref, rebuild only if it moved
#   ./update-source.sh --rebuild  rebuild from scratch even when it did not,
#                                 which is how base-image security updates land
#
# Safe to run unattended. It restarts the console and server whenever it
# rebuilds, ending any workstream in flight, so schedule it off-hours.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

REPO_URL="https://github.com/turnstonelabs/turnstone.git"
IMAGE="turnstone:local"
env_file=".env"

force=0
if [[ ${1:-} == "--rebuild" ]]; then
  force=1
elif [[ -n ${1:-} ]]; then
  echo "Usage: ./update-source.sh [--rebuild]" >&2
  exit 1
fi

if [[ ! -f $env_file ]]; then
  echo "No .env in $(pwd). Copy .env.example first." >&2
  exit 1
fi

# Read the keys directly rather than sourcing the file, which would run whatever
# happens to be in it.
read_env() {
  local val
  val=$(grep -E "^$1=" "$env_file" | tail -n1 | cut -d= -f2-) || true
  val=${val%\"}; val=${val#\"}
  val=${val%\'}; val=${val#\'}
  printf '%s' "$val"
}

# Fail on the things that otherwise surface as an unhealthy database or a
# container that exits on boot, and do it before spending time on a build.
preflight() {
  local docker_root workspace_dir jwt db_pass
  local missing=()
  docker_root=$(read_env DOCKER_ROOT)
  workspace_dir=$(read_env TURNSTONE_WORKSPACE_DIR)
  jwt=$(read_env TURNSTONE_JWT_SECRET)
  db_pass=$(read_env DB_USER_PASS)

  [[ -n $docker_root ]] || { echo "DOCKER_ROOT is unset in $env_file" >&2; exit 1; }
  [[ -d $docker_root/turnstone/database ]] || missing+=("$docker_root/turnstone/database")
  [[ -d $docker_root/turnstone/data ]] || missing+=("$docker_root/turnstone/data")
  if [[ -z $workspace_dir ]]; then
    echo "TURNSTONE_WORKSPACE_DIR is unset in $env_file" >&2
    exit 1
  fi
  [[ -d $workspace_dir ]] || missing+=("$workspace_dir")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Bind mount directories are missing, so the stack cannot start:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    echo >&2
    echo "  mkdir -p $docker_root/turnstone/database $docker_root/turnstone/data $workspace_dir" >&2
    echo "  chown -R 1000:1000 $docker_root/turnstone/data $workspace_dir" >&2
    exit 1
  fi

  if [[ ${#jwt} -lt 32 ]]; then
    echo "TURNSTONE_JWT_SECRET is ${#jwt} characters. Every service exits below 32." >&2
    echo "  openssl rand -hex 32" >&2
    exit 1
  fi

  if [[ -z $db_pass ]]; then
    echo "DB_USER_PASS is empty. Postgres will not initialise without one." >&2
    exit 1
  fi
}

src_dir=$(read_env TURNSTONE_SRC_DIR)
src_ref=$(read_env TURNSTONE_SRC_REF)

if [[ -z $src_dir || -z $src_ref ]]; then
  echo "Set TURNSTONE_SRC_DIR and TURNSTONE_SRC_REF in $(pwd)/$env_file" >&2
  exit 1
fi

preflight

if docker compose version >/dev/null 2>&1; then
  COMPOSE_BIN=(docker compose)
else
  COMPOSE_BIN=(docker-compose)
fi

if [[ ! -d $src_dir/.git ]]; then
  echo "Cloning $REPO_URL into $src_dir"
  mkdir -p "$src_dir"
  git clone --filter=blob:none "$REPO_URL" "$src_dir"
fi

before=$(git -C "$src_dir" rev-parse HEAD 2>/dev/null || echo none)

git -C "$src_dir" fetch --tags --prune --quiet origin
# Try a tag, then a branch. Detached either way: this is a build tree, never
# somewhere to commit.
git -C "$src_dir" checkout --quiet --detach "refs/tags/$src_ref" 2>/dev/null \
  || git -C "$src_dir" checkout --quiet --detach "origin/$src_ref"

after=$(git -C "$src_dir" rev-parse HEAD)
echo "$src_ref is at $after"

if [[ $force -eq 0 && $before == "$after" && -n $(docker images -q "$IMAGE") ]]; then
  echo "Unchanged, and $IMAGE exists. Nothing to do."
  exit 0
fi

if [[ $force -eq 1 ]]; then
  "${COMPOSE_BIN[@]}" build --pull --no-cache
else
  "${COMPOSE_BIN[@]}" build
fi

"${COMPOSE_BIN[@]}" up -d
echo "Turnstone rebuilt from $after"
