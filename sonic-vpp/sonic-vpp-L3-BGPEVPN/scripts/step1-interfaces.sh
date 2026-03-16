#!/bin/sh

set -x

ROUTER1="sshpass -p admin ssh admin@clab-sonic-vpp01-router1"
ROUTER2="sshpass -p admin ssh admin@clab-sonic-vpp01-router2"


sudo docker exec -d clab-sonic-vpp01-PC1 ip link set dev eth2 address aa:aa:aa:aa:aa:aa
sudo docker exec -d clab-sonic-vpp01-PC1 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp01-PC1 ip addr add 168.95.10.2/16 dev eth2
#sudo docker exec -d clab-sonic-vpp01-PC1 ip route add 0.0.0.0/0 dev eth2
 
sudo docker exec -d clab-sonic-vpp01-PC2 ip link set dev eth2 address be:ef:be:ef:be:ef
sudo docker exec -d clab-sonic-vpp01-PC2 ip link set eth2 up
sudo docker exec -d clab-sonic-vpp01-PC2 ip addr add 168.95.10.1/16 dev eth2
 
${ROUTER1} sudo config interface ip add Ethernet0 10.0.1.1/31
${ROUTER1} sudo config interface startup Ethernet0
${ROUTER1} sudo config interface startup Ethernet4

${ROUTER2} sudo config interface ip add Ethernet0 10.0.1.0/31
${ROUTER2} sudo config interface startup Ethernet0
${ROUTER2} sudo config interface startup Ethernet4
