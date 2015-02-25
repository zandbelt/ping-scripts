#!/bin/sh

PFMGMT=https://localhost:9999
USERNAME=heuristics
PASSWD=Changeme1

# insecure no-ssl-server-cert checking for testing purposes
CURL_FLAGS=-k
URL=${PFMGMT}/pf-mgmt-ws/ws/ConfigReplication
curl ${CURL_FLAGS} -u ${USERNAME}:${PASSWD} -H "soapAction: ${URL}" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><s:Envelope xmlns:s=\"http://www.w3.org/2003/05/soap-envelope\"><s:Body><replicateConfiguration/></s:Body></s:Envelope>" ${URL}
