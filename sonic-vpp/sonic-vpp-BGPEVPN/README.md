# SONiC-VPP BGP EVPN

This example demonstrates the integration of a high-performance software data plane ([VPP](https://fd.io/)) with a standardized network operating system ([SONiC](https://sonicfoundation.dev/)) to run advanced data center fabric protocols ([BGP EVPN](https://pantheon.tech/blog-news/what-is-bgp-evpn/)).

You will see two 2-site EVPN-VXLAN labs using **SONiC** + **VPP** data plane:
- **Single-VNI** — two router nodes, one L2 VNI (1000 / VLAN 100), two PCs sharing one broadcast domain
- **Multi-VNI** — two router nodes, two L2 VNIs (1000 / VLAN 100 and 2000 / VLAN 200), four PCs across two isolated broadcast domains

## Prerequisites
- This example was successfully replicated on an **Ubuntu (24.04.2 LTS) WSL** instance in Windows
- [Docker](https://docs.docker.com/engine/install/)
- [ContainerLab](https://containerlab.dev/install/)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

**Files to inspect**

Single-VNI:
- Topology: [single-vni.clab.yml](single-vni.clab.yml)
- Launch script: [run-single-vni.sh](run-single-vni.sh)
- Interface helper: [scripts/setup-single-vni.sh](scripts/setup-single-vni.sh)
- Router VXLAN commands: [routers/router1/vxlan-single-vni.cmd](routers/router1/vxlan-single-vni.cmd), [routers/router2/vxlan-single-vni.cmd](routers/router2/vxlan-single-vni.cmd)

Multi-VNI:
- Topology: [multi-vni.clab.yml](multi-vni.clab.yml)
- Launch script: [run-multi-vni.sh](run-multi-vni.sh)
- Interface helper: [scripts/setup-multi-vni.sh](scripts/setup-multi-vni.sh)
- Router VXLAN commands: [routers/router1/vxlan-multi-vni.cmd](routers/router1/vxlan-multi-vni.cmd), [routers/router2/vxlan-multi-vni.cmd](routers/router2/vxlan-multi-vni.cmd)

Shared (used by both labs):
- BGP underlay & EVPN configs: [routers/router1](routers/router1), [routers/router2](routers/router2)
- Common shell helpers: [lib/common.sh](lib/common.sh)

## Running the example
First, clone the repository so you have a local copy:

```bash
git clone https://github.com/PANTHEONtech/cnf-examples.git
```

### Single-VNI

To launch the single-VNI lab, simply execute the *run-single-vni.sh* script within the folder you downloaded the example to:

```bash
cd /cnf-examples/sonic-vpp/sonic-vpp-BGPEVPN
./run-single-vni.sh
```

The run-single-vni.sh script orchestrates the setup and configuration of the VXLAN environment.

**Configuration flow**

The `run-single-vni.sh` script performs these high-level actions:

1. Deploy the ContainerLab topology from `single-vni.clab.yml`
2. Configure host interfaces and router underlay IPs using `scripts/setup-single-vni.sh`
3. Apply FRR/`vtysh` underlay configurations in `routers/*/bgp-underlay.vtysh` to bring up the IPv4 underlay
4. Apply VPP VXLAN commands in `routers/*/vxlan-single-vni.cmd` to create the VTEP and the VLAN-to-VNI mapping (VLAN 100 → VNI 1000)
5. Apply FRR/`vtysh` BGP EVPN configurations in `routers/*/bgp-evpn.vtysh` to activate the BGP EVPN address-family

**Verification**

1. Start with topology and container checks (use `clab` first, fall back to `docker`):

```bash
clab inspect
docker ps
```

2. Check BGP peerings and EVPN routes

```bash
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "vtysh -c 'show bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router2 "vtysh -c 'show bgp summary'"

sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "vtysh -c 'show bgp l2vpn evpn'"
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router2 "vtysh -c 'show bgp l2vpn evpn'"
```

3. Check VXLAN interfaces on SONiC and VPP:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router2 "show vxlan tunnel"

sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "docker exec syncd vppctl show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router2 "docker exec syncd vppctl show vxlan tunnel"
```

4. Test L2 connectivity between PCs (run from host with `clab exec`):

```bash
docker exec clab-sonic-vpp-single-vni-PC1 ping -c 5 168.95.10.1
```

5. To stop and destroy the example, simply execute the *stop-single-vni.sh* script within the folder you downloaded the example to:

```bash
./stop-single-vni.sh
```

### Multi-VNI

To launch the multi-VNI lab, simply execute the *run-multi-vni.sh* script within the folder you downloaded the example to:

```bash
cd /cnf-examples/sonic-vpp/sonic-vpp-BGPEVPN
./run-multi-vni.sh
```

The run-multi-vni.sh script orchestrates the setup of two simultaneous VXLAN VNIs.

**Configuration flow**

The `run-multi-vni.sh` script performs these high-level actions:

1. Deploy the ContainerLab topology from `multi-vni.clab.yml` (two routers, four PCs across two VLANs)
2. Configure host interfaces and router underlay IPs using `scripts/setup-multi-vni.sh`
3. Apply FRR/`vtysh` underlay configurations in `routers/*/bgp-underlay.vtysh` to bring up the IPv4 underlay
4. Apply VPP VXLAN commands in `routers/*/vxlan-multi-vni.cmd` to create the VTEP and both VLAN-to-VNI mappings (VLAN 100 → VNI 1000 and VLAN 200 → VNI 2000)
5. Apply FRR/`vtysh` BGP EVPN configurations in `routers/*/bgp-evpn.vtysh` to activate the BGP EVPN address-family

**Verification**

1. Start with topology and container checks (use `clab` first, fall back to `docker`):

```bash
clab inspect
docker ps
```

2. Check BGP peerings and EVPN routes (Type-2 / Type-3 entries should appear for both VNIs):

```bash
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router1 "vtysh -c 'show bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router2 "vtysh -c 'show bgp summary'"

sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router1 "vtysh -c 'show bgp l2vpn evpn'"
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router2 "vtysh -c 'show bgp l2vpn evpn'"
```

3. Check VXLAN interfaces on SONiC and VPP (both VNI 1000 and VNI 2000 should be visible):

```bash
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router1 "show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router2 "show vxlan tunnel"

sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router1 "docker exec syncd vppctl show vxlan tunnel"
sshpass -p admin ssh admin@clab-sonic-vpp-multi-vni-router2 "docker exec syncd vppctl show vxlan tunnel"
```

4. Test L2 connectivity within each VNI — cross-VNI traffic should fail by design, since the two VNIs are isolated L2 broadcast domains:

```bash
# VNI 1000 — PC1 ↔ PC2
docker exec clab-sonic-vpp-multi-vni-PC1 ping -c 5 10.100.1.2

# VNI 2000 — PC3 ↔ PC4
docker exec clab-sonic-vpp-multi-vni-PC3 ping -c 5 10.200.1.2
```

5. Run the included test suites for end-to-end validation (multi-VLAN reachability, MAC learning, BUM flooding, dynamic VNI hot-add, scale, link-flap recovery):

```bash
./tests/test_multi_vlan_vxlan.sh
./tests/test_l2_vxlan_advanced.sh
```

6. To stop and destroy the example, simply execute the *stop-multi-vni.sh* script within the folder you downloaded the example to:

```bash
./stop-multi-vni.sh
```

## Packet tracing

To trace packets in VPP on Router1 (single-VNI lab shown — substitute `clab-sonic-vpp-multi-vni-router1` and the appropriate PC/IP for the multi-VNI lab):

```bash
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "docker exec syncd vppctl trace add dpdk-input 10"
# Generate traffic (from PC1):
docker exec clab-sonic-vpp-single-vni-PC1 ping -c 5 168.95.10.1
# View trace results:
sshpass -p admin ssh admin@clab-sonic-vpp-single-vni-router1 "docker exec syncd vppctl show trace"
```

# About

Learn more about [SONiC](https://pantheon.tech/services/expertise/sonic-nos/) and [how to orchestrate it](https://pantheon.tech/products/sandwork/).

Explore our other [SONiC-VPP examples in this repo](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp). 
