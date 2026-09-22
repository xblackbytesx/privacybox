#!/usr/bin/env bash

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Always operate from the repo root so the config and apps/ paths resolve
# regardless of the caller's working directory.
PRIVACYBOX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$PRIVACYBOX_DIR" || exit 1

# Read config file
config_file="privacybox.config"
if [[ ! -f "$config_file" ]]; then
  echo "Config file not found: $PRIVACYBOX_DIR/$config_file" >&2
  echo "Copy privacybox.config.example to privacybox.config and adjust it." >&2
  exit 1
fi

# Strip leading/trailing whitespace: an invisible trailing space must never
# silently change a path's meaning (same rule as scripts/backup.sh).
trim() {
  local s=$1
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

declare -A groups=()

# Every config key is exported, so it wins over the same variable in an app's
# .env for everything run through manage.sh (scripts/backup.sh does the same).
# That matters for DOCKER_ROOT: see check_docker_root.
while read -r line; do
  key="${line%%=*}"
  val=$(trim "${line#*=}")
  groups["$key"]="$val"
  export "$key"="$val"
done < <(grep -E '^[A-Z_]+=' "$config_file")

# Usage message
usage() {
  echo "Usage: ./manage.sh --(start|stop|restart|update|force-recreate) --(app|group|all) <name>"
  echo "       ./manage.sh --backup [--rolling | --app <name>] [--force] [--yes]"
  echo "       ./manage.sh --create-dsm-tun"
  echo "       ./manage.sh --free-dsm-ports"
  echo "Example: ./manage.sh --start --app wordpress"
  echo "Example: ./manage.sh --force-recreate --app immich"
  echo "Example: ./manage.sh --restart --group PUBLISHING"
  echo "Example: ./manage.sh --update --all"
  echo "Example: ./manage.sh --backup                     (full backup, everything must be stopped)"
  echo "Example: ./manage.sh --backup --rolling           (per-app: stop, archive, verify, restart)"
  echo "Example: ./manage.sh --backup --app nextcloud     (rolling treatment for one app)"
  echo "Example: ./manage.sh --create-dsm-tun"
  echo "Example: ./manage.sh --free-dsm-ports"
  exit 1
}

# Check if there are enough arguments
if [[ $# -lt 1 ]] || [[ $# -gt 5 ]]; then
  usage
fi

# Parse flags. Anything unrecognised is an error rather than being taken as
# the app name, so a typo can never silently change what runs.
action=""
entity_type=""
entity_name=""
backup_flags=()

set_action() {
  if [[ -n "$action" && "$action" != "$1" ]]; then
    echo "Only one action at a time (got --$action and --$1)." >&2
    usage
  fi
  action="$1"
}

set_entity_type() {
  if [[ -n "$entity_type" && "$entity_type" != "$1" ]]; then
    echo "Use only one of --app, --group and --all." >&2
    usage
  fi
  entity_type="$1"
}

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --start|--stop|--restart|--update|--force-recreate) set_action "${1#--}" ;;
    --backup|--create-dsm-tun|--free-dsm-ports) set_action "${1#--}" ;;
    --app|--group|--all) set_entity_type "${1#--}" ;;
    --rolling|--force|--yes) backup_flags+=("$1") ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      if [[ -n "$entity_name" ]]; then
        echo "Unexpected extra argument: $1" >&2
        usage
      fi
      entity_name="$1"
      ;;
  esac
  shift
done

# Validate input
case $action in
  "") usage ;;
  backup) ;;  # run_backup validates its own combinations
  create-dsm-tun|free-dsm-ports)
    if [[ -n "$entity_type" || -n "$entity_name" || ${#backup_flags[@]} -gt 0 ]]; then
      usage
    fi
    ;;
  *)
    if [[ ${#backup_flags[@]} -gt 0 ]]; then
      echo "${backup_flags[*]}: only valid with --backup." >&2
      usage
    fi
    case $entity_type in
      app|group) [[ -n "$entity_name" ]] || usage ;;
      all) [[ -z "$entity_name" ]] || usage ;;
      *) usage ;;
    esac
    ;;
esac

# Test if 'docker compose' command is available
if docker compose version >/dev/null 2>&1; then
    export COMPOSE_BIN='docker compose'
else
    export COMPOSE_BIN='docker-compose'
fi

echo "COMPOSE_BIN is set to $COMPOSE_BIN"

has_compose() {
  local f
  for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    if [[ -f "$1/$f" ]]; then return 0; fi
  done
  return 1
}

# An entry names a compose project under apps/ ("baikal",
# "ghost/deployments/eli5") or a parent directory holding several: variant
# layouts (gluetun -> gluetun/openvpn, gluetun/wireguard) and deployment
# layouts (ghost -> ghost/deployments/*). Same resolution as
# scripts/backup.sh. Fills PROJECTS; returns 1 when there is nothing there.
resolve_projects() {
  local entry=$1 f
  PROJECTS=()
  if [[ -z "$entry" || "$entry" == /* || "$entry" == *..* ]]; then
    return 1
  fi
  if has_compose "apps/$entry"; then
    PROJECTS=("$entry")
    return 0
  fi
  [[ -d "apps/$entry" ]] || return 1
  while IFS= read -r f; do
    PROJECTS+=("$(dirname "${f#apps/}")")
  done < <(find "apps/$entry" -mindepth 2 -maxdepth 4 \
             \( -name docker-compose.yml -o -name docker-compose.yaml \
                -o -name compose.yml -o -name compose.yaml \) | sort)
  [[ ${#PROJECTS[@]} -gt 0 ]]
}

deployments_layout() {
  # True when every resolved project sits under <entry>/deployments/: those
  # run side by side, unlike variants, which are alternatives.
  local p
  for p in "${PROJECTS[@]}"; do
    [[ "$p" == "${1%/}/deployments/"* ]] || return 1
  done
  return 0
}

run_compose() {
  local project=$1
  shift
  # shellcheck disable=SC2086  # COMPOSE_BIN may be two words ("docker compose")
  ( cd "apps/$project" && $COMPOSE_BIN "$@" )
}

project_running() {
  local out
  out=$(run_compose "$1" ps -q 2>/dev/null) || return 1
  [[ -n "$out" ]]
}

# The exported config DOCKER_ROOT wins over the app's .env. If the two differ,
# a plain `docker compose up` in the app folder would mount another data tree
# than manage.sh and the backups use, so say so.
check_docker_root() {
  local env_file="apps/$1/.env" val
  [[ -n "${DOCKER_ROOT:-}" && -f "$env_file" ]] || return 0
  val=$(grep -m1 -E '^[[:space:]]*DOCKER_ROOT=' "$env_file" | cut -d= -f2-) || return 0
  val=$(trim "$val")
  val=${val#\"}; val=${val%\"}; val=${val#\'}; val=${val%\'}
  [[ -n "$val" && "${val%/}" != "${DOCKER_ROOT%/}" ]] || return 0
  echo "WARNING [$1]: its .env sets DOCKER_ROOT=$val, but privacybox.config says $DOCKER_ROOT." >&2
  echo "  manage.sh and backups use $DOCKER_ROOT; a plain 'docker compose' in apps/$1 would use $val." >&2
}

# Perform the action on a single compose project
compose_action() {
  local project=$1 action=$2 rc=0
  check_docker_root "$project"
  echo "${action^}-ing $project..."
  case $action in
    start) run_compose "$project" up -d || rc=$? ;;
    # No -v on down: all current volumes are bind-driver so -v would only
    # drop definitions, but the first app that ever uses a real named
    # volume would have its data deleted by it.
    stop) run_compose "$project" down || rc=$? ;;
    restart) run_compose "$project" restart || rc=$? ;;
    force-recreate) run_compose "$project" up -d --force-recreate || rc=$? ;;
    update)
      run_compose "$project" pull || rc=$?
      run_compose "$project" up -d --build || rc=$?
      ;;
  esac
  return $rc
}

# Perform the action on an entry: one project, or every project under a
# parent directory (deployments), or its running variants.
execute_action() {
  local entry=$1 action=$2 p rc=0 targets=()
  if ! resolve_projects "$entry"; then
    echo "App not found: $entry" >&2
    return 1
  fi
  if [[ ${#PROJECTS[@]} -eq 1 ]]; then
    compose_action "${PROJECTS[0]}" "$action"
    return
  fi
  if deployments_layout "$entry"; then
    targets=("${PROJECTS[@]}")
  else
    # Variants are alternatives (gluetun/openvpn or gluetun/wireguard), so
    # only the running ones are acted on.
    for p in "${PROJECTS[@]}"; do
      if project_running "$p"; then targets+=("$p"); fi
    done
    if [[ ${#targets[@]} -eq 0 ]]; then
      case $action in
        stop|restart)
          echo "$entry: none of ${PROJECTS[*]} is running, nothing to $action."
          return 0
          ;;
        *)
          echo "$entry has several variants (${PROJECTS[*]}) and none is running." >&2
          echo "  Name the one to $action, e.g. --app ${PROJECTS[0]}, and list that one in DEPLOYED_APPS." >&2
          return 1
          ;;
      esac
    fi
  fi
  for p in "${targets[@]}"; do
    compose_action "$p" "$action" || rc=1
  done
  return $rc
}

# Function to run the scripts/backup.sh script (all backup logic lives there)
run_backup() {
  if [[ "$entity_type" == "app" ]]; then
    if [[ -z "$entity_name" ]]; then
      usage
    fi
    backup_flags+=(--app "$entity_name")
  elif [[ -n "$entity_type" || -n "$entity_name" ]]; then
    # --group/--all make no sense for backups (--rolling covers "all"), and a
    # bare name without --app is a mistake, not a full backup.
    usage
  fi
  exec bash "scripts/backup.sh" "${backup_flags[@]}"
}

# Function to run create-dsm-tun.sh script
create_dsm_tun() {
  create_dsm_tun="scripts/create-dsm-tun.sh"

  if [[ -f "$create_dsm_tun" ]]; then
    echo "Ensuring tun device is present..."
    chmod +x "$create_dsm_tun"
    ./"$create_dsm_tun"
  else
    echo "DSM script not found: $create_dsm_tun" >&2
    return 1
  fi
}

# Function to run free-dsm-ports.sh script
free_dsm_ports() {
  free_dsm_script="scripts/free-dsm-ports.sh"

  if [[ -f "$free_dsm_script" ]]; then
    echo "Freeing up port 80 and 443..."
    chmod +x "$free_dsm_script"
    ./"$free_dsm_script"
  else
    echo "DSM script not found: $free_dsm_script" >&2
    return 1
  fi
}

# Perform the action. Failures are collected rather than stopping the run, and
# turn into a non-zero exit at the end so cron and scripts can see them.
failures=()

run_on() {
  execute_action "$1" "$action" || failures+=("$1")
}

if [[ "$action" == "backup" ]]; then
  run_backup
elif [[ "$action" == "create-dsm-tun" ]]; then
  create_dsm_tun || failures+=("create-dsm-tun")
elif [[ "$action" == "free-dsm-ports" ]]; then
  free_dsm_ports || failures+=("free-dsm-ports")
elif [[ "$entity_type" == "all" ]]; then
  IFS=', ' read -ra app_list <<<"${groups["DEPLOYED_APPS"]}"
  for app in "${app_list[@]}"; do
    run_on "$app"
  done
else
  case $entity_type in
    app) run_on "$entity_name" ;;
    group)
      if [[ -n "${groups[$entity_name]}" ]]; then
        IFS=', ' read -ra app_list <<<"${groups[$entity_name]}"
        for app in "${app_list[@]}"; do
          run_on "$app"
        done
      else
        echo "Group not found: $entity_name" >&2
        failures+=("group $entity_name")
      fi
      ;;
    *) usage ;;
  esac
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "" >&2
  echo "FAILED: ${failures[*]}" >&2
  exit 1
fi
