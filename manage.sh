#!/bin/bash

# Read config file
config_file="privacybox.config"
declare -A groups=()

while read -r line; do
  group_name=$(echo "$line" | cut -d'=' -f1)
  apps=$(echo "$line" | cut -d'=' -f2)
  groups["$group_name"]="$apps"
  export "$group_name"="$apps"
done < <(grep '^[A-Z_]*=' "$config_file")

# Usage message
usage() {
  echo "Usage: ./manage.sh --(start|stop|restart|update|check-vpn) --(app|group|all) <name>"
  echo "       ./manage.sh --backup"
  echo "       ./manage.sh --create-dsm-tun"
  echo "       ./manage.sh --free-dsm-ports"
  echo "Example: ./manage.sh --start --app wordpress"
  echo "Example: ./manage.sh --restart --group PUBLISHING"
  echo "Example: ./manage.sh --update --all"
  echo "Example: ./manage.sh --check-vpn --group VPN_PROTECTED"
  echo "Example: ./manage.sh --backup"
  echo "Example: ./manage.sh --create-dsm-tun"
  echo "Example: ./manage.sh --free-dsm-ports"
  exit 1
}

# Check if there are enough arguments
if [[ $# -lt 1 ]] || [[ $# -gt 3 ]]; then
  usage
fi

# Parse flags
action=""
entity_type=""
entity_name=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --start|--stop|--restart|--update|--check-vpn) action="${1#--}" ;;
    --app|--group|--all) entity_type="${1#--}" ;;
    --backup) action="backup" ;;
    *) entity_name="$1" ;;
  esac
  shift
done

# Validate input
if [[ -z "$action" ]] || [[ -z "$entity_type" && "$action" != "backup" && "$action" != "free-dsm-ports" && "$action" != "create-dsm-tun" ]]; then
  usage
fi

# Function to check VPN status for a single app
check_vpn() {
  app_name="$1"
  app_dir="apps/$app_name"
  container_id=$(docker-compose -f "$app_dir/docker-compose.yml" ps -q)

  if [ -n "$container_id" ]; then
    container_ip=$(docker exec -it "$container_id" curl -s https://ifconfig.me)
    system_ip=$(curl -s https://ifconfig.me)

    # IP address validation regex
    ip_regex='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'

    if [[ ! $container_ip =~ $ip_regex ]]; then
      echo "Invalid container IP returned for $app_name"
      return
    fi

    if [[ ! $system_ip =~ $ip_regex ]]; then
      echo "Invalid system IP returned"
      return
    fi

    if [ "$container_ip" == "$system_ip" ]; then
      echo "VPN down issuing killswitch for $app_name"
    else
      echo "VPN check passed for $app_name"
    fi
  else
    echo "Container not running for $app_name"
  fi
}

# Function to perform the action on a single app
execute_action() {
  app_name="$1"
  action="$2"
  app_dir="apps/$app_name"

  if [[ -d "$app_dir" ]] && [[ -f "$app_dir/docker-compose.yml" ]]; then
    if [[ "$action" == "check-vpn" ]]; then
      check_vpn "$app_name"
      return
    fi

    echo "${action^}-ing $app_name..."
    cd "$app_dir" || exit
    case $action in
      start) docker-compose up -d ;;
      stop) docker-compose down -v ;;
      restart) docker-compose restart ;;
      update)
        docker-compose pull
        docker-compose up -d --build
        ;;
    esac
    cd - >/dev/null || exit
  else
    echo "App not found: $app_name"
  fi
}

# Function to run backup.sh script
run_backup() {
  backup_script="scripts/backup.sh"

  if [[ -f "$backup_script" ]]; then
    echo "Running backup script..."
    chmod +x "$backup_script"
    ./"$backup_script"
  else
    echo "Backup script not found: $backup_script"
  fi
}

# Function to run create-dsm-tun.sh script
create_dsm_tun() {
  create_dsm_tun="scripts/create-dsm-tun.sh"

  if [[ -f "$create_dsm_tun" ]]; then
    echo "Ensuring tun device is present..."
    chmod +x "$create_dsm_tun"
    ./"$create_dsm_tun"
  else
    echo "DSM script not found: $create_dsm_tun"
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
    echo "DSM script not found: $free_dsm_script"
  fi
}

# Perform the action
if [[ "$action" == "backup" ]]; then
  run_backup
elif [[ "$action" == "create-dsm-tun" ]]; then
  create_dsm_tun
elif [[ "$action" == "free-dsm-ports" ]]; then
  free_dsm_ports
elif [[ "$entity_type" == "all" ]]; then
  IFS=', ' read -ra app_list <<<"${groups["DEPLOYED_APPS"]}"
  for app in "${app_list[@]}"; do
    execute_action "$app" "$action"
  done
else
  case $entity_type in
    app) execute_action "$entity_name" "$action" ;;
    group)
      if [[ -n "${groups[$entity_name]}" ]]; then
        IFS=', ' read -ra app_list <<<"${groups[$entity_name]}"
        if [[ "$action" == "check-vpn" ]]; then
          # Pick a random app from the group
          random_app=${app_list[RANDOM % ${#app_list[@]}]}
          execute_action "$random_app" "$action"
        else
          for app in "${app_list[@]}"; do
            execute_action "$app" "$action"
          done
        fi
      else
        echo "Group not found: $entity_name"
      fi
      ;;
    *) usage ;;
  esac
fi
