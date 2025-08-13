# [Demo] SONiC VPP L3

This demo showcases L3 integration between [SONiC](https://sonicfoundation.dev/) and [FD.io VPP](fd.io), enabling high-performance routing in a containerized environment, using SONiC as control plane and FD.io VPP as the fast software data plane.

## Prerequisites
- This example was successfully replicated on an Ubuntu (24.04.2 LTS) WSL instance in Windows.
- [Docker](https://docs.docker.com/engine/install/)
- [ContainerLab](https://containerlab.dev/install/)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

To launch the example, simply execute the *run.sh* script:

```bash
./run.sh
```

The run.sh script orchestrates the setup and configuration of the L3 network.

## Verifying the Setup

1. Verify instances

```bash
clab inspect
```
-  Ensure that you see containers for PC1, PC2, Router 1 and Router 2.
-  Take note of the IP address each container is given. Replace them in the commands below. The output of *inspect* should look like this:

```Example Output
╭──────────────────────────┬──────────────────────────────────────────┬───────────┬───────────────────╮
│           Name           │                Kind/Image                │   State   │   IPv4/6 Address  │
├──────────────────────────┼──────────────────────────────────────────┼───────────┼───────────────────┤
│ clab-sonic-vpp01-PC1     │ linux                                    │ running   │ 192.xx.xx.x       │
│                          │ wbitt/network-multitool:extra            │           │ 3fff:172:20:20::2 │
├──────────────────────────┼──────────────────────────────────────────┼───────────┼───────────────────┤
│ clab-sonic-vpp01-PC2     │ linux                                    │ running   │ 192.xx.xx.x       │
│                          │ wbitt/network-multitool:extra            │           │ 3fff:172:20:20::3 │
├──────────────────────────┼──────────────────────────────────────────┼───────────┼───────────────────┤
│ clab-sonic-vpp01-router1 │ sonic-vm                                 │ running   │ 192.xx.xx.x       │
│                          │ ghcr.io/pantheontech/sonic-vpp-vs:250619 │ (healthy) │ 3fff:172:20:20::4 │
├──────────────────────────┼──────────────────────────────────────────┼───────────┼───────────────────┤
│ clab-sonic-vpp01-router2 │ sonic-vm                                 │ running   │ 192.xx.xx.x       │
│                          │ ghcr.io/pantheontech/sonic-vpp-vs:250619 │ (healthy) │ 3fff:172:20:20::5 │
╰──────────────────────────┴──────────────────────────────────────────┴───────────┴───────────────────╯
```
2. Verify connectivity between router1 and router2

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 ping -c5 10.0.1.2
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 ping -c5 10.0.1.1
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

## But why?

This example demonstrates Layer 3 routing integration between SONiC and [FD.io VPP](fd.io) using a real-world, containerized CNF setup. It showcases how to extend SONiC - traditionally a hardware-centric network OS - into a software-forwarding environment using VPP as the data plane, which is highly performant, flexible, and cloud-native.

# About PANTHEON.tech

Do you want to [deploy SONiC](https://pantheon.tech/services/expertise/sonic-nos/) in your infrastructure? Or [orchestrate SONiC with a unique solution](https://pantheon.tech/products/sandwork/)? 

We help enterprises take control of their network infrastructure – through software-driven automation, orchestration, and deep network technology expertise.
