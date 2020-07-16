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
    char name[16];
    u32 counter_index;
};

struct hash_leaf_simple_counter_t
{
    u64 total;
};

BPF_HASH(simple_counters, struct hash_key_t, struct hash_leaf_simple_counter_t, 16);

/**
 * @brief Reads VPP's simple counters, and stores them in the simple_counter hash.
 * @param ctx The BPF context.
 *
 */
int vpp_simple_counters(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    bpf_usdt_readarg_p(1, ctx, &key.name, sizeof(key.name));
    bpf_usdt_readarg(2, ctx, &key.counter_index);

    struct hash_leaf_simple_counter_t counter = {};
    bpf_usdt_readarg(3, ctx, &counter.total);

    bpf_trace_printk("%s[if_idx %d] : %d\n", key.name, key.counter_index, counter.total);

    simple_counters.update(&key, &counter);
    return 0;
};