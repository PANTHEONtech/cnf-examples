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

ROUTER1="docker exec clab-frr01-router1"
ROUTER2="docker exec clab-frr01-router2"

if ! sudo clab deploy --topo frr01.clab.yml; then
    { set +x; } > /dev/null 2>&1
    echo "Alternatively, you can manually destroy the existing containers using 'sudo clab destroy --topo frr01.clab.yml' and rerun this script."
    exit 1
fi

sleep 50

set_swss_log_level() {
    $1 swssloglevel -l INFO -c syncd
    $1 swssloglevel -l INFO -c fdbsyncd
    $1 swssloglevel -l INFO -c orchagent
    $1 swssloglevel -l SAI_LOG_LEVEL_INFO -s -a
}

set_swss_log_level "$ROUTER1"
set_swss_log_level "$ROUTER2"

./scripts/PC-interfaces.sh

execute() {
if [[ "$2" == *.vtysh ]]; then
	commands=$(cat $2)
     $1 vtysh -c "$commands"
else
    mapfile -t commands < $2
    
    for cmd in "${commands[@]}"; do
    $1 $cmd 
    done
fi
}

sleep 10

execute "$ROUTER1" "routers/router1/r1-1.vtysh"  
execute "$ROUTER2" "routers/router2/r2-1.vtysh"

sleep 10

execute "$ROUTER1" "routers/router1/r1-vxlan.cmd"  
execute "$ROUTER2" "routers/router2/r2-vxlan.cmd" 

sleep 10

execute "$ROUTER1" "routers/router1/r1-2.vtysh"
execute "$ROUTER2" "routers/router2/r2-2.vtysh"

# First sleep is intentional to load all services inside of the containers
# The others are only for better visibility in syslog


