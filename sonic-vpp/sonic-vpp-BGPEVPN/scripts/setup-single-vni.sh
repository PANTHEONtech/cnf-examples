#!/bin/sh
#
# Configure PC interfaces and router underlay IPs for the single-VNI lab.

set -e

LAB="sonic-vpp-single-vni"
ROUTER1="sshpass -p admin ssh admin@clab-${LAB}-router1"
ROUTER2="sshpass -p admin ssh admin@clab-${LAB}-router2"

# ---- PCs on VNI 1000 / VLAN 100 -----------------------------------------
sudo docker exec -d clab-${LAB}-PC1 ip link set dev eth2 address aa:aa:aa:aa:aa:aa
sudo docker exec -d clab-${LAB}-PC1 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC1 ip addr add 168.95.10.2/16 dev eth2
# Drop clab mgmt default route so non-VXLAN traffic fails cleanly
# instead of escaping via eth0 (172.20.20.0/24).
sudo docker exec clab-${LAB}-PC1 ip route del default 2>/dev/null || true

sudo docker exec -d clab-${LAB}-PC2 ip link set dev eth2 address be:ef:be:ef:be:ef
sudo docker exec -d clab-${LAB}-PC2 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC2 ip addr add 168.95.10.1/16 dev eth2
sudo docker exec clab-${LAB}-PC2 ip route del default 2>/dev/null || true

# ---- Router underlay interfaces -----------------------------------------
${ROUTER1} sudo config interface ip add Ethernet0 10.0.1.1/31
${ROUTER1} sudo config interface startup Ethernet0
${ROUTER1} sudo config interface startup Ethernet4

${ROUTER2} sudo config interface ip add Ethernet0 10.0.1.0/31
${ROUTER2} sudo config interface startup Ethernet0
${ROUTER2} sudo config interface startup Ethernet4
