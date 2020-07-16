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
    u32 if_index;
};

struct hash_leaf_interface_info_t
{
    char if_name[32];
    u32  state;
    u32  thread_index;      // rx_placement
    u32  queue_id;          // rx_placement
    u32  queue_mode;
};

BPF_HASH(intfs_info, struct hash_key_t, struct hash_leaf_interface_info_t);

int vpp_intfs_state(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    bpf_usdt_readarg(1, ctx, &key.if_index);

    struct hash_leaf_interface_info_t zero = {};
    struct hash_leaf_interface_info_t* info = intfs_info.lookup_or_try_init(&key, &zero);
    if (0 == info) {
        return 0;
    }
    bpf_usdt_readarg(2, ctx, &info->state);
    bpf_usdt_readarg_p(3, ctx, &info->if_name, sizeof(info->if_name));

    return 0;
}

/**
 * @brief Reads VPP's stat counters, and stores them in the stats_counters hash.
 * @param ctx The BPF context.
 */
int vpp_intfs_rx_placement(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    bpf_usdt_readarg(1, ctx, &key.if_index);

    struct hash_leaf_interface_info_t zero = {};
    struct hash_leaf_interface_info_t* info = intfs_info.lookup_or_try_init(&key, &zero);
    if (0 == info) {
        return 0;
    }
    bpf_usdt_readarg(2, ctx, &info->thread_index);
    bpf_usdt_readarg(3, ctx, &info->queue_id);

    return 0;
};

/**
 * @brief Reads VPP's stat counters, and stores them in the stats_counters hash.
 * @param ctx The BPF context.
 */
int vpp_intfs_rx_mode(struct pt_regs *ctx) {
    struct hash_key_t key = {};
    bpf_usdt_readarg(1, ctx, &key.if_index);

    struct hash_leaf_interface_info_t zero = {};
    struct hash_leaf_interface_info_t* info = intfs_info.lookup_or_try_init(&key, &zero);
    if (0 == info) {
        return 0;
    }
    bpf_usdt_readarg(2, ctx, &info->queue_mode);

    return 0;
};
