#!/bin/sh

sudo docker exec -d clab-frr01-PC1 ip link set eth1 up
sudo docker exec -d clab-frr01-PC1 ip addr add 192.168.11.2/24 dev eth1
sudo docker exec -d clab-frr01-PC1 ip route add 192.168.0.0/16 via 192.168.11.1 dev eth1
sudo docker exec -d clab-frr01-PC1 ip route add 10.10.10.0/24 via 192.168.11.1 dev eth1
#iperf3 has obviously problem with larger mtu and fragmentation, so for testing purpose mtu is set to 1500
sudo docker exec -d clab-frr01-PC1 ip link set dev eth1 mtu 1500

sudo docker exec -d clab-frr01-PC2 ip link set eth1 up
sudo docker exec -d clab-frr01-PC2 ip addr add 192.168.16.2/24 dev eth1
sudo docker exec -d clab-frr01-PC2 ip route add 192.168.0.0/16 via 192.168.16.1 dev eth1
sudo docker exec -d clab-frr01-PC2 ip route add 10.10.10.0/24 via 192.168.16.1 dev eth1

sudo docker exec -d clab-frr01-router1 config interface ip add Ethernet0 192.168.12.1/24
sudo docker exec -d clab-frr01-router1 config interface ip add Ethernet1 192.168.13.1/24
sudo docker exec -d clab-frr01-router1 config interface ip add Ethernet2 192.168.11.1/24
sudo docker exec -d clab-frr01-router1 config interface startup Ethernet0
sudo docker exec -d clab-frr01-router1 config interface startup Ethernet1
sudo docker exec -d clab-frr01-router1 config interface startup Ethernet2


sudo docker exec -d clab-frr01-router2 config interface ip add Ethernet0 192.168.12.2/24
sudo docker exec -d clab-frr01-router2 config interface ip add Ethernet1 192.168.14.1/24
sudo docker exec -d clab-frr01-router2 config interface startup Ethernet0
sudo docker exec -d clab-frr01-router2 config interface startup Ethernet1

sudo docker exec -d clab-frr01-router3 config interface ip add Ethernet0 192.168.13.2/24
sudo docker exec -d clab-frr01-router3 config interface ip add Ethernet1 192.168.15.1/24
sudo docker exec -d clab-frr01-router3 config interface startup Ethernet0
sudo docker exec -d clab-frr01-router3 config interface startup Ethernet1

sudo docker exec -d clab-frr01-router4 config interface ip add Ethernet0 192.168.14.2/24
sudo docker exec -d clab-frr01-router4 config interface ip add Ethernet1 192.168.15.2/24
sudo docker exec -d clab-frr01-router4 config interface ip add Ethernet2 192.168.16.1/24
sudo docker exec -d clab-frr01-router4 config interface startup Ethernet0
sudo docker exec -d clab-frr01-router4 config interface startup Ethernet1
sudo docker exec -d clab-frr01-router4 config interface startup Ethernet2

