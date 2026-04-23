# SONiC-VPP L3 BGP EVPN

This example demonstrates the integration of a high-performance software data plane ([VPP](https://fd.io/)) with a standardized network operating system ([SONiC](https://sonicfoundation.dev/)) to run advanced data center fabric protocols ([BGP EVPN](https://pantheon.tech/blog-news/what-is-bgp-evpn/)).

You will see a 2-site EVPN-VXLAN lab using **SONiC** + **VPP** data plane. The lab shows how: 
- **BGP EVPN** routes are signaled between two router nodes
- How VPP-created VXLAN tunnels forward L2 traffic so remote PCs appear on the same L2 VNI

## Prerequisites
- This example was successfully replicated on an **Ubuntu (24.04.2 LTS) WSL** instance in Windows
- [Docker](https://docs.docker.com/engine/install/)
- [ContainerLab](https://containerlab.dev/install/)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

**Files to inspect**

- Topology: [sonic-vpp-L3-BGPEVPN/sonic-vpp01.clab.yml](sonic-vpp-L3-BGPEVPN/sonic-vpp01.clab.yml)
- Launch script: [sonic-vpp-L3-BGPEVPN/run.sh](sonic-vpp-L3-BGPEVPN/run.sh)
- Interface helper: [sonic-vpp-L3-BGPEVPN/scripts/step1-interfaces.sh](sonic-vpp-L3-BGPEVPN/scripts/step1-interfaces.sh)
- Router configs and VXLAN commands: [sonic-vpp-L3-BGPEVPN/routers](sonic-vpp-L3-BGPEVPN/routers)

## Running the example
First, clone the repository so you have a local copy:

```bash
git clone https://github.com/PANTHEONtech/cnf-examples.git
```

To launch the example, simply execute the *run.sh* script within the folder you downloaded the example to:

```bash
cd /cnf-examples/sonic-vpp/sonic-vpp-L3-BGPEVPN
./run.sh
```

The run.sh script orchestrates the setup and configuration of the VXLAN environment.

**Configuration flow**

The `run.sh` script performs these high-level actions:

1. Deploy the ContainerLab topology from `sonic-vpp01.clab.yml`
2. Configure host interfaces using `scripts/step1-interfaces.sh`
3. Apply FRR/`vtysh` configurations in `routers/*/*.vtysh` to establish BGP EVPN sessions
4. Apply VPP VXLAN commands in `routers/*/*-vxlan.cmd` to create VXLAN tunnels on each router

**Verification**

1. Start with topology and container checks (use `clab` first, fall back to `docker`):

```bash
clab inspect
docker ps
```

2. Check BGP peerings and EVPN routes

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show bgp summary'"

sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show bgp l2vpn evpn'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show bgp l2vpn evpn'"
```

3. Check VXLAN interfaces on SONiC and VPP:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "show vxlan tunnel"

sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "docker exec syncd vppctl show vxlan tunnel"
```

4. Test L2 connectivity between PCs (run from host with `clab exec`):

```bash
docker exec clab-sonic-vpp01-PC1 ping -c 5 168.95.10.1
```

5. To stop and destroy the example, simply execute the *stop.sh* script within the folder you downloaded the example to:

```bash
./stop.sh
```

## Packet tracing

To trace packets in VPP on Router1:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl trace add dpdk-input 10"
# Generate traffic (from PC1):
docker exec clab-sonic-vpp01-PC1 ping -c 5 168.95.10.1
# View trace results:
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl show trace"
```

# About

Learn more about [SONiC](https://pantheon.tech/services/expertise/sonic-nos/) and [how to orchestrate it](https://pantheon.tech/products/sandwork/).

Explore our other [SONiC-VPP examples in this repo](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp). 
