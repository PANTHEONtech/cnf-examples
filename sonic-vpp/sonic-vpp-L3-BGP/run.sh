#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker (https://docs.docker.com/engine/install/) and try again."
    exit 1
fi

# Check if clab is installed
if ! command -v clab &> /dev/null; then
    echo "Containerlab is not installed. Please install Containerlab (https://containerlab.dev/install/) and try again."
    exit 1
fi

# Check if the user is part of the docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    echo "You are not a member of the docker group. Please add yourself to the docker group using:"
    echo "sudo usermod -aG docker $USER"
    echo "Then log out and back in for the changes to take effect."
    exit 1
fi

set -x

ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp01-router1"
ROUTER2="sshpass -p admin ssh admin@clab-sonic-vpp01-router2"

if ! sudo clab deploy --topo sonic-vpp01.clab.yml; then
    { set +x; } > /dev/null 2>&1
    echo "Alternatively, you can manually destroy the existing containers using 'sudo clab destroy --topo sonic-vpp01.clab.yml' and rerun this script."
    exit 1
fi


#Let's wait for the VMs to boot up 

RETRY_INTERVAL=10  # seconds
MAX_RETRIES=20
TARGET_HEALTHY_COUNT=2

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Attempt $i of $MAX_RETRIES..."

    # Run the containerlab inspect and count 'healthy' statuses
    HEALTHY_COUNT=$(clab inspect -f json | grep -o '"status": *"healthy"' | wc -l)

    if [ "$HEALTHY_COUNT" -ge "$TARGET_HEALTHY_COUNT" ]; then
        echo "Success: $HEALTHY_COUNT nodes are healthy. Continuing..."
        break
    else
        echo "Currently $HEALTHY_COUNT healthy nodes. Waiting for $TARGET_HEALTHY_COUNT..."
        if [ "$i" -eq "$MAX_RETRIES" ]; then
            echo "Error: Timeout reached. Not all containers are healthy."
            exit 1
        fi
        sleep $RETRY_INTERVAL
    fi
done

set_swss_log_level() {
    $1 swssloglevel -l ERROR -a
    $1 swssloglevel -l SAI_LOG_LEVEL_INFO -s -a
}

set_swss_log_level "$ROUTER1"
set_swss_log_level "$ROUTER2"

./scripts/PC-interfaces.sh

execute() {
  local host=$1
  local file=$2

  if [[ "$file" == *.vtysh ]]; then
    # Send all commands in the file to vtysh via heredoc inside ssh
    $1 bash <<EOF
vtysh <<EOV
$(cat "$file")
EOV
EOF

  else
    # Handle line-by-line CLI commands (e.g., raw Linux commands)
    mapfile -t commands < "$file"
    for cmd in "${commands[@]}"; do
      $1 "$cmd"
    done
  fi
}

sleep 10

execute "$ROUTER1" "routers/router1/r1-1.vtysh"
execute "$ROUTER2" "routers/router2/r2-1.vtysh"

