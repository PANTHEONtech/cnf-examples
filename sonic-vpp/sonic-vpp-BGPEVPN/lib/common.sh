#!/bin/bash
#
# common.sh — Shared helpers for SONiC-VPP BGP EVPN examples.
# Source this from run-*.sh scripts; do not execute directly.

# -----------------------------------------------------------------------------
# Prerequisites
# -----------------------------------------------------------------------------
check_prereqs() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. See https://docs.docker.com/engine/install/"
        exit 1
    fi

    if ! command -v clab &> /dev/null; then
        echo "Containerlab is not installed. See https://containerlab.dev/install/"
        exit 1
    fi

    if ! command -v sshpass &> /dev/null; then
        echo "sshpass is not installed. Install it with: sudo apt-get install sshpass"
        exit 1
    fi

    if ! groups "$USER" | grep -q '\bdocker\b'; then
        echo "You are not a member of the docker group. Run:"
        echo "  sudo usermod -aG docker $USER"
        echo "Then log out and back in for the changes to take effect."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Topology deployment
# -----------------------------------------------------------------------------
deploy_topology() {
    local topo_file="$1"

    if ! sudo clab deploy --topo "$topo_file"; then
        echo "Deploy failed. To retry from a clean state:"
        echo "  sudo clab destroy --topo $topo_file"
        echo "Then rerun this script."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Wait until the expected number of nodes report as healthy.
#
# Args:
#   $1 — topology file (passed to `clab inspect`)
#   $2 — number of nodes expected to be healthy
# -----------------------------------------------------------------------------
wait_for_healthy() {
    local topo_file="$1"
    local target="$2"
    local retry_interval=10
    local max_retries=20

    for ((i=1; i<=max_retries; i++)); do
        echo "Attempt $i of $max_retries..."
        local healthy
        healthy=$(clab inspect --topo "$topo_file" -f json \
                  | grep -o '"status": *"healthy"' | wc -l)

        if [ "$healthy" -ge "$target" ]; then
            echo "Success: $healthy nodes are healthy. Continuing..."
            return 0
        fi

        echo "Currently $healthy healthy nodes. Waiting for $target..."
        if [ "$i" -eq "$max_retries" ]; then
            echo "Error: Timeout waiting for $target healthy nodes."
            exit 1
        fi
        sleep "$retry_interval"
    done
}

# -----------------------------------------------------------------------------
# you can set any log level for any component here
# -----------------------------------------------------------------------------
set_swss_log_level() {
    local ssh_cmd="$1"
    $ssh_cmd swssloglevel -l ERROR -a
    $ssh_cmd swssloglevel -l SAI_LOG_LEVEL_INFO -s -a
}

# -----------------------------------------------------------------------------
# Apply a config file to a router.
#
# Args:
#   $1 — SSH command prefix (e.g. "sshpass -p admin ssh admin@...")
#   $2 — path to config file (relative to the caller's working directory)
# -----------------------------------------------------------------------------
execute() {
    local ssh_cmd="$1"
    local file="$2"

    if [[ "$file" == *.vtysh ]]; then
        $ssh_cmd bash <<EOF
vtysh <<EOV
$(cat "$file")
EOV
EOF
    else
        local cmd
        while IFS= read -r cmd || [ -n "$cmd" ]; do
            [ -z "$cmd" ] && continue
            $ssh_cmd "$cmd" < /dev/null
        done < "$file"
    fi
}
