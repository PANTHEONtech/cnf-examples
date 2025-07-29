#!/bin/sh

set -x

ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp01-router1"
ROUTER2="sshpass -p admin ssh admin@clab-sonic-vpp01-router2"


sudo docker exec -d clab-sonic-vpp01-PC1 ip link set dev eth2 address aa:aa:aa:aa:aa:aa
sudo docker exec -d clab-sonic-vpp01-PC1 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp01-PC1 ip addr add 10.20.1.1/24 dev eth2
sudo docker exec -d clab-sonic-vpp01-PC1 ip route add 10.20.2.0/24 via 10.20.1.254

sudo docker exec -d clab-sonic-vpp01-PC2 ip link set dev eth2 address be:ef:be:ef:be:ef
sudo docker exec -d clab-sonic-vpp01-PC2 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp01-PC2 ip addr add 10.20.2.1/24 dev eth2
sudo docker exec -d clab-sonic-vpp01-PC2 ip route add 10.20.1.0/24 via 10.20.2.254


${ROUTER1} sudo config interface ip add Ethernet0 10.0.1.1/30
${ROUTER1} sudo config interface startup Ethernet0
${ROUTER1} sudo config interface ip add Ethernet4 10.20.1.254/24
${ROUTER1} sudo config interface startup Ethernet4

${ROUTER2} sudo config interface ip add Ethernet0 10.0.1.2/30
${ROUTER2} sudo config interface startup Ethernet0
${ROUTER2} sudo config interface ip add Ethernet4 10.20.2.254/24
${ROUTER2} sudo config interface startup Ethernet4
