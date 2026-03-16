**Introduction**

This example demonstrates a 2-site EVPN-VXLAN lab using SONiC + VPP data plane. The lab shows how BGP EVPN routes are signalled between two router nodes and how VPP-created VXLAN tunnels forward L2 traffic so remote PCs appear on the same L2 VNI.

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


**Files to inspect**

- Topology: [sonic-vpp-L3-BGPEVPN/sonic-vpp01.clab.yml](sonic-vpp-L3-BGPEVPN/sonic-vpp01.clab.yml)
- Launch script: [sonic-vpp-L3-BGPEVPN/run.sh](sonic-vpp-L3-BGPEVPN/run.sh)
- Interface helper: [sonic-vpp-L3-BGPEVPN/scripts/step1-interfaces.sh](sonic-vpp-L3-BGPEVPN/scripts/step1-interfaces.sh)
- Router configs and VXLAN commands: [sonic-vpp-L3-BGPEVPN/routers](sonic-vpp-L3-BGPEVPN/routers)


**Configuration flow**

`run.sh` / the deploy steps perform these high-level actions:

1. Deploy the ContainerLab topology from `sonic-vpp01.clab.yml`.
2. Configure host interfaces using `scripts/step1-interfaces.sh`.
3. Apply FRR/`vtysh` configurations in `routers/*/*.vtysh` to establish BGP EVPN sessions.
4. Apply VPP VXLAN commands in `routers/*/*-vxlan.cmd` to create VXLAN tunnels on each router.

**Verification**

Start with topology and container checks (use `clab` first, fall back to `docker`):

```bash
clab inspect
docker ps
```

Check BGP peerings and EVPN routes

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show bgp summary'"

sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show bgp l2vpn evpn'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show bgp l2vpn evpn'"
```

Check VXLAN interfaces on SONiC and VPP:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "show vxlan tunnel"

sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "docker exec syncd vppctl show vxlan tunnel"
```

Test L2 connectivity between PCs (run from host with `clab exec`):

```bash
docker exec clab-sonic-vpp01-PC1 ping -c 5 168.95.10.1
```

To stop and destroy the example, simply execute the *stop.sh* script within the folder you downloaded the example to:

```bash
./stop.sh
```


**Packet Tracing**

To trace packets in VPP on Router1:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl trace add dpdk-input 10"
# Generate traffic (from PC1):
docker exec clab-sonic-vpp01-PC1 ping -c 5 168.95.10.1
# View trace results:
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "docker exec syncd vppctl show trace"
```