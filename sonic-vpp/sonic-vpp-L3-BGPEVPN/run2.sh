#!/bin/bash

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! command -v clab &> /dev/null; then
    echo "Containerlab is not installed. Please install Containerlab and try again."
    exit 1
fi

set -x

ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp02-router1"
ROUTER2="sshpass -p admin ssh admin@clab-sonic-vpp02-router2"

if ! sudo clab deploy --topo sonic-vpp02.clab.yml; then
    { set +x; } > /dev/null 2>&1
    echo "Deploy failed. You can manually destroy with 'sudo clab destroy --topo sonic-vpp02.clab.yml' and retry."
    exit 1
fi

# Wait for VMs to boot up
RETRY_INTERVAL=10
MAX_RETRIES=20
TARGET_HEALTHY_COUNT=2

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Attempt $i of $MAX_RETRIES..."
    HEALTHY_COUNT=$(clab inspect --topo sonic-vpp02.clab.yml -f json | grep -o '"status": *"healthy"' | wc -l)

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

./scripts/PC-interfaces2.sh

execute() {
  local host=$1
  local file=$2

  if [[ "$file" == *.vtysh ]]; then
    $1 bash <<EOF
vtysh <<EOV
$(cat "$file")
EOV
EOF
  else
    mapfile -t commands < "$file"
    for cmd in "${commands[@]}"; do
      $1 "$cmd"
    done
  fi
}

sleep 5

execute "$ROUTER1" "routers/router1/r1-1.vtysh"
execute "$ROUTER2" "routers/router2/r2-1.vtysh"

sleep 5

execute "$ROUTER1" "routers/router1/r1-vxlan2.cmd"
execute "$ROUTER2" "routers/router2/r2-vxlan2.cmd"

sleep 5

execute "$ROUTER1" "routers/router1/r1-2.vtysh"
execute "$ROUTER2" "routers/router2/r2-2.vtysh"