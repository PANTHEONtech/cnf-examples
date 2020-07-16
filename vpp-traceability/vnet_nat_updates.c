/*
 * Copyright (c) 2020 Pantheon.tech and/or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/
#include <uapi/linux/ptrace.h>

struct data_t
{
    u8  operation;
    u32  thread_index;
    u32  fib_index;
    u32  protocol;
    u32  in2out_addr;
    u32  in2out_port;
    u32  out2in_addr;
    u32  out2in_port;
};

BPF_PERF_OUTPUT(nat_events);

/**
 * @brief Reads VPP's NAT updates, flush it using BPF perf event.
 * @param ctx The BPF context.
 *
 *  DTRACE_PROBE ...
 */
int vpp_nat_session_updates(struct pt_regs *ctx) {
    struct data_t data = { 0 };

    bpf_usdt_readarg(1, ctx, &data.operation);
    bpf_usdt_readarg(2, ctx, &data.thread_index);
    bpf_usdt_readarg(3, ctx, &data.fib_index);
    bpf_usdt_readarg(4, ctx, &data.protocol);
    bpf_usdt_readarg(5, ctx, &data.in2out_addr);
    bpf_usdt_readarg(6, ctx, &data.in2out_port);
    bpf_usdt_readarg(7, ctx, &data.out2in_addr);
    bpf_usdt_readarg(8, ctx, &data.out2in_port);

    nat_events.perf_submit(ctx, &data, sizeof(data));

    return 0;
};