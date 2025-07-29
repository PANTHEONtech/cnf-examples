To launch the project, simply execute the run.sh script:

```bash
./run.sh
```

The run.sh script orchestrates the setup and configuration of the VXLAN environment.

## Verifying the Setup

- Verify Container

```bash
docker ps
```
Ensure that you see containers for Router 1, Router 2, PC1, and PC2.

- Verify BGP Status

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show ip bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 "vtysh -c 'show ip bgp'"

sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show ip bgp summary'"
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 "vtysh -c 'show ip bgp'"
```

 Verify connectivity between PC1 and PC2

```bash
docker exec clab-sonic-vpp01-PC1 ping -c 5 10.20.2.1
docker exec clab-sonic-vpp01-PC2 ping -c 5 10.20.1.1
```

- Test Connectivity

```bash
docker exec -it clab-sonic-vpp01-PC1 iperf3 -s
docker exec -it clab-sonic-vpp01-PC2 iperf3 -c 10.20.1.1
```
