# [Demo] SONiC VPP L3 BGP

A small lab that brings up two [SONiC](https://sonicfoundation.dev/) with [FD.io VPP](fd.io) routers, configures basic BGP on each via [FRR](https://docs.frrouting.org/projects/dev-guide/en/latest/vtysh.html), and connects two Linux PCs to verify end‑to‑end L3 connectivity. This scenario extends [the simpler L3-only demo](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp/sonic-vpp-L3) by adding BGP peering and route advertisement.

## Prerequisites
- This example was successfully replicated on an Ubuntu (24.04.2 LTS) WSL instance in Windows.
- [Docker](https://docs.docker.com/engine/install/)
- [ContainerLab](https://containerlab.dev/install/)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

First, clone the repository so you have a local copy:

```bash
git clone https://github.com/PANTHEONtech/cnf-examples.git
```

To launch the example, simply execute the *run.sh* script within the folder you downloaded the example to:

```bash
./run.sh
```

The run.sh script orchestrates the setup and configuration of the VXLAN environment.

## Verifying the Setup

1. Verify containers

```bash
docker ps
```
-  Ensure that you see containers for PC1, PC2, Router 1 and Router 2.

2. Verify BGP status

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show ip bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show ip bgp'"

sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show ip bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show ip bgp'"
```

3. Verify connectivity between PC1 and PC2

```bash
docker exec clab-sonic-vpp01-PC1 ping -c 5 10.20.2.1
docker exec clab-sonic-vpp01-PC2 ping -c 5 10.20.1.1
```

4. Test Connectivity

```bash
docker exec -it clab-sonic-vpp01-PC1 iperf3 -s
docker exec -it clab-sonic-vpp01-PC2 iperf3 -c 10.20.1.1
```

# About PANTHEON.tech

Do you want to [deploy SONiC](https://pantheon.tech/services/expertise/sonic-nos/) in your infrastructure? Or [orchestrate SONiC with a unique solution](https://pantheon.tech/products/sandwork/)? 

We help enterprises take control of their network infrastructure – through software-driven automation, orchestration, and deep network technology expertise.
