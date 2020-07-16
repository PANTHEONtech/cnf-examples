VPP Traceability with eBPF
==========================

VPP-BPF tooling is Python script build on BCC [https://github.com/iovisor/bcc], a 
Berkeley Packet Filter Compiler Collection.

It enables to trace running VPP and displays combines output from all USDT probes,
inserted into VPP's code (see below) including data-plane (interface, error and node counters)
and control-plane changes performed via CLI and/or API commands into one otput.

Linux Kernel Requirements:
--------------

   It is recommended that you are running a Linux 4.9 kernel or higher.

Requirements:
--------------
### Installed BCC and BPFtrace

- [https://github.com/iovisor/bcc/blob/master/INSTALL.md]
- [https://github.com/iovisor/bpftrace/blob/master/INSTALL.md]

### VPP [FD.io]

- Version v20.09 and commit 'a5cf6e077' was used for this demo.
   ```
   a5cf6e077 build: add libssl-dev library for ubuntu 20.04
   ```
- Clone VPP.
   ```
   git clone "https://gerrit.fd.io/r/vpp"
   ```
- Checkout commit ```a5cf6e077```.

- In case of any other build, please update probes to make compile-able if necessary.

Build:
--------------
### build with USDT probes

- Annotated code using SystemTap macros from patch 
   ```
   vpp-traceability.diff
   ```
- Rebuild vpp with annotated code

### start VPP

```
vpp -c startup.conf
```

### start VPP-BPF tooling and attach it to running VPP

```
python vpp_bpftrace.py -r 1 -p `pgrep vpp`
```
