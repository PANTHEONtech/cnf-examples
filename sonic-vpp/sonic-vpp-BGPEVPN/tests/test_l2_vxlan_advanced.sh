#!/bin/bash
#
# test_l2_vxlan_advanced.sh — Advanced behavior tests for multi-VNI L2 VXLAN
#
# Covers:
#  - MAC learning over VXLAN (VPP L2 FIB + SONiC MAC table + FRR EVPN Type-2)
#  - BUM flooding (broadcast, ARP resolution over VXLAN)
#  - Dynamic VNI hot-add with concurrent traffic
#  - Scale test (5 VNIs simultaneously)
#  - Underlay link flap recovery
#  - Log verification

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
    $router_cmd docker exec syncd supervisorctl status syncd 2>/dev/null | grep -q "RUNNING"
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
            [ "$attempt" -lt "$max_attempts" ] && { echo "  Attempt $attempt failed, waiting ${wait_secs}s..."; sleep "$wait_secs"; }
        fi
    done
    fail "$label (all $max_attempts attempts failed)"
    return 1
}

vpp_tunnel_count() {
    local router_cmd="$1"
    timeout 10 $router_cmd 'sudo docker exec syncd vppctl show vxlan tunnel' 2>/dev/null | grep -c "vni" || echo 0
}

# =========================================================================
header "PHASE 0: Pre-flight — verify baseline connectivity"
# =========================================================================

echo "Verifying VNI 1000 (PC1 → PC2)..."
if ping_test "$PC1" "10.100.1.2" 5; then pass "VNI 1000 baseline OK"; else fail "VNI 1000 baseline broken — aborting"; exit 1; fi

echo "Verifying VNI 2000 (PC3 → PC4)..."
if ping_test "$PC3" "10.200.1.2" 5; then pass "VNI 2000 baseline OK"; else fail "VNI 2000 baseline broken — aborting"; exit 1; fi

# =========================================================================
header "PHASE 1: MAC learning over VXLAN"
# =========================================================================

echo "Generating traffic to trigger MAC learning..."
$PC1 ping -c 3 -W 2 10.100.1.2 > /dev/null 2>&1
$PC2 ping -c 3 -W 2 10.100.1.1 > /dev/null 2>&1
$PC3 ping -c 3 -W 2 10.200.1.2 > /dev/null 2>&1
$PC4 ping -c 3 -W 2 10.200.1.1 > /dev/null 2>&1
sleep 3

echo ""
echo "Checking VPP L2 FIB on Router1 for remote MACs..."
VPP_FIB_R1=$($ROUTER1 "sudo docker exec syncd vppctl show l2fib" 2>/dev/null || echo "")
if echo "$VPP_FIB_R1" | grep -qi "aa:aa:aa:aa:aa:02"; then
    pass "R1 learned PC2 MAC (aa:aa:aa:aa:aa:02) via VXLAN"
else
    warn "R1 did not learn PC2 MAC — may use flooding path"
fi
if echo "$VPP_FIB_R1" | grep -qi "bb:bb:bb:bb:bb:04"; then
    pass "R1 learned PC4 MAC (bb:bb:bb:bb:bb:04) via VXLAN"
else
    warn "R1 did not learn PC4 MAC — may use flooding path"
fi

echo ""
echo "Checking VPP L2 FIB on Router2 for remote MACs..."
VPP_FIB_R2=$($ROUTER2 "sudo docker exec syncd vppctl show l2fib" 2>/dev/null || echo "")
if echo "$VPP_FIB_R2" | grep -qi "aa:aa:aa:aa:aa:01"; then
    pass "R2 learned PC1 MAC (aa:aa:aa:aa:aa:01) via VXLAN"
else
    warn "R2 did not learn PC1 MAC"
fi
if echo "$VPP_FIB_R2" | grep -qi "bb:bb:bb:bb:bb:03"; then
    pass "R2 learned PC3 MAC (bb:bb:bb:bb:bb:03) via VXLAN"
else
    warn "R2 did not learn PC3 MAC"
fi

echo ""
echo "Checking SONiC MAC table on Router1..."
$ROUTER1 "show mac 2>/dev/null | head -20" || true

echo ""
echo "Checking FRR EVPN MAC info on Router1..."
$ROUTER1 "vtysh -c 'show evpn mac vni all' 2>/dev/null | head -30" || true

# =========================================================================
header "PHASE 2: BUM flooding — broadcast and ARP"
# =========================================================================

echo "Testing ARP resolution over VXLAN (PC1 → PC2)..."
$PC1 ip neigh flush all 2>/dev/null || true
$PC2 ip neigh flush all 2>/dev/null || true
sleep 2

if ping_test "$PC1" "10.100.1.2" 3; then pass "ARP resolution works over VXLAN (VNI 1000)"; else fail "ARP resolution failed"; fi

echo ""
echo "Verifying ARP entry was re-learned..."
ARP_ENTRY=$($PC1 ip neigh show 10.100.1.2 2>/dev/null || echo "")
if echo "$ARP_ENTRY" | grep -qi "aa:aa:aa:aa:aa:02"; then
    pass "PC1 re-learned PC2 MAC via ARP over VXLAN"
else
    warn "PC1 ARP entry unclear: $ARP_ENTRY"
fi

echo ""
echo "Testing ARP resolution on VNI 2000 (PC3 → PC4)..."
$PC3 ip neigh flush all 2>/dev/null || true
sleep 1
if ping_test "$PC3" "10.200.1.2" 3; then pass "ARP resolution works over VXLAN (VNI 2000)"; else fail "ARP resolution failed"; fi

# =========================================================================
header "PHASE 3: Add 3rd VNI while traffic flows"
# =========================================================================

echo "Starting background traffic on VNI 1000 and VNI 2000..."
$PC1 ping -c 60 -i 0.5 -W 2 10.100.1.2 > /tmp/vni1000_bg.log 2>&1 &
BG1=$!
$PC3 ping -c 60 -i 0.5 -W 2 10.200.1.2 > /tmp/vni2000_bg.log 2>&1 &
BG2=$!

echo "Adding VLAN 300 and VNI 3000 on both routers while traffic flows..."
$ROUTER1 sudo config vlan add 300 2>&1 || true
$ROUTER2 sudo config vlan add 300 2>&1 || true
sleep 2
$ROUTER1 sudo config vxlan map add vtep 300 3000
$ROUTER2 sudo config vxlan map add vtep 300 3000
sleep 10

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING after adding VNI 3000"; else fail "R1 syncd CRASHED"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING after adding VNI 3000"; else fail "R2 syncd CRASHED"; fi

echo ""
echo "Checking VNI 3000 appears in EVPN..."
VNI_INFO=$($ROUTER1 "vtysh -c 'show evpn vni'" 2>/dev/null || echo "")
if echo "$VNI_INFO" | grep -q "3000"; then pass "VNI 3000 present in EVPN"; else warn "VNI 3000 not yet visible in EVPN"; fi

echo ""
R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
echo "R1 VPP tunnel count: $R1_TUNNELS"
if [ "$R1_TUNNELS" -ge 3 ]; then pass "R1 has $R1_TUNNELS VPP tunnels (expected ≥3)"; else warn "R1 has $R1_TUNNELS tunnels (expected ≥3 with VNI 3000)"; fi

echo ""
echo "Waiting for background traffic to finish..."
wait $BG1; R1_LOSS=$?
wait $BG2; R2_LOSS=$?

if [ $R1_LOSS -eq 0 ]; then pass "VNI 1000 traffic uninterrupted during VNI 3000 add"; else warn "VNI 1000 had some loss during hot-add (exit=$R1_LOSS)"; fi
if [ $R2_LOSS -eq 0 ]; then pass "VNI 2000 traffic uninterrupted during VNI 3000 add"; else warn "VNI 2000 had some loss during hot-add (exit=$R2_LOSS)"; fi

echo ""
echo "Cleaning up VNI 3000..."
$ROUTER1 sudo config vxlan map del vtep 300 3000 2>&1 || true
$ROUTER2 sudo config vxlan map del vtep 300 3000 2>&1 || true
sleep 2
$ROUTER1 sudo config vlan del 300 2>&1 || true
$ROUTER2 sudo config vlan del 300 2>&1 || true
sleep 5

echo "Verifying original VNIs still work after cleanup..."
if ping_test "$PC1" "10.100.1.2" 3; then pass "VNI 1000 OK after VNI 3000 cleanup"; else fail "VNI 1000 broken"; fi
if ping_test "$PC3" "10.200.1.2" 3; then pass "VNI 2000 OK after VNI 3000 cleanup"; else fail "VNI 2000 broken"; fi

# =========================================================================
header "PHASE 4: Scale — 5 VNIs simultaneously"
# =========================================================================

echo "Adding VNIs 3000, 4000, 5000 (VLANs 300, 400, 500)..."
for vlan_vni in "300:3000" "400:4000" "500:5000"; do
    vlan="${vlan_vni%%:*}"
    vni="${vlan_vni##*:}"
    $ROUTER1 sudo config vlan add $vlan 2>&1 || true
    $ROUTER2 sudo config vlan add $vlan 2>&1 || true
    $ROUTER1 sudo config vxlan map add vtep $vlan $vni 2>&1 || true
    $ROUTER2 sudo config vxlan map add vtep $vlan $vni 2>&1 || true
done
sleep 15

if check_syncd "$ROUTER1"; then pass "R1 syncd RUNNING with 5 VNIs"; else fail "R1 syncd CRASHED with 5 VNIs"; fi
if check_syncd "$ROUTER2"; then pass "R2 syncd RUNNING with 5 VNIs"; else fail "R2 syncd CRASHED with 5 VNIs"; fi

echo ""
R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
R2_TUNNELS=$(vpp_tunnel_count "$ROUTER2")
if [ "$R1_TUNNELS" -ge 5 ]; then pass "R1 has $R1_TUNNELS VPP tunnels (5 VNIs)"; else warn "R1 has $R1_TUNNELS tunnels (expected ≥5)"; fi
if [ "$R2_TUNNELS" -ge 5 ]; then pass "R2 has $R2_TUNNELS VPP tunnels (5 VNIs)"; else warn "R2 has $R2_TUNNELS tunnels (expected ≥5)"; fi

echo ""
echo "Verifying original VNIs still work with 5 VNIs active..."
if ping_test "$PC1" "10.100.1.2" 3; then pass "VNI 1000 OK with 5 VNIs"; else fail "VNI 1000 broken"; fi
if ping_test "$PC3" "10.200.1.2" 3; then pass "VNI 2000 OK with 5 VNIs"; else fail "VNI 2000 broken"; fi

echo ""
echo "Cleaning up extra VNIs..."
for vlan_vni in "300:3000" "400:4000" "500:5000"; do
    vlan="${vlan_vni%%:*}"
    vni="${vlan_vni##*:}"
    $ROUTER1 sudo config vxlan map del vtep $vlan $vni 2>&1 || true
    $ROUTER2 sudo config vxlan map del vtep $vlan $vni 2>&1 || true
    $ROUTER1 sudo config vlan del $vlan 2>&1 || true
    $ROUTER2 sudo config vlan del $vlan 2>&1 || true
done
sleep 10

R1_TUNNELS=$(vpp_tunnel_count "$ROUTER1")
echo "R1 tunnel count after cleanup: $R1_TUNNELS"
if ping_test "$PC1" "10.100.1.2" 3; then pass "VNI 1000 OK after scale cleanup"; else fail "VNI 1000 broken"; fi
if ping_test "$PC3" "10.200.1.2" 3; then pass "VNI 2000 OK after scale cleanup"; else fail "VNI 2000 broken"; fi

# =========================================================================
header "PHASE 5: Underlay link flap recovery"
# =========================================================================

echo "Shutting down underlay interface Ethernet0 on Router1..."
$ROUTER1 sudo config interface shutdown Ethernet0
sleep 5

echo "Verifying VXLAN traffic fails during underlay outage..."
if ping_test "$PC1" "10.100.1.2" 3; then
    warn "VNI 1000 still works with underlay down (unexpected)"
else
    pass "VNI 1000 correctly unreachable with underlay down"
fi

echo ""
echo "Bringing underlay back up..."
$ROUTER1 sudo config interface startup Ethernet0
echo "Waiting 20s for BGP EVPN to re-converge..."
sleep 20

echo "Verifying VXLAN traffic recovers..."
ping_test_retry "$PC1" "10.100.1.2" "VNI 1000 recovered after underlay flap"
ping_test_retry "$PC3" "10.200.1.2" "VNI 2000 recovered after underlay flap"

# =========================================================================
header "PHASE 6: Log verification and final health"
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
