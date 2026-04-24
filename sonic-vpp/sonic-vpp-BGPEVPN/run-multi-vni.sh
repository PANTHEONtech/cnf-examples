#!/bin/bash
#
# Deploy the multi-VNI L2 VXLAN EVPN example.
# Two SONiC-VPP routers, two VNIs (1000 / VLAN 100, 2000 / VLAN 200), four PCs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source lib/common.sh

TOPO="multi-vni.clab.yml"
LAB="sonic-vpp-multi-vni"

ROUTER1="sshpass -p admin ssh admin@clab-${LAB}-router1"
ROUTER2="sshpass -p admin ssh admin@clab-${LAB}-router2"

check_prereqs
deploy_topology "$TOPO"
wait_for_healthy "$TOPO" 2

set_swss_log_level "$ROUTER1"
set_swss_log_level "$ROUTER2"

./scripts/setup-multi-vni.sh

sleep 5

# BGP underlay (IPv4 unicast + /31 neighbor)
execute "$ROUTER1" "routers/router1/bgp-underlay.vtysh"
execute "$ROUTER2" "routers/router2/bgp-underlay.vtysh"

sleep 5

# VXLAN VTEP + VLAN-to-VNI mappings for both VNIs
execute "$ROUTER1" "routers/router1/vxlan-multi-vni.cmd"
execute "$ROUTER2" "routers/router2/vxlan-multi-vni.cmd"

sleep 5

# activate BGP EVPN address-family
execute "$ROUTER1" "routers/router1/bgp-evpn.vtysh"
execute "$ROUTER2" "routers/router2/bgp-evpn.vtysh"

echo ""
echo "Multi-VNI lab ready. Verify with:"
echo "  docker exec clab-${LAB}-PC1 ping -c 3 10.100.1.2   # VNI 1000"
echo "  docker exec clab-${LAB}-PC3 ping -c 3 10.200.1.2   # VNI 2000"
echo ""
echo "Run the test suite with:"
echo "  ./tests/test_multi_vlan_vxlan.sh"
echo "  ./tests/test_l2_vxlan_advanced.sh"
