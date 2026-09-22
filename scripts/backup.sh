#!/usr/bin/env bash
#
# privacybox backup — trustworthy tar backups of the repo + container data.
#
# Modes:
#   (default)      Full backup: repo dir + DOCKER_ROOT in a single archive.
#                  Refuses to run while ANY container is running (--force overrides).
#   --rolling      Per-app backup: stop -> archive -> verify -> restart, one app
#                  at a time, so only one service is down at any moment.
#                  Covers every directory in DOCKER_ROOT: DEPLOYED_APPS first,
#                  then the rest. Switched-off apps are backed up cold and stay
#                  stopped; a directory with no compose project is archived
#                  data-only; a tree excluded whole by EXCLUDE_PATH is skipped
#                  without stopping anything.
#                  Deployments sharing a top-level dir (apps/<app>/deployments/*)
#                  are stopped together and DOCKER_ROOT/<app> is archived once.
#   --app <name>   The rolling treatment for a single app. Accepts a top-level
#                  name ("ghost") or one deployment ("ghost/deployments/eli5");
#                  the whole top-level group is treated either way.
#
# Flags:
#   --yes          Skip the confirmation prompt (for cron; run as root so tar
#                  needs no sudo password).
#   --force        Proceed despite running containers (full mode) or a failed
#                  free-space preflight. The archive may not be trustworthy —
#                  the point of this script is that you never need this flag.
#
# Trust guarantees (all modes):
#   - Archives are written to <name>.partial and only renamed into place after
#     passing gzip -t + a full tar structural read. A crash, Ctrl-C or disk-full
#     never leaves a plausible-looking archive behind.
#   - tar exit code 1 ("file changed as we read it") is treated as a hard
#     failure: something was writing to the source, the archive cannot be
#     trusted, and it is discarded.
#   - Existing archives are never overwritten.
#   - A .sha256 sidecar is written next to every verified archive.
#   - A failed app does not end a rolling run: it is restarted, reported
#     FAILED, the remaining apps are still backed up, and the run exits
#     non-zero.
#   - With BACKUP_KEEP=N in privacybox.config, old backups are pruned, but
#     only after the new one has been created AND verified. Full archives,
#     rolling runs and each app's --app runs are counted separately, and only
#     runs that finished without a failure count towards N.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PRIVACYBOX_DIR=$(dirname "$SCRIPT_DIR")

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

usage() {
  # Print the header comment block above as the help text.
  awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

# ---------------------------------------------------------------- config ----

CONFIG_FILE="${PRIVACYBOX_CONFIG:-$PRIVACYBOX_DIR/privacybox.config}"
if [[ ! -f $CONFIG_FILE ]]; then
  die "Config file not found: $CONFIG_FILE (copy privacybox.config.example and adjust)"
fi

# Strip leading/trailing whitespace: an invisible trailing space must never
# silently change a path's meaning.
trim() {
  local s=$1
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

DOCKER_ROOT="" BACKUP_ROOT="" EXCLUDE_PATHS="" DEPLOYED_APPS="" BACKUP_KEEP=""
EXCLUDE_LIST=()
while IFS= read -r line; do
  key="${line%%=*}"
  val=$(trim "${line#*=}")
  case "$key" in
    DOCKER_ROOT)   DOCKER_ROOT=$val ;;
    BACKUP_ROOT)   BACKUP_ROOT=$val ;;
    # Preferred: one path per EXCLUDE_PATH line, repeated as often as needed.
    # The legacy space-separated EXCLUDE_PATHS is still honoured; additive.
    EXCLUDE_PATH)  EXCLUDE_LIST+=("$val") ;;
    EXCLUDE_PATHS) EXCLUDE_PATHS=$val ;;
    DEPLOYED_APPS) DEPLOYED_APPS=$val ;;
    BACKUP_KEEP)   BACKUP_KEEP=$val ;;
  esac
  # Exported exactly like manage.sh does, so the apps this script stops and
  # restarts get the same environment on a direct run: config values, above
  # all DOCKER_ROOT, win over the same variable in an app's .env.
  export "$key=$val"
done < <(grep -E '^[A-Z_]+=' "$CONFIG_FILE" || true)

[[ -n $DOCKER_ROOT ]] || die "DOCKER_ROOT is not set in $CONFIG_FILE"
[[ -d $DOCKER_ROOT ]] || die "DOCKER_ROOT is not a directory: $DOCKER_ROOT"
[[ -n $BACKUP_ROOT ]] || die "BACKUP_ROOT is not set in $CONFIG_FILE"

# ------------------------------------------------------------- arguments ----

MODE="full" APP_NAME="" FORCE=0 ASSUME_YES=0 ROLLING=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rolling) ROLLING=1 ;;
    --app)
      [[ $# -ge 2 ]] || die "--app requires an app name"
      MODE="single"
      APP_NAME=$2
      shift
      ;;
    --force) FORCE=1 ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
  shift
done
if [[ $ROLLING -eq 1 ]]; then
  [[ $MODE != "single" ]] || die "--rolling and --app are mutually exclusive"
  MODE="rolling"
fi

# ----------------------------------------------------------- environment ----

# Inherit COMPOSE_BIN when the caller (manage.sh) already detected it.
if [[ -z ${COMPOSE_BIN:-} ]]; then
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN='docker compose'
  else
    COMPOSE_BIN='docker-compose'
  fi
fi

# Reading DOCKER_ROOT needs root (data is owned by many container uids).
# When already root — e.g. a root cron job — sudo is skipped entirely.
if [[ ${PRIVACYBOX_NO_SUDO:-0} == 1 || $EUID -eq 0 ]]; then
  as_root() { "$@"; }
else
  as_root() { sudo "$@"; }
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOST=$(cat /proc/sys/kernel/hostname)
# Per-host parent folder: BACKUP_ROOT/<host>/… so one server's backups form a
# single subtree that syncthing can selectively sync or ignore. Retention and
# the space preflight are scoped to this folder only.
HOST_DIR="$BACKUP_ROOT/$HOST"

# EXCLUDE_PATH(S) entries are relative to DOCKER_ROOT. BACKUP_ROOT is always
# excluded so a backup can never recursively archive its own output. Empty
# entries are skipped — an empty path would exclude ALL of DOCKER_ROOT.
EXCLUDE_ARGS=("--exclude=$BACKUP_ROOT")
read -r -a _exclude_rel <<< "$EXCLUDE_PATHS"
for _p in ${_exclude_rel[@]+"${_exclude_rel[@]}"} ${EXCLUDE_LIST[@]+"${EXCLUDE_LIST[@]}"}; do
  [[ -n $_p ]] || continue
  EXCLUDE_ARGS+=("--exclude=$DOCKER_ROOT/$_p")
done

mkdir -p "$BACKUP_ROOT"

# ----------------------------------------------------- cleanup guarantees ----

CURRENT_PARTIAL=""        # partial archive to delete if we die mid-write
RESTART_PENDING_APPS=()   # compose projects we stopped and have not yet restarted
RESULTS=()
FAILED_ITEMS=()           # data trees not backed up, apps not restarted

cleanup() {
  local rc=$? a
  set +e
  if [[ -n $CURRENT_PARTIAL && -e $CURRENT_PARTIAL ]]; then
    err "Removing incomplete archive: $CURRENT_PARTIAL"
    as_root rm -f -- "$CURRENT_PARTIAL"
  fi
  if [[ ${#RESTART_PENDING_APPS[@]} -gt 0 ]]; then
    err "Run aborted while apps were stopped — restarting: ${RESTART_PENDING_APPS[*]}"
    for a in "${RESTART_PENDING_APPS[@]}"; do
      if start_app "$a"; then
        err "$a restarted."
      else
        err "COULD NOT RESTART $a — start it manually: ./manage.sh --start --app $a"
      fi
    done
  fi
  if [[ ${#RESULTS[@]} -gt 0 ]]; then
    log ""
    log "Backup summary:"
    printf '  %s\n' "${RESULTS[@]}"
  fi
  if [[ $rc -ne 0 ]]; then
    err "Backup FAILED (exit $rc). Only archives listed as OK above are trustworthy."
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# -------------------------------------------------------- compose helpers ----

compose_app() {
  local app=$1
  shift
  # shellcheck disable=SC2086  # COMPOSE_BIN may be two words ("docker compose")
  ( cd "$PRIVACYBOX_DIR/apps/$app" && $COMPOSE_BIN "$@" )
}

app_running() {
  local out
  if ! out=$(compose_app "$1" ps -q); then
    # A variant that was never deployed may not even be queryable (missing
    # .env). Treat it as not running — if that assumption were ever wrong,
    # the moving-target detection fails the archive rather than trust it.
    err "[$1] could not query container status — treating as not running."
    return 1
  fi
  [[ -n $out ]]
}

start_app() { compose_app "$1" up -d; }

check_docker_root() {
  # The exported config DOCKER_ROOT wins over the app's .env. If the two
  # differ, a plain `docker compose up` in the app folder mounts another data
  # tree than the one archived here, so say so.
  local env_file="$PRIVACYBOX_DIR/apps/$1/.env" val
  [[ -f $env_file ]] || return 0
  val=$(grep -m1 -E '^[[:space:]]*DOCKER_ROOT=' "$env_file" | cut -d= -f2-) || return 0
  val=$(trim "$val")
  val=${val#\"}; val=${val%\"}; val=${val#\'}; val=${val%\'}
  [[ -n $val && ${val%/} != "${DOCKER_ROOT%/}" ]] || return 0
  err "[$1] its .env sets DOCKER_ROOT=$val, but privacybox.config says $DOCKER_ROOT."
  err "[$1] Backups archive $DOCKER_ROOT/$(top_of "$1"); a plain 'docker compose' in apps/$1 would use $val."
}
stop_app()  { compose_app "$1" down; }

# ------------------------------------------------------------- trust core ----

# All failure paths in the functions below are explicit (no reliance on
# errexit) so they behave identically in any calling context.

verify_archive() {
  local f=$1 size
  size=$(as_root du -sk -- "$f" | awk '{print $1}') || size=""
  if [[ -z $size || $size -eq 0 ]]; then
    err "Archive is empty: $f"
    return 1
  fi
  if ! as_root gzip -t "$f"; then
    err "gzip integrity check FAILED: $f"
    return 1
  fi
  if ! as_root tar -tzf "$f" >/dev/null; then
    err "tar structural check FAILED: $f"
    return 1
  fi
  return 0
}

write_checksum() {
  local f=$1
  ( cd "$(dirname "$f")" \
      && as_root sha256sum "$(basename "$f")" > "$(basename "$f").sha256" )
}

discard_partial() {
  if [[ -n $CURRENT_PARTIAL && -e $CURRENT_PARTIAL ]]; then
    as_root rm -f -- "$CURRENT_PARTIAL"
  fi
  CURRENT_PARTIAL=""
}

create_archive() {
  # create_archive <final-path> <source-path>...
  local final=$1
  shift
  if [[ -e $final ]]; then
    err "Refusing to overwrite existing archive: $final"
    return 1
  fi
  local partial="$final.partial" rc=0
  CURRENT_PARTIAL=$partial
  as_root tar "${EXCLUDE_ARGS[@]}" -zcf "$partial" "$@" || rc=$?
  if [[ $rc -eq 1 ]]; then
    err "tar exit 1: files changed while being read — something was still writing."
    err "This archive can NOT be trusted; discarding it."
    discard_partial
    return 1
  elif [[ $rc -ne 0 ]]; then
    err "tar failed (exit $rc)."
    discard_partial
    return 1
  fi
  if ! verify_archive "$partial"; then
    discard_partial
    return 1
  fi
  if ! as_root mv -- "$partial" "$final"; then
    err "Could not move verified archive into place: $final"
    discard_partial
    return 1
  fi
  CURRENT_PARTIAL=""
  if ! write_checksum "$final"; then
    err "Could not write checksum sidecar for $final"
    return 1
  fi
  log "Verified backup written: $final ($(as_root du -h -- "$final" | cut -f1))"
  return 0
}

# --------------------------------------------------------------- preflight ----

mib() { echo "$(( $1 / 1024 / 1024 )) MiB"; }

newest_backup_size() {
  # newest_backup_size <glob>... -> size in bytes of the newest match, 0 if none
  local newest
  newest=$(ls -1dt "$@" 2>/dev/null | head -n1 || true)
  if [[ -z $newest ]]; then
    echo 0
    return 0
  fi
  # Byte math in bash, not awk: mawk prints values past 2^31 in scientific
  # notation (1.15e+10), which [[ -gt ]] rejects, silently skipping the check.
  local kib
  kib=$(as_root du -sk -- "$newest" 2>/dev/null | cut -f1) || kib=0
  [[ $kib =~ ^[0-9]+$ ]] || kib=0
  echo $(( kib * 1024 ))
}

preflight_space() {
  # preflight_space <estimated-bytes> — 0 means "no prior backup, skip check"
  local need=$1 avail
  [[ $need -gt 0 ]] || return 0
  need=$(( need + need / 10 ))
  avail=$(df -Pk "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
  avail=$(( avail * 1024 ))
  if [[ $avail -lt $need ]]; then
    if [[ $FORCE -eq 1 ]]; then
      err "Low space on $BACKUP_ROOT: $(mib "$avail") free, ~$(mib "$need") expected — continuing due to --force."
    else
      die "Not enough space on $BACKUP_ROOT: $(mib "$avail") free, ~$(mib "$need") expected (last comparable backup + 10%). Free up space or use --force."
    fi
  fi
}

confirm() {
  if [[ $ASSUME_YES -eq 1 ]]; then
    return 0
  fi
  read -p "Proceed with the backup? (y/n): " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || die "Backup cancelled."
}

print_excludes() {
  local e
  for e in "${EXCLUDE_ARGS[@]}"; do
    log "    - ${e#--exclude=}"
  done
}

# -------------------------------------------------------------- retention ----

# Run folders: rolling runs are named <timestamp>, --app runs
# <timestamp>-app-<top>, so the two kinds never compete for BACKUP_KEEP slots.
# A run that finished without a failure gets RUN_OK_MARKER; only those count.
TS_GLOB='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]'
RUN_OK_MARKER=".complete"

prune_runs() {
  # prune_runs <run-dir>... (newest first). Keep everything down to the
  # BACKUP_KEEP-th complete run and delete what is older. Failed or cut-short
  # runs never count, so they can not push a good backup out, and nothing is
  # pruned until BACKUP_KEEP complete runs exist (history from before the
  # marker existed is only removed once it is older than those).
  local complete=0 dir
  for dir in "$@"; do
    dir=${dir%/}
    if [[ $complete -ge $BACKUP_KEEP ]]; then
      log "Retention (BACKUP_KEEP=$BACKUP_KEEP): removing old backup $dir"
      as_root rm -rf -- "$dir"
      continue
    fi
    if [[ -e $dir/$RUN_OK_MARKER ]]; then complete=$(( complete + 1 )); fi
  done
}

apply_retention() {
  [[ -n $BACKUP_KEEP ]] || return 0
  if ! [[ $BACKUP_KEEP =~ ^[1-9][0-9]*$ ]]; then
    err "BACKUP_KEEP must be a whole number of at least 1 (got '$BACKUP_KEEP'): skipping pruning."
    return 0
  fi
  local items=() item
  case $MODE in
    full)
      while IFS= read -r item; do items+=("$item"); done \
        < <(ls -1dt "$HOST_DIR"/*-full.tar.gz 2>/dev/null || true)
      [[ ${#items[@]} -gt $BACKUP_KEEP ]] || return 0
      for item in "${items[@]:$BACKUP_KEEP}"; do
        log "Retention (BACKUP_KEEP=$BACKUP_KEEP): removing old backup $item"
        as_root rm -rf -- "$item" "$item.sha256"
      done
      ;;
    rolling)
      while IFS= read -r item; do items+=("$item"); done \
        < <(ls -1dt "$HOST_DIR"/$TS_GLOB/ 2>/dev/null || true)
      prune_runs ${items[@]+"${items[@]}"}
      ;;
    single)
      while IFS= read -r item; do items+=("$item"); done \
        < <(ls -1dt "$HOST_DIR"/$TS_GLOB-app-"$(top_of "$APP_NAME")"/ 2>/dev/null || true)
      prune_runs ${items[@]+"${items[@]}"}
      ;;
  esac
}

rolling_estimate() {
  # Space estimate for a rolling run: the newest complete rolling run, or,
  # before one exists, the newest rolling run folder of any kind.
  local dir
  while IFS= read -r dir; do
    if [[ -e ${dir%/}/$RUN_OK_MARKER ]]; then
      newest_backup_size "$dir"
      return 0
    fi
  done < <(ls -1dt "$HOST_DIR"/$TS_GLOB/ 2>/dev/null || true)
  newest_backup_size "$HOST_DIR"/$TS_GLOB/
}

finish_run() {
  # finish_run <outdir>: mark a clean run complete, prune, and fail the run
  # (non-zero exit, summary via the exit trap) if anything was not backed up.
  if [[ ${#FAILED_ITEMS[@]} -eq 0 ]]; then
    touch "$1/$RUN_OK_MARKER"
  fi
  apply_retention
  if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
    err "Not backed up or not restarted: ${FAILED_ITEMS[*]}"
    exit 1
  fi
}

# ------------------------------------------------------------------ modes ----

do_full() {
  local running=""
  running=$(docker ps --format '{{.Names}}' 2>/dev/null) || {
    log "Note: could not query docker for running containers — assuming none."
    running=""
  }
  if [[ -n $running ]]; then
    if [[ $FORCE -eq 1 ]]; then
      err "Containers are RUNNING — proceeding due to --force. This archive may not be consistent!"
    else
      err "Refusing a full backup while containers are running:"
      while IFS= read -r name; do err "  - $name"; done <<< "$running"
      err "Stop everything first (./manage.sh --stop --all), use --rolling, or --force (NOT recommended)."
      exit 2
    fi
  fi

  local final="$HOST_DIR/$TIMESTAMP-full.tar.gz"
  log "Backup task summary (full):"
  log "  Sources:"
  log "    - $PRIVACYBOX_DIR"
  log "    - $DOCKER_ROOT"
  log "  Excludes:"
  print_excludes
  log "  Target: $final"
  confirm
  preflight_space "$(newest_backup_size "$HOST_DIR"/*-full.tar.gz)"

  mkdir -p "$HOST_DIR"
  create_archive "$final" "$PRIVACYBOX_DIR" "$DOCKER_ROOT"
  RESULTS+=("full: OK -> $final")
  apply_retention
}

# A DEPLOYED_APPS entry names something under apps/: a compose project
# directly ("baikal", "ghost/deployments/eli5") or a parent directory whose
# subdirectories hold the actual compose projects — variant layouts like
# apps/gluetun/{openvpn,wireguard} or deployment layouts like
# apps/ghost/deployments/<name>. Entries are resolved to concrete compose
# projects below; the unit of DATA is always the top-level directory
# DOCKER_ROOT/<top> (first path segment), archived whole, minus excludes.
# All projects sharing a top are stopped together — archiving
# DOCKER_ROOT/ghost while another ghost deployment still runs would capture
# a moving target.
top_of() { printf '%s' "${1%%/*}"; }

has_compose() {
  local f
  for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    if [[ -f "$1/$f" ]]; then return 0; fi
  done
  return 1
}

PROJECTS=()  # resolved compose-project paths, relative to apps/

add_project() {
  local p
  for p in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
    if [[ $p == "$1" ]]; then return 0; fi
  done
  PROJECTS+=("$1")
}

collect_projects() {
  # Append the compose project(s) an entry stands for to PROJECTS; return 1
  # when there are none. Non-running variants cost nothing: they are queried,
  # found stopped, and left alone.
  local entry=$1 dir="$PRIVACYBOX_DIR/apps/$1" found=0 f
  if has_compose "$dir"; then
    add_project "$entry"
    return 0
  fi
  if [[ -d $dir ]]; then
    while IFS= read -r f; do
      add_project "$(dirname "${f#"$PRIVACYBOX_DIR/apps/"}")"
      found=1
    done < <(find "$dir" -mindepth 2 -maxdepth 4 \
               \( -name docker-compose.yml -o -name docker-compose.yaml \
                  -o -name compose.yml -o -name compose.yaml \) | sort)
  fi
  [[ $found -eq 1 ]]
}

resolve_entry() {
  # A DEPLOYED_APPS/--app entry must name a compose project: a typo fails
  # before anything is stopped or archived.
  if ! collect_projects "$1"; then
    die "Unknown app '$1': no compose project at apps/$1 or below. Fix DEPLOYED_APPS or the --app argument."
  fi
}

docker_root_tops() {
  # Every directory directly under DOCKER_ROOT, sorted. lost+found is a
  # filesystem artefact, not app data.
  as_root find "$DOCKER_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name lost+found -printf '%f\n' | sort
}

fully_excluded() {
  # True when DOCKER_ROOT/<top> as a whole is an exclude (an EXCLUDE_PATH
  # entry, or BACKUP_ROOT itself): there is nothing to archive, so its app is
  # not stopped either. Paths are compared without doubled or trailing slashes.
  local target="$DOCKER_ROOT/$1" a p
  target=${target//\/\//\/}
  target=${target%/}
  for a in "${EXCLUDE_ARGS[@]}"; do
    p=${a#--exclude=}
    p=${p//\/\//\/}
    p=${p%/}
    if [[ $p == "$target" ]]; then return 0; fi
  done
  return 1
}

list_or_none() {
  if [[ $# -gt 0 ]]; then printf '%s' "$*"; else printf '(none)'; fi
}

backup_group() {
  # backup_group <outdir> <top> <entry>...
  # Stop every listed deployment (if running) -> archive DOCKER_ROOT/<top>
  # once -> verify -> restart the ones that were running. Deployments that
  # were already stopped are deliberately NOT started afterwards.
  local outdir=$1 top=$2
  shift 2
  local entry to_restart=()
  local data_dir="$DOCKER_ROOT/$top"

  if fully_excluded "$top"; then
    log "[$top] whole tree is in EXCLUDE_PATH: skipped, nothing stopped."
    RESULTS+=("$top: SKIPPED (whole tree excluded)")
    return 0
  fi
  if [[ $# -eq 0 ]]; then
    log "[$top] no compose project under apps/: archiving data only."
  fi

  # Failures are recorded, never fatal: the stopped apps are restarted and
  # the run moves on to the next data tree.
  local ok=1
  for entry in "$@"; do
    check_docker_root "$entry"
    if app_running "$entry"; then
      log "[$entry] stopping..."
      to_restart+=("$entry")
      RESTART_PENDING_APPS+=("$entry")
      if ! stop_app "$entry"; then
        err "[$entry] 'down' reported an error."
      fi
      if app_running "$entry"; then
        err "[$entry] containers still present after 'down': not archiving $top."
        ok=0
        break
      fi
    else
      log "[$entry] not running — cold backup, will stay stopped."
    fi
  done

  if [[ $ok -eq 1 ]]; then
    if [[ -d $data_dir ]]; then
      if create_archive "$outdir/$top.tar.gz" "$data_dir"; then
        RESULTS+=("$top: OK -> $outdir/$top.tar.gz")
      else
        ok=0
      fi
    else
      log "[$top] no data directory at $data_dir: nothing to archive (stateless, or its state lives in the repo archive)."
      RESULTS+=("$top: NO DATA DIR ($data_dir) — nothing archived")
    fi
  fi
  if [[ $ok -eq 0 ]]; then
    RESULTS+=("$top: FAILED, not backed up (see the errors above)")
    FAILED_ITEMS+=("$top")
  fi

  for entry in ${to_restart[@]+"${to_restart[@]}"}; do
    log "[$entry] starting..."
    if ! start_app "$entry"; then
      err "[$entry] COULD NOT RESTART: start it manually: ./manage.sh --start --app $entry"
      RESULTS+=("$entry: RESTART FAILED, start it manually")
      FAILED_ITEMS+=("$entry")
    fi
  done
  RESTART_PENDING_APPS=()
  return 0
}

group_for_top() {
  # Fill the global GROUP array with every resolved project whose top-level
  # segment matches $1 (order preserved).
  local top=$1 p
  GROUP=()
  for p in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
    if [[ $(top_of "$p") == "$top" ]]; then
      GROUP+=("$p")
    fi
  done
}

do_rolling() {
  local entries=() entry tops=() listed_tops=() extra_tops=() skipped=()
  local listing top seen t p
  IFS=', ' read -r -a entries <<< "$DEPLOYED_APPS"

  # Resolve DEPLOYED_APPS up front (a typo must fail before anything is
  # stopped or archived), then derive the ordered, unique top-level list.
  PROJECTS=()
  for entry in ${entries[@]+"${entries[@]}"}; do
    resolve_entry "$entry"
  done
  for p in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
    top=$(top_of "$p")
    seen=0
    for t in ${tops[@]+"${tops[@]}"}; do
      if [[ $t == "$top" ]]; then seen=1; fi
    done
    if [[ $seen -eq 0 ]]; then tops+=("$top"); fi
  done

  listed_tops=(${tops[@]+"${tops[@]}"})

  # Then everything else in DOCKER_ROOT, so switched-off apps are covered too.
  # A tree with compose projects under apps/<top> gets the same treatment as a
  # listed one (running: stop/archive/restart, stopped: cold, stays stopped);
  # a tree without is archived data-only.
  listing=$(docker_root_tops) || die "Could not list the directories in $DOCKER_ROOT"
  while IFS= read -r top; do
    [[ -n $top ]] || continue
    seen=0
    for t in ${tops[@]+"${tops[@]}"}; do
      if [[ $t == "$top" ]]; then seen=1; fi
    done
    if [[ $seen -eq 1 ]]; then continue; fi
    collect_projects "$top" || true
    tops+=("$top")
    extra_tops+=("$top")
  done <<< "$listing"
  for top in ${tops[@]+"${tops[@]}"}; do
    if fully_excluded "$top"; then skipped+=("$top"); fi
  done

  local outdir="$HOST_DIR/$TIMESTAMP"
  log "Backup task summary (rolling — each app is only down while its own archive is written):"
  log "  Compose projects: $(list_or_none ${PROJECTS[@]+"${PROJECTS[@]}"})"
  log "  Data trees (DEPLOYED_APPS): $(list_or_none ${listed_tops[@]+"${listed_tops[@]}"})"
  log "  Data trees (rest of DOCKER_ROOT): $(list_or_none ${extra_tops[@]+"${extra_tops[@]}"})"
  log "  Skipped (whole tree excluded): $(list_or_none ${skipped[@]+"${skipped[@]}"})"
  log "  Excludes:"
  print_excludes
  log "  Target: $outdir/"
  confirm
  preflight_space "$(rolling_estimate)"

  mkdir -p "$outdir"
  create_archive "$outdir/privacybox-repo.tar.gz" "$PRIVACYBOX_DIR"
  RESULTS+=("privacybox-repo: OK -> $outdir/privacybox-repo.tar.gz")
  for top in ${tops[@]+"${tops[@]}"}; do
    group_for_top "$top"
    backup_group "$outdir" "$top" ${GROUP[@]+"${GROUP[@]}"}
  done
  finish_run "$outdir"
}

do_single() {
  # --app accepts a top-level name ("ghost", "gluetun") or a single project
  # ("ghost/deployments/eli5", "gluetun/wireguard"); either way the whole
  # top-level group is treated — its data tree can only be archived
  # consistently as one unit.
  local top entry entries=()
  top=$(top_of "$APP_NAME")
  PROJECTS=()
  if [[ -n $DEPLOYED_APPS ]]; then
    IFS=', ' read -r -a entries <<< "$DEPLOYED_APPS"
    for entry in ${entries[@]+"${entries[@]}"}; do
      if [[ $(top_of "$entry") == "$top" ]]; then
        resolve_entry "$entry"
      fi
    done
  fi
  if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    # Not in DEPLOYED_APPS — resolve the named app/project directly.
    resolve_entry "$APP_NAME"
  fi
  group_for_top "$top"

  local outdir="$HOST_DIR/$TIMESTAMP-app-$top"
  log "Backup task summary (single app):"
  log "  App: $top (compose projects: ${GROUP[*]})"
  log "  Excludes:"
  print_excludes
  log "  Target: $outdir/$top.tar.gz (+ privacybox-repo.tar.gz)"
  confirm
  preflight_space "$(newest_backup_size "$HOST_DIR"/*/"$top".tar.gz)"

  mkdir -p "$outdir"
  # Every backup, whatever the mode, carries a copy of the repo itself —
  # compose files, .envs and config are needed to make app data restorable.
  create_archive "$outdir/privacybox-repo.tar.gz" "$PRIVACYBOX_DIR"
  RESULTS+=("privacybox-repo: OK -> $outdir/privacybox-repo.tar.gz")
  backup_group "$outdir" "$top" "${GROUP[@]}"
  finish_run "$outdir"
}

# ------------------------------------------------------------------- main ----

case "$MODE" in
  full)    do_full ;;
  rolling) do_rolling ;;
  single)  do_single ;;
esac
