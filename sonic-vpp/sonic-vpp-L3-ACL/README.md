# [Demo] SONiC + VPP L3 ACL

This demo shows IPv4 ACL integration between [SONiC](https://sonicfoundation.dev/) (control plane) and [FD.io VPP](fd.io) VPP (data plane) in a ContainerLab topology, with SONiC as the control plane and FD.io VPP as the fast data plane.

## Prerequisites
- Ubuntu (tested on 24.04.2 LTS)
- [Docker](https://docs.docker.com/engine/install/)
- [ContainerLab](https://containerlab.dev/install/)
- [sshpass](https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/)

Get the repo:

```bash
git clone https://github.com/PANTHEONtech/cnf-examples.git
cd cnf-examples/sonic-vpp/sonic-vpp-L3-ACL
```

Launch the demo:

```bash
./run.sh
```

run.sh deploys the ContainerLab topology, waits for nodes to become healthy, adjusts SONiC log levels, configures PC interfaces, and applies ACLs on router1.

## Verifying the Setup

1. Check containers and addresses:

```bash
clab inspect
```
2. Verify router-to-router connectivity:

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 ping -c5 10.0.1.2
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 ping -c5 10.0.1.1
```

3. Web traffic from PC2 to PC1 is allowed:

```bash
docker exec clab-sonic-vpp01-PC1 curl -s 10.20.2.1
```

3. Iperf (TCP - 5201) traffic from PC2 to PC1 is allowed:

```bash
docker exec -it clab-sonic-vpp01-PC2 iperf3 -s
docker exec -it clab-sonic-vpp01-PC1 iperf3 -c 10.20.2.1
```

5. Any other traffic from PC1 is dropped by the ACL rule on router1:

```bash
docker exec clab-sonic-vpp01-PC1 ping ping -W 1 -c 5 10.20.2.1
```

## Notes and tips

Files to inspect first

- ```run.sh``` — orchestration and health checks
- ```sonic-vpp01.clab.yml``` — topology
- ```scripts/PC-interfaces.sh``` — endpoint configuration
- ```scripts/acl.sh``` and ```routers/router1_acl.json``` — ACL application


# About PANTHEON.tech

Do you want to [deploy SONiC](https://pantheon.tech/services/expertise/sonic-nos/) in your infrastructure? Or [orchestrate SONiC with a unique solution](https://pantheon.tech/products/sandwork/)? 

We help enterprises take control of their network infrastructure – through software-driven automation, orchestration, and deep network technology expertise.
