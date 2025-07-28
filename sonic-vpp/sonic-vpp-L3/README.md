To launch the project, simply execute the run.sh script:

```bash
./run.sh
```

The run.sh script orchestrates the setup and configuration of the L3 network.

## Verifying the Setup

- Verify instances

```bash
clab inspect
```
Ensure that you see containers for Router 1, Router 2, PC1, and PC2.

- Verify connectivity between router1 and router2

```bash
sshpass -p admin ssh admin@clab-sonic-vpp01-router1 ping -c5 10.0.1.2
sshpass -p admin ssh admin@clab-sonic-vpp01-router2 ping -c5 10.0.1.1
```

- Verify connectivity between PC1 and PC2

```bash
docker exec clab-sonic-vpp01-PC1 ping -c 5 10.20.2.1
docker exec clab-sonic-vpp01-PC2 ping -c 5 10.20.1.1
```

- Test Connectivity

```bash
docker exec -it clab-sonic-vpp01-PC1 iperf3 -s
docker exec -it clab-sonic-vpp01-PC2 iperf3 -c 10.20.1.1
```

