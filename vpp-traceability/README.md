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

- Clone VPP with eBPF tracing support
   ```
   git clone "https://gerrit.fd.io/r/vpp"
   git review -d 27945
   ```
Build:
--------------
### build with USDT probes

- Install SystemTap
   ```
   apt-get install systemtap-sdt-dev
   ```
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
