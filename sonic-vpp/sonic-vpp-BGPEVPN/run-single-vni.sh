#!/bin/bash
#
# Deploy the single-VNI L2 VXLAN EVPN example.
# Two SONiC-VPP routers, one VNI (1000 / VLAN 100), two PCs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source lib/common.sh

TOPO="single-vni.clab.yml"
LAB="sonic-vpp-single-vni"

ROUTER1="sshpass -p admin ssh admin@clab-${LAB}-router1"
ROUTER2="sshpass -p admin ssh admin@clab-${LAB}-router2"

check_prereqs
deploy_topology "$TOPO"
wait_for_healthy "$TOPO" 2

set_swss_log_level "$ROUTER1"
set_swss_log_level "$ROUTER2"

./scripts/setup-single-vni.sh

sleep 5

# BGP underlay (IPv4 unicast + /31 neighbor)
execute "$ROUTER1" "routers/router1/bgp-underlay.vtysh"
execute "$ROUTER2" "routers/router2/bgp-underlay.vtysh"

sleep 5

# VXLAN VTEP + VLAN-to-VNI mappings
execute "$ROUTER1" "routers/router1/vxlan-single-vni.cmd"
execute "$ROUTER2" "routers/router2/vxlan-single-vni.cmd"

sleep 5

# activate BGP EVPN address-family
execute "$ROUTER1" "routers/router1/bgp-evpn.vtysh"
execute "$ROUTER2" "routers/router2/bgp-evpn.vtysh"

echo ""
echo "Single-VNI lab ready. Verify with:"
echo "  docker exec clab-${LAB}-PC1 ping -c 3 168.95.10.1"
