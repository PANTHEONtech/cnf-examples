#!/bin/sh
set -e

# Define SSH connection
ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp01-router1"

# Default ACL file (can be overridden by passing a file path as the first argument)
ACL_FILE="${1:-routers/router1_acl.json}"

if [ ! -f "$ACL_FILE" ]; then
  echo "Error: ACL file '$ACL_FILE' not found."
  echo "Provide a path to an ACL JSON file or ensure 'routers/router1_acl.json' exists."
  exit 1
fi

echo "Applying ACL from '$ACL_FILE' to router1..."
cat "$ACL_FILE" | ${ROUTER1} "cat > /tmp/acl_demo.json && sudo config load -y /tmp/acl_demo.json"
echo "ACL applied successfully."

