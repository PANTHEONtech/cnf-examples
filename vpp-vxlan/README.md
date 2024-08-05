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
docker exec clab-frr01-router1 vtysh -c "show ip bgp summary"
docker exec clab-frr01-router2 vtysh -c "show ip bgp summary"
```

- Verify VXLAN Interfaces

```bash
docker exec clab-frr01-router1 ip -d link show type vxlan
docker exec clab-frr01-router2 ip -d link show type vxlan
```

- Verify EVPN Routes


```bash
docker exec clab-frr01-router1 vtysh -c "show bgp l2vpn evpn"
docker exec clab-frr01-router2 vtysh -c "show bgp l2vpn evpn"
```

- Test Connectivity

```bash
docker exec clab-frr01-PC1 ping -c 5 168.95.10.1
```


- Packet Tracing

    - Enable Packet Tracing

    ```bash
    docker exec -it clab-frr01-router1 vppctl trace add af-packet-input 10
    ```

    - Generate Traffic

    ```bash
    docker exec clab-frr01-PC1 ping -c 5 168.95.10.1
    ```

    - View Trace Results

    ```bash
    docker exec clab-frr01-router1 vppctl show trace
    ```