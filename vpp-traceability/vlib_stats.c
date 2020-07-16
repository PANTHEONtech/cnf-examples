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

struct hash_key_t
{
    u32 node_index;
};

struct hash_leaf_stat_counter_t
{
    char node_name[32];
    u64 calls;          // Calls
    u64 vectors;        // Vectors
    u64 suspends;       // Suspends
    u64 clocksperx;     // Clocks
    u64 vectorspercall; // Vectors/Call
    u64 maxcn;          // Max Node Clocks
    u32 maxn;           // Vectors at Max
    u64 maxc;           // Max Clocks
};

BPF_HASH(stats_counters, struct hash_key_t, struct hash_leaf_stat_counter_t);

#define MAX_CORES 8

struct hash_key_vr_t
{
    u32 node_index;
};

struct hash_leaf_vr_counter_t
{
    u64 vectors;
    u64 calls;
};

BPF_HASH(vector_rate_counters, struct hash_key_vr_t, struct hash_leaf_vr_counter_t);

/**
 * @brief Reads VPP's stat counters, and stores them in the stats_counters hash.
 * @param ctx The BPF context.
 *
 *  DTRACE_PROBE ...
 */
int vpp_stats(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    bpf_usdt_readarg(2, ctx, &key.node_index);

    struct hash_leaf_stat_counter_t counter = {};
    bpf_usdt_readarg_p(1, ctx, &counter.node_name, sizeof(counter.node_name));
    bpf_usdt_readarg(3, ctx, &counter.calls);
    bpf_usdt_readarg(4, ctx, &counter.vectors);
    bpf_usdt_readarg(5, ctx, &counter.suspends);
    bpf_usdt_readarg(6, ctx, &counter.clocksperx);
    bpf_usdt_readarg(7, ctx, &counter.vectorspercall);
    bpf_usdt_readarg(8, ctx, &counter.maxcn);
    bpf_usdt_readarg(9, ctx, &counter.maxn);
    bpf_usdt_readarg(10, ctx, &counter.maxc);

    stats_counters.update(&key, &counter);
    return 0;
};

/**
 * @brief Reads VPP's vector rates, and stores them in the vector_rate_counters hash.
 * @param ctx The BPF context.
 *
 *  DTRACE_PROBE ...
 */
int vpp_vector_rate(struct pt_regs *ctx) {    
    struct hash_key_vr_t key = {};
    bpf_usdt_readarg(1, ctx, &key.node_index);

    struct hash_leaf_vr_counter_t counter = {};
    bpf_usdt_readarg(2, ctx, &counter.vectors);
    bpf_usdt_readarg(3, ctx, &counter.calls);

    vector_rate_counters.update(&key, &counter);

    return 0;
};