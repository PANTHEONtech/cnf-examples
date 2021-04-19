#!/usr/bin/env bash

set -euo pipefail

# Topology
TEST_ALPINE_IMAGE_TAG="alpine-start-end-point"
CNF_CONTAINER_NAME="firewall-cnf" # dependent on docker-compose.yml
STARTPOINT_VETH_IP="10.11.1.1"
STARTPOINT_VETH_MAC_ADDRESS="66:66:66:66:66:66"
STARTPOINT_VETH_HOST_IP="10.11.1.2"
ENDPOINT_VETH_HOST_IP="10.11.2.1"
ENDPOINT_VETH_IP="10.11.2.2"
NAME_OF_DEFAULT_NETWORK="onap-cdnf-integration_default" # dependent on parent directory name
NAME_OF_CDS_NETWORK="onap-cdnf-integration_cds-network" # dependent on parent directory name and docker-compose.yml

# Test traffic
TRAFFIC_DEST_IP="10.12.0.1"
TRAFFIC_DEST_NETWORK="10.12.0.0/24"
PORT="9000"


function preDockerComposeCNFPreparations() {
  # clean up reporting directory from previous reports
  refreshReportingDir

  # create (if not exists) docker image for startpoint and endpoint containers
  assertStartEndPointDockerImage

  # prepare directories for veth moving
  sudo mkdir -p /var/run/netns

  # clean up previous run if needed
  sudo rm -f /var/run/netns/startpoint
  sudo rm -f /var/run/netns/endpoint
}

function setupCNFTrafficTopology() {
  setupVPPPacketPath
  setupLoopForIPAddress "endpoint" ${TRAFFIC_DEST_IP} # used as ping destination
}

function refreshReportingDir() {
    rm -rf reports;mkdir -p reports; # for demo report output
}

function reportCNFState {
    docker logs ${CNF_CONTAINER_NAME} &> reports/cnf-log.txt
    logVPPACLConfig
    logVPPTrace "from-demo-exit"
}

function cleanupCNFRelatedThings {
    sudo rm -f /var/run/netns/startpoint
    sudo rm -f /var/run/netns/endpoint
}

function setupVPPPacketPath() {
    ENDPOINT_IP=$(docker inspect endpoint --format='{{ (index .NetworkSettings.Networks "'${NAME_OF_DEFAULT_NETWORK}'").IPAddress}}')
    STARTPOINT_IP=$(docker inspect startpoint --format='{{ (index .NetworkSettings.Networks "'${NAME_OF_DEFAULT_NETWORK}'").IPAddress}}')
    CNF_IP=$(docker inspect ${CNF_CONTAINER_NAME} --format='{{ (index .NetworkSettings.Networks "'${NAME_OF_CDS_NETWORK}'").IPAddress}}')

    echo "Running setup for packet path..."
    echo "--creating file reference of startpoint container namespace..."
    mkdir -p /tmp/netns
    startpoint_pid=`docker inspect -f '{{.State.Pid}}' startpoint`
    sudo ln -s /proc/$startpoint_pid/ns/net /var/run/netns/startpoint

    echo "--creating file reference of endpoint container namespace..."
    endpoint_pid=`docker inspect -f '{{.State.Pid}}' endpoint`
    sudo ln -s /proc/$endpoint_pid/ns/net /var/run/netns/endpoint

    echo "--creating veth tunnel from startpoint container to VPP in \"CNF\" container...(2 veth tunnels and routes needed in vpp)"
    curl --location --request PUT 'http://'${CNF_IP}':9191/configuration' \
        --header 'Content-Type: text/plain' \
        --data-raw 'netallocConfig: {}
linuxConfig:
  interfaces:
  - name: vpptoLinuxVETH
    type: VETH
    hostIfName: veth3
    enabled: true
    veth:
      peerIfName: endpointVETH
  - name: startpointVETH
    type: VETH
    namespace:
      type: FD
      reference: /var/run/netns/startpoint
    hostIfName: veth1
    enabled: true
    ipAddresses:
    - '${STARTPOINT_VETH_IP}'/24
    physAddress: '${STARTPOINT_VETH_MAC_ADDRESS}'
    veth:
      peerIfName: startpointToLinuxVETH
  - name: endpointVETH
    type: VETH
    namespace:
      type: FD
      reference: /var/run/netns/endpoint
    hostIfName: veth4
    enabled: true
    ipAddresses:
    - '${ENDPOINT_VETH_IP}'/24
    physAddress: 66:66:66:66:66:65
    veth:
      peerIfName: vpptoLinuxVETH
  - name: startpointToLinuxVETH
    type: VETH
    hostIfName: veth2
    enabled: true
    veth:
      peerIfName: startpointVETH
vppConfig:
  interfaces:
  - name: toVPPAFPacket
    type: AF_PACKET
    enabled: true
    physAddress: a7:35:45:55:65:75
    ipAddresses:
    - '${STARTPOINT_VETH_HOST_IP}'/24
    afpacket:
      hostIfName: veth2
  - name: fromVPPAFPacket
    type: AF_PACKET
    enabled: true
    physAddress: b7:35:45:55:65:75
    ipAddresses:
    - '${ENDPOINT_VETH_HOST_IP}'/24
    afpacket:
      hostIfName: veth3
  routes:
  - dstNetwork: '${TRAFFIC_DEST_IP}'/32
    nextHopAddr: '${ENDPOINT_VETH_IP}'/24
    outgoingInterface: fromVPPAFPacket
  - dstNetwork: '${STARTPOINT_IP}'/32
    nextHopAddr: '${STARTPOINT_VETH_IP}'
    outgoingInterface: toVPPAFPacket
'

    echo "--creating route in startpoint to veth tunnel..."
    docker exec -it startpoint ip route add ${TRAFFIC_DEST_NETWORK} via ${STARTPOINT_VETH_HOST_IP}

    echo "--disabling Linux kernel's reverse path filtering" #disabling to not filter out packets based on unknown/trash source address (source address is expected by this filtering to be reachable with interface from which the packet came)
    docker exec -it endpoint sysctl -w net.ipv4.conf.all.rp_filter=0 > /dev/null
    docker exec -it endpoint sysctl -w net.ipv4.conf.veth4.rp_filter=0 > /dev/null

    echo "--enabling Linux kernel's routing of packet from veth tunnel to localnet (127.0.0.1)" #external/"martian" source addressed packets are not allowed to localnet by default
    docker exec -it endpoint sysctl -w net.ipv4.conf.all.route_localnet=1 > /dev/null
    docker exec -it endpoint sysctl -w net.ipv4.conf.veth4.route_localnet=1 > /dev/null

    echo "--moving packets from tunnel (VPP->Endpoint) to Linux localhost" #(so that netcat/socat server listening to localhost can pick them
    docker exec -it endpoint iptables -t nat -A PREROUTING -i veth4 -p udp --dport ${PORT} -j DNAT --to-destination 127.0.0.1
    docker exec -it endpoint iptables -t nat -A PREROUTING -i veth4 -p tcp --dport ${PORT} -j DNAT --to-destination 127.0.0.1

    echo "--route back for TCP's confirmation packet" #TCP does confirmation using packet sending back to TCP client
    docker exec -it endpoint ip route add ${STARTPOINT_VETH_IP}/32 via ${ENDPOINT_VETH_HOST_IP}

    echo "--waiting for processing and applying the configuration inside CNF" #configuration items are dependent on each other and correct configuration may take time
    sleep 5s # TODO make pooling solution

    #TODO i should probably find out all things needed to setup and setup them manually
    echo "--sending one packet to trigger initialization of packet path(ARP learning and other stuff)" #otherwise first packet failure will break netcat connetion
    docker exec -it startpoint sh -c "timeout -t 1 ping ${TRAFFIC_DEST_IP} || true" > /dev/null
    echo
}

function setupLoopForIPAddress() {
    local containerName=$1
    local ipAddress=$2
    $(docker exec -it ${containerName} ip addr add ${ipAddress}/32 dev lo)
}

function newVPPTrace() {
    docker exec -it ${CNF_CONTAINER_NAME} vppctl clear trace
    docker exec -it ${CNF_CONTAINER_NAME} vppctl trace add af-packet-input 100
}

function sendPing() {
    local start_container_name=$1
    local dest_ip=$2

    pingOutput=$(docker exec -it ${start_container_name} ping -c 1 -W 3 ${dest_ip} || true)
    if [[ "$pingOutput" == *"100% packet loss"* ]]; then
        # empty string will be evaluated as false when used in if condition
        PASSED_THROUGHT=
    else
        PASSED_THROUGHT=yes
    fi
}

function logVPPTrace() {
    docker exec -it ${CNF_CONTAINER_NAME} vppctl sh trace > reports/vpp-trace-output-$1.txt
}

function logVPPACLConfig() {
    docker exec -it ${CNF_CONTAINER_NAME} vppctl show acl-plugin acl > reports/vpp-acl-config-output.txt
    docker exec -it ${CNF_CONTAINER_NAME} vppctl show int >> reports/vpp-acl-config-output.txt # needed due to interface referencing in ACL configuration
}

function getVPPTrace() {
    docker exec -it ${CNF_CONTAINER_NAME} vppctl sh trace
}

function assertStartEndPointDockerImage() {
    if ! docker images | grep $TEST_ALPINE_IMAGE_TAG > /dev/null; then
        echo "Creating docker image for startpoint/endpoint"
        printf "FROM alpine:3.9.5\n RUN apk add iproute2" | docker build - --tag  $TEST_ALPINE_IMAGE_TAG
        echo
    fi
}
