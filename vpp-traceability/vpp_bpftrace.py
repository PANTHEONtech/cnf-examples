#!/usr/bin/python
#
# Trace VPP BPF tooling to display output from BPF probes.
#
# Copyright 2020 GitHub, Inc.
# Copyright 2020 Pantheon.tech and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");

from __future__ import print_function
import argparse
import curses
import inspect
import ipaddress
import logging
import os
import sys
import subprocess
from bcc import BPF, USDT
from decimal import Decimal
from multiprocessing import Process
from select import select
from struct import *
from time import sleep, strftime

Config = {}
VppBpfProbes = {}
VppBpfPerfProbes = {}
USDT_ctx = {}

def bpf_tracing2curses(stdscr, vpp_bpf_probes):
    global Config

    def render_header(stdscr, line, header, col=0):
        stdscr.attron(curses.color_pair(2))
        stdscr.attron(curses.A_BOLD)
        stdscr.addstr(line, col, header)
        stdscr.addstr(line+1, col, "=" * len(header))
        stdscr.attroff(curses.color_pair(2))
        stdscr.attroff(curses.A_BOLD)

    # Clear and refresh the screen for a blank canvas
    stdscr.clear()
    stdscr.refresh()

    auto_refresh = True
    key = 0

    # Start colors in curses
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_BLUE, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_BLACK, curses.COLOR_WHITE)
    curses.init_pair(4, curses.COLOR_MAGENTA, curses.COLOR_BLACK)

    titlestr = "VPP BPFtrace tooling"
    header_simple_counters = "{:<11} | {:<32} | {:^15}".format("SW-if-index", "Counter name", "Count")
    header_error_counters = "{:<11} | {:<32} | {:^15}".format("Error-idx", "Counter name", "Count")
    header_stats = "{:^32} | {:^8}|{:^8}|{:^8}|{:^8}|{:^8}|{:^8}|{:^8}|{:^8}".format("Node name (with Calls > 0)", "Calls", "Vectors", "Suspends", "Clocks", "Vcts/Cls", "MxNodCls", "VctsAtMx", "MxClocks")
    header_intfs_info = "{:<46} | {:^5} | {:^7}".format("SW-if-index [if-name]", "State", "Core ID")
    header_vector_rates = "{:^9} | {:^7} | {:^7} | {:^32}".format("Core ID", "Calls", "Vectors", "Internal node vector rate")
    height, width = stdscr.getmaxyx()

    while (key != ord('q')):
        # Initialization
        stdscr.clear()
        line = 0

        simple_counters = vpp_bpf_probes["InterfaceCounters"].get_table("simple_counters") if (vpp_bpf_probes.get("InterfaceCounters") != None) else None
        error_counters = vpp_bpf_probes["ErrorCounters"].get_table("error_counters") if (vpp_bpf_probes.get("ErrorCounters") != None) else None
        stats_counters = vpp_bpf_probes["NodeStatistics"].get_table("stats_counters") if (vpp_bpf_probes.get("NodeStatistics") != None) else None
        intfs_info = vpp_bpf_probes["InterfacesInfo"].get_table("intfs_info") if (vpp_bpf_probes.get("InterfacesInfo") != None) else None
        vector_rate_counters = vpp_bpf_probes["NodeStatistics"].get_table("vector_rate_counters") if (vpp_bpf_probes.get("NodeStatistics") != None) else None

        # Render status bar
        refreshstr = "Auto {:2} s".format(Config["refresh_interval"]) if auto_refresh else "Manual"
        statusbarstr = " STATUS BAR | Attached to pid {} | Refresh : {:>9} | Press 'q' to exit, 'r' to refresh, 'a' for auto-refresh".format(Config["pid"], refreshstr)
        stdscr.attron(curses.color_pair(3))
        stdscr.addstr(height-1, 0, statusbarstr)
        stdscr.addstr(height-1, len(statusbarstr), " " * (width - len(statusbarstr) - 1))
        stdscr.attroff(curses.color_pair(3))

        # Render title bar
        stdscr.attron(curses.color_pair(4))
        stdscr.attron(curses.A_BOLD)
        col = int((width // 2) - (len(titlestr) // 2) - len(titlestr) % 2)
        stdscr.addstr(line, col, titlestr)
        stdscr.attroff(curses.color_pair(4))
        stdscr.attroff(curses.A_BOLD)

        # Render splitters
        stdscr.attron(curses.color_pair(2))
        stdscr.attron(curses.A_BOLD)
        for l in range(line+2, height-Config["log_height"]-3): stdscr.addstr(l, 68, "|")
        for c in range(0, width): stdscr.addstr(height-Config["log_height"]-4, c, "-")
        stdscr.attroff(curses.color_pair(2))
        stdscr.attroff(curses.A_BOLD)

        if stats_counters != None:
            # Render stat header
            render_header(stdscr, line+2, header_stats, col=70)
            # Rendering stat probes output
            l = line+4
            for k, v in sorted(stats_counters.items(), key=lambda kv: kv[1].node_name):
                if l == height-Config["log_height"]-5:
                    stdscr.addstr(l, 70, "...")
                    break
                if v.calls > 0:
                    item = "{:<32} | {:1.2E} {:1.2E} {:1.2E} {:1.2E} {:1.2E} {:1.2E} {:1.2E} {:1.2E}". \
                        format(v.node_name, v.calls, v.vectors, \
                        v.suspends, v.clocksperx, v.vectorspercall, \
                        v.maxcn, v.maxn, v.maxc)
                        #v.clocksperx, v.vectorspercall, v.maxcn, v.maxn, v.maxc)
                    stdscr.addstr(l, 70, item)
                    l += 1
                    if l>60:
                        break;

        if vector_rate_counters != None:
            # Render vector rate header
            line += 2
            render_header(stdscr, line, header_vector_rates)
            # Rendering vector rate output
            line += 2
            for k, v in vector_rate_counters.items():
                item = "{:^9} | {:^7} | {:^7} | {:^30.02E}".format(k.node_index, v.calls, v.vectors, \
                    v.vectors/v.calls if v.calls>0 else 0)
                stdscr.addstr(line, 0, item)
                line += 1

        if simple_counters != None:
            # Header simple counters
            line += 2
            render_header(stdscr, line, header_simple_counters)

            # Rendering simple counter probes output
            line += 2
            for k, v in simple_counters.items():
                item = "{:^11} | {:<32} | {:^15}".format(k.counter_index, k.name, v.total)
                stdscr.addstr(line, 0, item)
                line += 1

        if error_counters != None:
            # Header error counters
            line += 1
            render_header(stdscr, line, header_error_counters)

            # Rendering error counter probes output
            line += 2
            for k, v in error_counters.items():
                item = "{:^11} | {:<32} | {:^15}".format(k.counter_index, k.name, v.total)
                stdscr.addstr(line, 0, item)
                line += 1

        if intfs_info != None:
            # Header interfaces info
            line += 1
            render_header(stdscr, line, header_intfs_info)

            # Rendering interface info output
            line += 2
            for k, v in intfs_info.items():
                item = "{:>3} {:<42} | {:^5} | {:^7}".format(k.if_index,"["+v.if_name+"]", Config["if_s"][v.state], v.thread_index)
                stdscr.addstr(line, 0, item)
                line += 1

        # Render last Config["log_height"] lines from FILE_LOG
        line = height - Config["log_height"] - 2
        p = subprocess.Popen(['tail','-n',str(Config["log_height"]),Config["log_file"]], stdout=subprocess.PIPE)
        soutput, sinput = p.communicate()
        for msg in soutput.split('\n'):
            stdscr.addstr(line, 0, msg)
            line += 1
            
        # Set cursor position
        stdscr.move(height-1, 0)
        # Refresh the screen
        stdscr.refresh()

        # Wait for next input
        key = ord('a') if auto_refresh else 0
        while (key == 0 or key == ord('a')):
            rlist, wlist, xlist = select([sys.stdin], [], [], Config["refresh_interval"])
            if rlist:
                key = stdscr.getch()
                if key == ord('a'):
                    auto_refresh = True
                    break
                elif key == ord('q'):
                    break
                elif key == ord('r') or key == ord('m'):
                    auto_refresh = False
                    break
            else:
                if auto_refresh:
                    break
                key = 0

# Callbacks fot performace loggers

def log_nbh_event(cpu, data, size):
    global Config, VppBpfProbes

    nbh_updates = VppBpfProbes["NbhUpdates"] if (VppBpfProbes.get("NbhUpdates") != None) else None

    event = nbh_updates["nbh_events"].event(data)

    ip_bytes = bytearray()
    for b in event.ip_address[0:Config["ip_len"][event.is_ipv6]]: ip_bytes.append (b)

    item_fmt = "{:<24} | {:6} | {:3} | {:36} | {:<17} | {:^12}" if event.is_ipv6 else "{:<24} | {:6} | {:3} | {:15} | {:<17} | {:^12}"
    item = item_fmt. \
        format("vnet_ip_neighbor_probe", event.sw_if_index, Config["mode_s"][event.is_del], \
        ipaddress.ip_address(bytes(ip_bytes)), \
        ':'.join('%02x' % b for b in event.mac_address), \
        Config["nbh_fl_s"][event.flags])

    logging.info(item)

def log_ip_event(cpu, data, size):
    global Config, VppBpfProbes
    ip_updates = VppBpfProbes["IpUpdates"] if (VppBpfProbes.get("IpUpdates") != None) else None

    event = ip_updates["ip_events"].event(data)

    ip_bytes = bytearray()
    for b in event.ip_address[0:Config["ip_len"][event.is_ipv6]]: ip_bytes.append (b)

    item = "{:<24} | {:6} | {:3} | {:3} | {:<128}".\
        format("vnet_ip_address_probe", event.sw_if_index, Config["mode_s"][event.is_del], Config["ip_s"][event.is_ipv6], \
            "{}/{}".format(ipaddress.ip_address(bytes(ip_bytes)), event.address_length))

    logging.info(item)

def log_route_event(cpu, data, size):
    global Config, VppBpfProbes
    route_updates = VppBpfProbes["RouteUpdates"] if (VppBpfProbes.get("RouteUpdates") != None) else None
    
    event = route_updates["route_events"].event(data)

    path_ip_bytes = bytearray()
    route_ip_bytes = bytearray()
    for b in event.path[0:Config["ip_len"][event.is_ipv6]]: path_ip_bytes.append (b)
    for b in event.route[0:Config["ip_len"][event.is_ipv6]]: route_ip_bytes.append (b)
    
    item_fmt = "{:<24} | {:6} | {:3} | {:36} | {:32}" if event.is_ipv6 else "{:<24} | {:6} | {:3} | {:20} | {:15}"
    item = item_fmt.format("vnet_ip_route_probe", event.fib_index, Config["mode_s"][event.is_del], \
            "{}/{}".format(ipaddress.ip_address(bytes(path_ip_bytes)), event.path_len), \
            ipaddress.ip_address(bytes(route_ip_bytes)))

    logging.info(item)

def log_nat_event(cpu, data, size):
    global Config, VppBpfProbes
    nat_updates = VppBpfProbes["NatUpdates"] if (VppBpfProbes.get("NatUpdates") != None) else None

    event = nat_updates["nat_events"].event(data)
    item = "{:24} | {:6} | {:3} | {:3} | {:3} | {:>15}:{:<5} | {:>15}:{:<5}".\
        format("vnet_nat_session_update", event.thread_index, \
            Config["nat_op_s"][event.operation], \
            event.fib_index, event.protocol, \
            ipaddress.ip_address(event.in2out_addr), event.in2out_port, \
            ipaddress.ip_address(event.out2in_addr), event.out2in_port)

    logging.info(item)

ProbesWrapper = {
    "InterfaceCounters" : {
        "perf": False,
        "bcc": "vlib_simple_counters.c",
        "probes": ["vlib_increment_simple_counters_probe"],
        "probes_fn": ["vpp_simple_counters"]},
   "ErrorCounters" : {
        "perf": False,
        "bcc": "vlib_error_counters.c",
        "probes": ["vlib_error_count_probe"],
        "probes_fn": ["vpp_error_counters"]},
    "NodeStatistics" : {
        "perf": False,
        "bcc": "vlib_stats.c",
        "probes": ["vlib_node_runtime_sync_stats_probe", "vlib_vector_rate_probe"],
        "probes_fn": ["vpp_stats", "vpp_vector_rate"]},
    "InterfacesInfo" : {
        "perf": False,
        "bcc": "vnet_interfaces.c",
        "probes": ["vnet_sw_interface_state_probe","vnet_set_hw_interface_rx_placement_probe","vnet_hw_interface_set_rx_mode_probe"],
        "probes_fn": ["vpp_intfs_state","vpp_intfs_rx_placement","vpp_intfs_rx_mode"]},
    "NbhUpdates": {
        "perf": True,
        "bcc": "vnet_neighbor_updates.c",
        "probes": ["vnet_ip_neighbor_probe"], 
        "probes_fn": ["vpp_nbh_updates"],
        "events": "nbh_events",
        "callback": log_nbh_event},
    "IpUpdates": {
        "perf": True,
        "bcc": "vnet_ip_updates.c",
        "probes": ["vnet_ip_address_probe"],
        "probes_fn": ["vpp_ip_updates"],
        "events": "ip_events",
        "callback": log_ip_event},
    "RouteUpdates": {
        "perf": True,
        "bcc": "vnet_route_updates.c",
        "probes": ["vnet_ip_route_probe"], 
        "probes_fn": ["vpp_route_updates"],
        "events": "route_events",
        "callback": log_route_event},
    "NatUpdates": {
        "perf": True,
        "bcc": "vnet_nat_updates.c",
        "probes": ["vnet_nat_session_update_probe"], 
        "probes_fn": ["vpp_nat_session_updates"],
        "events": "nat_events",
        "callback": log_nat_event},
}

# Performance loggers

def bpf_tracing2log(vpp_bpf_probe, event_table, *args):
    global VppBpfProbes

    updates = VppBpfProbes[vpp_bpf_probe] if (VppBpfProbes.get(vpp_bpf_probe) != None) else None
    if updates != None:
        updates[event_table].open_perf_buffer(*args, page_cnt=64)
        while 1:
            updates.perf_buffer_poll()

def create_usdt(probe, ctx):
    global Config, ProbesWrapper

    probe_config = ProbesWrapper[probe]

    os_path = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
    bpf_code = open("%s/%s" % (os_path, probe_config["bcc"]), 'r').read()
    for p, f in zip(probe_config["probes"], probe_config["probes_fn"]):
        ctx.enable_probe( p, f)
    VppBpfProbes[probe] = BPF(text=bpf_code, usdt_contexts=[ctx], debug=Config["debugLevel"])

def create_bpf_tracer(probe):
    global ProbesWrapper

    probe_config = ProbesWrapper[probe]

    VppBpfPerfProbes[probe] = Process(target=bpf_tracing2log, 
        args=(probe, probe_config["events"], probe_config["callback"]))

def main():
    global Config

    Config["bcc_path"] = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
    Config["refresh_interval"] = 10
    Config["debugLevel"] = 0
    Config["log_file"] = Config["bcc_path"] + "/vpp_bpf_tracer.log"
    Config["log_height"] = 15

    Config["if_s"] = { 0: 'DOWN', 1: 'UP' }
    Config["mode_s"] = { 0: 'ADD', 1: 'DEL' }
    Config["ip_s"] = { 0: 'IP4', 1: 'IP6'}
    Config["nat_op_s"] = { 0: 'CRE', 1: 'UPD', 2: 'DEL' }
    Config["nbh_fl_s"] = { 1: 'STATIC', 2: 'DYNAMIC', 4: 'NO_FIB_ENTRY', 8: 'PENDING', 16: 'STALE' }
    Config["ip_len"] = { 0: 4, 1: 16 }

    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Trace VPP interface's counters.", formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-p", "--pid", type=int, help="The id of the VPP process to trace.")
    parser.add_argument("-r", "--refresh", dest="refresh_interval", type=int, help="Time interval for auto refresh")
    parser.add_argument("-l", "--log_height", dest="log_height", type=int, help="Height, in lines, of log part of window")
    parser.add_argument("-v", "--verbose", dest="verbose", action="store_true", help="If true, will output verbose logging information.")
    parser.set_defaults(verbose=False)
    args = parser.parse_args()

    # Monitored process ID
    Config["pid"] = int(args.pid)
    # Refresh rate
    if args.refresh_interval:
        Config["refresh_interval"] = int(args.refresh_interval)
    if args.log_height:
        Config["log_height"] = int(args.log_height)
    # Debug level
    if args.verbose:
        Config["debugLevel"]=4

    print("Attaching probes to pid %d ..." % Config["pid"])

    if os.path.exists(Config["log_file"]):
        os.remove(Config["log_file"])
    logging.basicConfig(level=logging.DEBUG, filename=Config["log_file"],
        filemode="a+", format="%(asctime)-15s %(levelname)-8s %(message)s")

    # Create USDT contexts
    usdt_ctx_simple = USDT(pid=Config["pid"])
    usdt_ctx_error = USDT(pid=Config["pid"])
    usdt_ctx_stats = USDT(pid=Config["pid"])
    usdt_ctx_intfs = USDT(pid=Config["pid"])
    usdt_ctx_nbh = USDT(pid=Config["pid"])
    usdt_ctx_ip = USDT(pid=Config["pid"])
    usdt_ctx_route = USDT(pid=Config["pid"])
    usdt_ctx_nat = USDT(pid=Config["pid"])

    create_usdt("InterfaceCounters", usdt_ctx_simple)
    create_usdt("ErrorCounters", usdt_ctx_error)
    create_usdt("NodeStatistics", usdt_ctx_stats)
    create_usdt("InterfacesInfo", usdt_ctx_intfs)
    create_usdt("NbhUpdates", usdt_ctx_nbh)
    create_usdt("IpUpdates", usdt_ctx_ip)
    create_usdt("RouteUpdates", usdt_ctx_route)
    create_usdt("NatUpdates", usdt_ctx_nat)

    for k, v in ProbesWrapper.items():
        if (v["perf"]):
            create_bpf_tracer(k)

    # Start tracing
    for v in VppBpfPerfProbes.itervalues():
        v.start()
    curses.wrapper(bpf_tracing2curses, VppBpfProbes)

    # Stop tracing
    for v in VppBpfPerfProbes.itervalues():
        v.terminate()

    print("Closing probes ...")

if __name__ == "__main__":
    main()