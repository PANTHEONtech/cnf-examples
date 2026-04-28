#!/bin/bash
#
# test_multi_vlan_vxlan.sh — Multi-VLAN / Multi-VNI test (4 PCs, 2 routers)
#
# Topology:
#   VLAN 100 / VNI 1000: PC1 (10.100.1.1) on R1 <--> PC2 (10.100.1.2) on R2
#   VLAN 200 / VNI 2000: PC3 (10.200.1.1) on R1 <--> PC4 (10.200.1.2) on R2

set -u

LAB="sonic-vpp-multi-vni"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 -o LogLevel=ERROR"
ROUTER1="sshpass -p admin ssh $SSH_OPTS admin@clab-${LAB}-router1"
ROUTER2="sshpass -p admin ssh $SSH_OPTS admin@clab-${LAB}-router2"
PC1="sudo docker exec clab-${LAB}-PC1"
PC2="sudo docker exec clab-${LAB}-PC2"
PC3="sudo docker exec clab-${LAB}-PC3"
PC4="sudo docker exec clab-${LAB}-PC4"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}: $1"; }

header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_syncd() {
    local router_cmd="$1"
    local status
    status=$($router_cmd docker exec syncd supervisorctl status syncd 2>/dev/null || echo "FAILED")
    echo "$status" | grep -q "RUNNING"
}

ping_test() {
    local src_cmd="$1"
    local dst_ip="$2"
    local count="${3:-5}"
    $src_cmd ping -c "$count" -W 2 "$dst_ip" > /dev/null 2>&1
}

ping_test_retry() {
    local src_cmd="$1"
    local dst_ip="$2"
    local label="$3"
    local max_attempts="${4:-3}"
    local wait_secs="${5:-10}"

    for attempt in $(seq 1 "$max_attempts"); do
        if ping_test "$src_cmd" "$dst_ip" 5; then
            pass "$label (attempt $attempt)"
            return 0
        else
            if [ "$attempt" -lt "$max_attempts" ]; then
                echo "  Attempt $attempt failed, waiting ${wait_secs}s..."
                sleep "$wait_secs"
            fi
        fi
    done
    fail "$label (all $max_attempts attempts failed)"
    return 1
}

vpp_tunnel_count() {
    local router_cmd="$1"
    local count
    count=$(timeout 10 $router_cmd 'sudo docker exec syncd vppctl show vxlan tunnel' 2>/dev/null | grep -c "vni" || true)
    echo "$count"
}

# Full VXLAN teardown (reverse order: maps → evpn_nvo → tunnel)
full_vxlan_teardown() {
    local router_cmd="$1"
    $router_cmd sudo config vxlan map del vtep 100 1000 2>&1 || true
    $router_cmd sudo config vxlan map del vtep 200 2000 2>&1 || true
    sleep 2
    $router_cmd sudo config vxlan evpn_nvo del nvo 2>&1 || true
    sleep 1
    $router_cmd sudo config vxlan del vtep 2>&1 || true
}

# Full VXLAN setup (forward order: tunnel → evpn_nvo → maps)
full_vxlan_setup() {
    local router_cmd="$1"
    local vtep_ip="$2"
    $router_cmd sudo config vxlan add vtep "$vtep_ip"
    $router_cmd sudo config vxlan evpn_nvo add nvo vtep
    $router_cmd sudo config vxlan map add vtep 100 1000
    $router_cmd sudo config vxlan map add vtep 200 2000
}

# =========================================================================
header "PHASE 0: Pre-flight checks"
# =========================================================================

echo "Checking router accessibility..."
if $ROUTER1 echo "ok" > /dev/null 2>&1; then
    pass "Router1 SSH accessible"
else
    fail "Router1 SSH not accessible"; exit 1
fi
if $ROUTER2 echo "ok" > /dev/null 2>&1; then
    pass "Router2 SSH accessible"
else
    fail "Router2 SSH not accessible"; exit 1
fi

echo ""
echo "Checking syncd health..."
if check_syncd "$ROUTER1"; then pass "Router1 syncd RUNNING"; else fail "Router1 syncd NOT running"; fi
if check_syncd "$ROUTER2"; then pass "Router2 syncd RUNNING"; else fail "Router2 syncd NOT running"; fi

echo ""
echo "Checking BGP EVPN peering..."
BGP_STATE=$(timeout 10 $ROUTER1 "vtysh -c 'show bgp l2vpn evpn summary'" 2>/dev/null || echo "")
if echo "$BGP_STATE" | grep -q "10.0.1.0"; then
    pass "BGP EVPN neighbor 10.0.1.0 present on Router1"
else
    warn "Could not verify BGP EVPN neighbor (will be confirmed by ping tests)"
fi

echo ""
echo "Checking VXLAN VNI mappings..."
VNI_INFO=$(timeout 10 $ROUTER1 "vtysh -c 'show evpn vni'" 2>/dev/null || echo "")
echo "$VNI_INFO"
if echo "$VNI_INFO" | grep -q "1000"; then pass "VNI 1000 present"; else warn "VNI 1000 not visible"; fi
if echo "$VNI_INFO" | grep -q "2000"; then pass "VNI 2000 present"; else warn "VNI 2000 not visible"; fi

echo ""
echo "Checking VPP VXLAN tunnels..."
R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
R2_TUNNELS=$(vpp_tunnel_count "$ROUTER2")
if [ "$R1_TUNNELS" -ge 2 ]; then pass "R1 has $R1_TUNNELS VPP VXLAN tunnels"; else warn "R1 has $R1_TUNNELS tunnels (expected 2)"; fi
if [ "$R2_TUNNELS" -ge 2 ]; then pass "R2 has $R2_TUNNELS VPP VXLAN tunnels"; else warn "R2 has $R2_TUNNELS tunnels (expected 2)"; fi

# =========================================================================
header "PHASE 1: VNI 1000 connectivity (PC1 <-> PC2)"
# =========================================================================

echo "Testing PC1 (10.100.1.1) → PC2 (10.100.1.2)..."
ping_test_retry "$PC1" "10.100.1.2" "PC1 → PC2 (VNI 1000)"

echo ""
echo "Testing PC2 (10.100.1.2) → PC1 (10.100.1.1)..."
if ping_test "$PC2" "10.100.1.1" 3; then pass "PC2 → PC1 (VNI 1000)"; else fail "PC2 → PC1 (VNI 1000)"; fi

# =========================================================================
header "PHASE 2: VNI 2000 connectivity (PC3 <-> PC4)"
# =========================================================================

echo "Testing PC3 (10.200.1.1) → PC4 (10.200.1.2)..."
ping_test_retry "$PC3" "10.200.1.2" "PC3 → PC4 (VNI 2000)"

echo ""
echo "Testing PC4 (10.200.1.2) → PC3 (10.200.1.1)..."
if ping_test "$PC4" "10.200.1.1" 3; then pass "PC4 → PC3 (VNI 2000)"; else fail "PC4 → PC3 (VNI 2000)"; fi

# =========================================================================
header "PHASE 3: Cross-VNI isolation (remote)"
# =========================================================================

echo "PC1 (VNI 1000) → PC3 (VNI 2000) — should FAIL..."
if ping_test "$PC1" "10.200.1.1" 3; then fail "PC1 can reach PC3"; else pass "PC1 cannot reach PC3"; fi

echo ""
echo "PC1 (VNI 1000) → PC4 (VNI 2000) — should FAIL..."
if ping_test "$PC1" "10.200.1.2" 3; then fail "PC1 can reach PC4"; else pass "PC1 cannot reach PC4"; fi

echo ""
echo "PC3 (VNI 2000) → PC2 (VNI 1000) — should FAIL..."
if ping_test "$PC3" "10.100.1.2" 3; then fail "PC3 can reach PC2"; else pass "PC3 cannot reach PC2"; fi

echo ""
echo "PC4 (VNI 2000) → PC1 (VNI 1000) — should FAIL..."
if ping_test "$PC4" "10.100.1.1" 3; then fail "PC4 can reach PC1"; else pass "PC4 cannot reach PC1"; fi

# =========================================================================
header "PHASE 4: Same-router cross-VLAN isolation"
# =========================================================================

echo "PC1 and PC3 are both on Router1 but different VLANs..."
echo ""
echo "PC1 (R1, VNI 1000) → PC3 (R1, VNI 2000) — should FAIL..."
if ping_test "$PC1" "10.200.1.1" 3; then fail "Same-router leak: PC1 → PC3"; else pass "Same-router isolated: PC1 → PC3"; fi

echo ""
echo "PC3 (R1, VNI 2000) → PC1 (R1, VNI 1000) — should FAIL..."
if ping_test "$PC3" "10.100.1.1" 3; then fail "Same-router leak: PC3 → PC1"; else pass "Same-router isolated: PC3 → PC1"; fi

echo ""
echo "PC2 and PC4 are both on Router2 but different VLANs..."
echo ""
echo "PC2 (R2, VNI 1000) → PC4 (R2, VNI 2000) — should FAIL..."
if ping_test "$PC2" "10.200.1.2" 3; then fail "Same-router leak: PC2 → PC4"; else pass "Same-router isolated: PC2 → PC4"; fi

echo ""
echo "PC4 (R2, VNI 2000) → PC2 (R2, VNI 1000) — should FAIL..."
if ping_test "$PC4" "10.100.1.2" 3; then fail "Same-router leak: PC4 → PC2"; else pass "Same-router isolated: PC4 → PC2"; fi

# =========================================================================
header "PHASE 5: Delete VNI 2000 map — verify VNI 1000 unaffected"
# =========================================================================

echo "Deleting VXLAN map for VNI 2000 on both routers..."
$ROUTER1 sudo config vxlan map del vtep 200 2000 2>&1 || true
sleep 3
$ROUTER2 sudo config vxlan map del vtep 200 2000 2>&1 || true
sleep 5

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after VNI 2000 map delete"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after VNI 2000 map delete"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Verifying VNI 1000 still works (PC1 → PC2)..."
if ping_test "$PC1" "10.100.1.2" 5; then pass "VNI 1000 unaffected"; else fail "VNI 1000 broken"; fi

# =========================================================================
header "PHASE 6: Re-add VNI 2000 map — verify recovery"
# =========================================================================

echo "Re-adding VXLAN map for VNI 2000..."
$ROUTER1 sudo config vxlan map add vtep 200 2000
$ROUTER2 sudo config vxlan map add vtep 200 2000
sleep 5

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after VNI 2000 map re-add"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after VNI 2000 map re-add"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Waiting 15s for BGP EVPN re-convergence..."
sleep 15

ping_test_retry "$PC3" "10.200.1.2" "VNI 2000 recovered (PC3 → PC4)"

echo ""
if ping_test "$PC1" "10.100.1.2" 3; then pass "VNI 1000 still operational"; else fail "VNI 1000 broken"; fi

# =========================================================================
header "PHASE 7: Delete VNI 1000 map — verify VNI 2000 unaffected"
# =========================================================================

echo "Deleting VXLAN map for VNI 1000 on both routers..."
$ROUTER1 sudo config vxlan map del vtep 100 1000 2>&1 || true
sleep 3
$ROUTER2 sudo config vxlan map del vtep 100 1000 2>&1 || true
sleep 5

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after VNI 1000 map delete"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after VNI 1000 map delete"; else fail "R2 syncd CRASHED"; fi

echo ""
if ping_test "$PC3" "10.200.1.2" 5; then pass "VNI 2000 unaffected"; else fail "VNI 2000 broken"; fi

# =========================================================================
header "PHASE 8: Re-add VNI 1000 map — verify full recovery"
# =========================================================================

echo "Re-adding VXLAN map for VNI 1000..."
$ROUTER1 sudo config vxlan map add vtep 100 1000
$ROUTER2 sudo config vxlan map add vtep 100 1000
sleep 5

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after VNI 1000 map re-add"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after VNI 1000 map re-add"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Waiting 15s for BGP EVPN re-convergence..."
sleep 15

ping_test_retry "$PC1" "10.100.1.2" "VNI 1000 recovered (PC1 → PC2)"

echo ""
if ping_test "$PC3" "10.200.1.2" 3; then pass "VNI 2000 still operational"; else fail "VNI 2000 broken"; fi

# =========================================================================
header "PHASE 9: Full tunnel teardown and re-creation"
# =========================================================================

echo "Full teardown: del maps → del evpn_nvo → del tunnel..."
full_vxlan_teardown "$ROUTER1"
full_vxlan_teardown "$ROUTER2"
sleep 10

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after full teardown"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after full teardown"; else fail "R2 syncd CRASHED"; fi

echo ""
R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
if [ "$R1_TUNNELS" -eq 0 ]; then pass "R1 has 0 VPP tunnels after full teardown"; else warn "R1 has $R1_TUNNELS tunnels (expected 0)"; fi

echo ""
echo "Full setup: add tunnel → add evpn_nvo → add maps..."
full_vxlan_setup "$ROUTER1" "10.0.1.1"
full_vxlan_setup "$ROUTER2" "10.0.1.0"
sleep 5

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after full setup"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after full setup"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Waiting 20s for BGP EVPN to fully converge..."
sleep 20

R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
if [ "$R1_TUNNELS" -eq 2 ]; then pass "R1 has 2 VPP tunnels after full setup"; else warn "R1 has $R1_TUNNELS tunnels (expected 2)"; fi

echo ""
ping_test_retry "$PC1" "10.100.1.2" "VNI 1000 works after full cycle"
ping_test_retry "$PC3" "10.200.1.2" "VNI 2000 works after full cycle"

# =========================================================================
header "PHASE 10: Rapid map delete/re-add stress test"
# =========================================================================

STRESS_CYCLES=3
echo "Running $STRESS_CYCLES rapid map delete/re-add cycles on VNI 2000..."
echo ""

for cycle in $(seq 1 "$STRESS_CYCLES"); do
    echo "  Cycle $cycle/$STRESS_CYCLES: delete map..."
    $ROUTER1 sudo config vxlan map del vtep 200 2000 2>&1 || true
    $ROUTER2 sudo config vxlan map del vtep 200 2000 2>&1 || true
    sleep 3

    echo "  Cycle $cycle/$STRESS_CYCLES: re-add map..."
    $ROUTER1 sudo config vxlan map add vtep 200 2000
    $ROUTER2 sudo config vxlan map add vtep 200 2000
    sleep 3
done

sleep 15

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after $STRESS_CYCLES rapid cycles"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after $STRESS_CYCLES rapid cycles"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Verifying connectivity after stress test..."
ping_test_retry "$PC1" "10.100.1.2" "VNI 1000 works after stress test"
ping_test_retry "$PC3" "10.200.1.2" "VNI 2000 works after stress test"

# =========================================================================
header "PHASE 11: Simultaneous bidirectional traffic"
# =========================================================================

echo "Sending pings on both VNIs concurrently (10 packets each)..."
$PC1 ping -c 10 -W 2 10.100.1.2 > /dev/null 2>&1 &
PID1=$!
$PC2 ping -c 10 -W 2 10.100.1.1 > /dev/null 2>&1 &
PID2=$!
$PC3 ping -c 10 -W 2 10.200.1.2 > /dev/null 2>&1 &
PID3=$!
$PC4 ping -c 10 -W 2 10.200.1.1 > /dev/null 2>&1 &
PID4=$!

wait $PID1; R1=$?
wait $PID2; R2=$?
wait $PID3; R3=$?
wait $PID4; R4=$?
echo ""

if [ $R1 -eq 0 ]; then pass "Concurrent: PC1 → PC2 (VNI 1000)"; else fail "Concurrent: PC1 → PC2 (VNI 1000)"; fi
if [ $R2 -eq 0 ]; then pass "Concurrent: PC2 → PC1 (VNI 1000)"; else fail "Concurrent: PC2 → PC1 (VNI 1000)"; fi
if [ $R3 -eq 0 ]; then pass "Concurrent: PC3 → PC4 (VNI 2000)"; else fail "Concurrent: PC3 → PC4 (VNI 2000)"; fi
if [ $R4 -eq 0 ]; then pass "Concurrent: PC4 → PC3 (VNI 2000)"; else fail "Concurrent: PC4 → PC3 (VNI 2000)"; fi

# =========================================================================
header "PHASE 12: Final isolation re-check"
# =========================================================================

echo "Cross-VNI (remote)..."
if ping_test "$PC1" "10.200.1.2" 3; then fail "PC1 → PC4 leak"; else pass "PC1 → PC4 isolated"; fi
if ping_test "$PC3" "10.100.1.2" 3; then fail "PC3 → PC2 leak"; else pass "PC3 → PC2 isolated"; fi

echo ""
echo "Cross-VLAN same-router..."
if ping_test "$PC1" "10.200.1.1" 3; then fail "PC1 → PC3 same-router leak"; else pass "PC1 → PC3 same-router isolated"; fi
if ping_test "$PC2" "10.200.1.2" 3; then fail "PC2 → PC4 same-router leak"; else pass "PC2 → PC4 same-router isolated"; fi

# =========================================================================
header "PHASE 13: Log verification and final health"
# =========================================================================

echo "Checking for segfaults..."
for router_label in "Router1:$ROUTER1" "Router2:$ROUTER2"; do
    label="${router_label%%:*}"
    cmd="${router_label#*:}"
    SYSLOG=$(timeout 15 $cmd bash -c '{
        sudo docker logs syncd 2>&1
        grep -a "" /var/log/syslog /var/log/syslog.1 2>/dev/null
    } | grep -i "segfault\|SIGSEGV" | tail -5' 2>/dev/null || echo "")

    if [ -n "$SYSLOG" ] && echo "$SYSLOG" | grep -qi "segfault\|SIGSEGV"; then
        fail "SIGSEGV detected in $label logs!"
    else
        pass "No segfault in $label logs"
    fi
done

echo ""
echo "Final syncd health..."
if check_syncd "$ROUTER1"; then pass "R1 syncd healthy"; else fail "R1 syncd not healthy"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd healthy"; else fail "R2 syncd not healthy"; fi

# =========================================================================
header "TEST SUMMARY"
# =========================================================================

echo ""
echo -e "  ${GREEN}Passed${NC}: $PASS"
echo -e "  ${RED}Failed${NC}: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "  ${RED}SOME TESTS FAILED${NC} — check output above"
    exit 1
fi
