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
//    char name[16];
    u32 counter_index;
};

struct hash_leaf_combined_counter_t
{
    u64 packets;
    u64 bytes;
};

BPF_HASH(combined_counters, u32, struct hash_leaf_combined_counter_t, 16);

/**
 * @brief Reads VPP's combined counters, and stores them in the combined_counter hash.
 * @param ctx The BPF context.
 *
 * DTRACE_PROBE ...
 */
int vpp_combined_counters(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    // bpf_usdt_readarg_p(1, ctx, &key.name, sizeof(key.name));
    // bpf_usdt_readarg(2, ctx, &key.counter_index);

    bpf_usdt_readarg(1, ctx, &key.counter_index);

    struct hash_leaf_combined_counter_t counter = {};
    // bpf_usdt_readarg(3, ctx, &counter.packets);
    // bpf_usdt_readarg(4, ctx, &counter.bytes);

    bpf_usdt_readarg(2, ctx, &counter.packets);

//    bpf_trace_printk("[%d] : %d\\n", key, counter.packets);
    bpf_trace_printk("%d : %d\\n", counter.packets, counter.bytes);

//    combined_counters.update(&key, &counter);
    return 0;
};