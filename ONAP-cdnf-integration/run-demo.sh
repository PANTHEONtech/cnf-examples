#!/usr/bin/env bash

# requirements:
# 1. docker, docker-compose
# 2. curl
#
#(Tested with:
# Ubuntu 20.04
# docker 20.10.5
# docker-compose 1.27.4
# curl 7.68.0 (x86_64-pc-linux-gnu)
# )

set -eo pipefail

source firewall-cnf-helper.sh


CBA_FILE="cba.zip"
ENRICHED_CBA_FILE="cba-enriched.zip"

echo " -----------------------------------------------------------------------------"
echo "  Configuring Firewall CNF using ONAP (CDS)                                   "
echo " -----------------------------------------------------------------------------"

########################################
# Setup
########################################

echo
echo "Cleaning up from previous runs and doing other preparations..."
docker-compose down --volumes  # removing also DB volumes
rm ${CBA_FILE} > /dev/null 2>&1 || true
rm ${ENRICHED_CBA_FILE} > /dev/null 2>&1 || true
preDockerComposeCNFPreparations

echo
echo "Starting docker containers/networking..."
docker-compose up -d

echo
echo "Waiting little bit longer to start CNF properly..."
sleep 5s

echo
echo "Preparing Firewall CNF use case topology..."
setupCNFTrafficTopology

echo
echo "Waiting little bit longer to start CDS-blueprintprocessor properly..."
sleep 5s


echo
echo "CDS bootstraping (loading of default model types and resource dictionary-needed for proper CBA enrichment)..."
curl --location --request POST 'http://localhost:8000/api/v1/blueprint-model/bootstrap' \
--header 'Content-Type: application/json' \
--header 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' \
--data-raw '{
"loadModelType" : true,
"loadResourceDictionary" : true,
"loadCBA" : false
}'

echo
echo "Packing CBA (making zip archive from cba folder content)..."
cd cba;zip -r ../${CBA_FILE} * -x "pom.xml" "target/*";cd ..

echo
echo "Enriching CBA..."
curl --location --request POST 'http://localhost:8000/api/v1/blueprint-model/enrich' \
--header 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' \
--form 'file=@"./'${CBA_FILE}'"' \
--output ${ENRICHED_CBA_FILE}

echo
echo "Saving/Uploading enriched CBA to CDS..."
curl --location --request POST 'http://localhost:8000/api/v1/blueprint-model' \
--header 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' \
--form 'file=@"./'${ENRICHED_CBA_FILE}'"'

########################################
# Sending Traffic through Firewall CNF
########################################

echo;echo
echo "Sending data through unconfigured firewall..."
newVPPTrace
sendPing "startpoint" ${TRAFFIC_DEST_IP}
if [ ! $PASSED_THROUGHT ]; then
  echo "=> failed to transmit data properly (ERROR)"
  logVPPTrace "unconfigured-firewall"
  exit 1
else
  echo "=> data transmission was successful  (OK)"
  logVPPTrace "unconfigured-firewall"
fi

echo
echo "Starting firewall configuration (Deny traffic) by using CDS..."
curl --location --request POST 'http://localhost:8000/api/v1/execution-service/process' \
--header 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' \
--header 'Content-Type: application/json' \
--data-raw '{
	"actionIdentifiers": {
		"mode": "sync",
		"blueprintName": "Firewall-CNF-configuration-example",
		"blueprintVersion": "1.0.0",
		"actionName": "apply-firewall-rule"
	},
	"payload": {
		"apply-firewall-rule-request": {
			"cnf-rest-url": "http://'${CNF_CONTAINER_NAME}':9191",
			"firewall_action": "DENY",
      "traffic_destination_network": "'${TRAFFIC_DEST_IP}'/32"
		}
	},
	"commonHeader": {
		"subRequestId": "143748f9-3cd5-4910-81c9-a4601ff2ea58",
		"requestId": "e5eb1f1e-3386-435d-b290-d49d8af8db4c",
		"originatorId": "SDNC_DG"
	}
}'

echo;echo
echo "Sending data through configured firewall (Deny traffic)..."
newVPPTrace
sendPing "startpoint" ${TRAFFIC_DEST_IP}
if [ ! $PASSED_THROUGHT ]; then
  if [[ $(getVPPTrace) == *"ACL deny packets"* ]]; then
      echo "=> blocked by firewall as expected (OK)"
      logVPPTrace "deny-configured-firewall"
  else
    echo "=> didn't pass throught but not because of firewall => demo failure (ERROR)"
    logVPPTrace "deny-configured-firewall"
    exit 1
  fi
else
  echo "=> passed through firewall but shouldn't(ERROR)"
  logVPPTrace "deny-configured-firewall"
  exit 1
fi

echo
echo "Starting firewall configuration (Allow traffic) by using CDS..."
curl --location --request POST 'http://localhost:8000/api/v1/execution-service/process' \
--header 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' \
--header 'Content-Type: application/json' \
--data-raw '{
	"actionIdentifiers": {
		"mode": "sync",
		"blueprintName": "Firewall-CNF-configuration-example",
		"blueprintVersion": "1.0.0",
		"actionName": "apply-firewall-rule"
	},
	"payload": {
		"apply-firewall-rule-request": {
			"cnf-rest-url": "http://'${CNF_CONTAINER_NAME}':9191",
			"firewall_action": "PERMIT",
      "traffic_destination_network": "'${TRAFFIC_DEST_IP}'/32"
		}
	},
	"commonHeader": {
		"subRequestId": "143748f9-3cd5-4910-81c9-a4601ff2ea58",
		"requestId": "e5eb1f1e-3386-435d-b290-d49d8af8db4c",
		"originatorId": "SDNC_DG"
	}
}'

echo;echo
echo "Sending data through configured firewall (Allowed Traffic)..."
newVPPTrace
sendPing "startpoint" ${TRAFFIC_DEST_IP}
if [ ! $PASSED_THROUGHT ]; then
  echo "=> failed to transmit data properly (ERROR)"
  logVPPTrace "allow-configured-firewall"
  exit 1
else
  echo "=> data transmission was successful  (OK)"
  logVPPTrace "allow-configured-firewall"
fi

echo
echo "Logging CNF state..."
reportCNFState


########################################
# Clean up
########################################

echo
echo "Cleaning up..."
rm ${CBA_FILE} > /dev/null 2>&1 || true
rm ${ENRICHED_CBA_FILE} > /dev/null 2>&1 || true
docker-compose down --volumes  # removing also DB volumes
cleanupCNFRelatedThings
