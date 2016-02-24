#!/bin/sh

# sample script to add a virtual server id to an existing SP Connection

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u ${ADM_USER}:${ADM_PWD} --header X-XSRF-Header:\ pingfed"

function print_usage() {
  echo "Usage: $0 <connection-id> <new-virtual-server-id> "
  exit 1
}

if [ $# -lt 2 ] ; then print_usage; fi

SPID=$1
#SPID=iIsFjLr8PxZhoE1h8zFEG4Rre3P
VSID=$2

#when it is the first virtual server id, we also need to set the default virtual server id
#curl ${FLAGS} ${PF_API}/idp/spConnections/${SPID} | jq ".virtualEntityIds |=.+ [\"${VSID}\"] | .defaultVirtualEntityId = \"${VSID}\"" | curl ${FLAGS} -H "Content-Type: application/json" -X PUT -d @- ${PF_API}/idp/spConnections/${SPID}

curl ${FLAGS} ${PF_API}/idp/spConnections/${SPID} | jq ".virtualEntityIds |=.+ [\"${VSID}\"]" | curl ${FLAGS} -H "Content-Type: application/json" -X PUT -d @- ${PF_API}/idp/spConnections/${SPID}
