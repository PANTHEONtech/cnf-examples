#!/bin/sh

ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp02-router1"
ROUTER2="sshpass -p admin ssh admin@clab-sonic-vpp02-router2"

# VLAN 100 / VNI 1000 hosts
sudo docker exec -d clab-sonic-vpp02-PC1 ip link set dev eth2 address aa:aa:aa:aa:aa:01
sudo docker exec -d clab-sonic-vpp02-PC1 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp02-PC1 ip addr add 10.100.1.1/24 dev eth2

sudo docker exec -d clab-sonic-vpp02-PC2 ip link set dev eth2 address aa:aa:aa:aa:aa:02
sudo docker exec -d clab-sonic-vpp02-PC2 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp02-PC2 ip addr add 10.100.1.2/24 dev eth2

# VLAN 200 / VNI 2000 hosts
sudo docker exec -d clab-sonic-vpp02-PC3 ip link set dev eth2 address bb:bb:bb:bb:bb:03
sudo docker exec -d clab-sonic-vpp02-PC3 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp02-PC3 ip addr add 10.200.1.1/24 dev eth2

sudo docker exec -d clab-sonic-vpp02-PC4 ip link set dev eth2 address bb:bb:bb:bb:bb:04
sudo docker exec -d clab-sonic-vpp02-PC4 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp02-PC4 ip addr add 10.200.1.2/24 dev eth2

# Router underlay interfaces
${ROUTER1} sudo config interface ip add Ethernet0 10.0.1.1/31
${ROUTER1} sudo config interface startup Ethernet0
${ROUTER1} sudo config interface startup Ethernet4
${ROUTER1} sudo config interface startup Ethernet8

${ROUTER2} sudo config interface ip add Ethernet0 10.0.1.0/31
${ROUTER2} sudo config interface startup Ethernet0
${ROUTER2} sudo config interface startup Ethernet4
${ROUTER2} sudo config interface startup Ethernet8
