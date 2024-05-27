# BGP ECMP

## Overview
This project sets up a BGP ECMP lab using Containerlab. The lab includes multiple routers and PCs configured to test the behavior of BGP and ECMP in a controlled environment. BGP (Border Gateway Protocol) is used to exchange routing information between different networks, while ECMP (Equal-Cost Multi-Path) allows for load balancing across multiple paths of equal cost.



## Requirements
* Prerequisites: [Docker](https://docs.docker.com/engine/install/), [Containerlab](https://containerlab.dev/install/)
* Linux distribution that can run both (Debian, CentOS, Ubuntu, Fedora)


## Setup Instructions

Clone this repository and navigate to this directory:
```sh
cd cnf-examples/vpp-bgp-ecmp
```

### 1. Run the Setup Script
Execute the `run.sh` script to deploy the topology and configure the network interfaces:

```sh
./run.sh
```
### 2. Verify the Setup
Open multiple terminal tabs and run the following commands to verify the setup.

#### First Tab
```sh
docker exec -it clab-frr01-PC2 iperf3 -s
```
#### Second Tab
```sh
docker exec -it clab-frr01-PC1 iperf3 -c 192.168.16.2 -u -t 0
```
#### Third Tab
```sh
docker exec -it clab-frr01-router1 bash
```
```sh
show ip route
```
```sh
show interfaces counter
config interface shutdown Ethernet0
show interfaces counter
```