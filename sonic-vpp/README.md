# SONiC-VPP Examples

This repository contains a collection of examples and deployment scenarios for **SONiC-VPP**, demonstrating how to leverage the power of a [VPP-based data plane](https://pantheon.tech/services/expertise/fdio-vector-packet-processing-vpp/) within the [SONiC](https://pantheon.tech/services/expertise/sonic-nos/) ecosystem.

## What is SONiC-VPP?

**SONiC-VPP** is an integration developed by **PANTHEON.tech** that replaces the traditional kernel-based forwarding, or hardware-specific ASIC drivers in SONiC, with **FD.io VPP**. 

## Overview

These examples demonstrate various networking stacks and configurations using SONiC-VPP.

* **[SONiC-VPP L3](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp/sonic-vpp-L3)**
    The foundational example demonstrating basic **L3 connectivity**. It covers interface configuration, IP assignment, and static routing within the SONiC-VPP framework.
    
* **[SONiC-VPP L3-ACL](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp/sonic-vpp-L3-ACL)**
    This example showcases security and traffic filtering capabilities. It demonstrates how to define and apply **ACLs** to manage inbound and outbound traffic flows at the VPP data plane level.

* **[SONiC-VPP L3-BGP](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp/sonic-vpp-L3-BGP)**
    Focuses on **dynamic routing**. It demonstrates the integration of the **FRR** stack within SONiC to establish **BGP peering** sessions, allowing VPP to handle high-throughput routing updates and packet forwarding.

* **[SONiC-VPP L3-BGPEVPN](https://github.com/PANTHEONtech/cnf-examples/tree/master/sonic-vpp/sonic-vpp-L3-BGPEVPN)**
    An advanced networking scenario demonstrating **BGP EVPN** control plane. This highlights the ability of SONiC-VPP to support modern data center fabric technologies and VXLAN tunneling.

## About PANTHEON.tech

Engineering better networks.

* **Website:** [pantheon.tech](https://pantheon.tech/)
* **Contact:** [info@pantheon.tech](mailto:info@pantheon.tech)
