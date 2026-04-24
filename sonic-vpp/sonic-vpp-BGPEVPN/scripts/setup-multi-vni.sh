#!/bin/sh
#
# Configure PC interfaces and router underlay IPs for the multi-VNI lab.

set -e

LAB="sonic-vpp-multi-vni"
ROUTER1="sshpass -p admin ssh admin@clab-${LAB}-router1"
ROUTER2="sshpass -p admin ssh admin@clab-${LAB}-router2"

# ---- PCs on VNI 1000 / VLAN 100 -----------------------------------------
sudo docker exec -d clab-${LAB}-PC1 ip link set dev eth2 address aa:aa:aa:aa:aa:01
sudo docker exec -d clab-${LAB}-PC1 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC1 ip addr add 10.100.1.1/24 dev eth2
# Drop clab mgmt default route so cross-VNI tests fail cleanly instead of
# escaping to the internet via eth0 (172.20.20.0/24).
sudo docker exec clab-${LAB}-PC1 ip route del default 2>/dev/null || true

sudo docker exec -d clab-${LAB}-PC2 ip link set dev eth2 address aa:aa:aa:aa:aa:02
sudo docker exec -d clab-${LAB}-PC2 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC2 ip addr add 10.100.1.2/24 dev eth2
sudo docker exec clab-${LAB}-PC2 ip route del default 2>/dev/null || true

# ---- PCs on VNI 2000 / VLAN 200 -----------------------------------------
sudo docker exec -d clab-${LAB}-PC3 ip link set dev eth2 address bb:bb:bb:bb:bb:03
sudo docker exec -d clab-${LAB}-PC3 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC3 ip addr add 10.200.1.1/24 dev eth2
sudo docker exec clab-${LAB}-PC3 ip route del default 2>/dev/null || true

sudo docker exec -d clab-${LAB}-PC4 ip link set dev eth2 address bb:bb:bb:bb:bb:04
sudo docker exec -d clab-${LAB}-PC4 ip link set eth2 up
sudo docker exec -d clab-${LAB}-PC4 ip addr add 10.200.1.2/24 dev eth2
sudo docker exec clab-${LAB}-PC4 ip route del default 2>/dev/null || true

# ---- Router underlay interfaces -----------------------------------------
${ROUTER1} sudo config interface ip add Ethernet0 10.0.1.1/31
${ROUTER1} sudo config interface startup Ethernet0
${ROUTER1} sudo config interface startup Ethernet4
${ROUTER1} sudo config interface startup Ethernet8

${ROUTER2} sudo config interface ip add Ethernet0 10.0.1.0/31
${ROUTER2} sudo config interface startup Ethernet0
${ROUTER2} sudo config interface startup Ethernet4
${ROUTER2} sudo config interface startup Ethernet8
