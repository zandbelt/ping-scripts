#!/bin/bash

# sample script to check verification certificate expiry on connections

ADM_USER="administrator"
ADM_PWD="2Federate"
PF_API="https://localhost:9999/pf-admin-api/v1"

FLAGS="-k -S -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

pf_check_expiry() {
  local ENDPOINT="$1"
  local DAYS="$2"
  if [ -z "${DAYS}" ] ; then DAYS=30; fi
  echo ${FLAGS} | xargs curl ${PF_API}/${ENDPOINT} | jq '.items[] | .entityId as $entityid | .credentials.certs[] | [$entityid, .x509File.fileData] | join("|")' |
    while IFS="|" read -r entityid cert ; do
      entityid=$(echo "$entityid" | tr -d '"')
      cert=$(echo "$cert" | tr -d '"')
      #echo "entityid = *${entityid}*"
      #echo "cert = *${cert}*"
      enddate=$(echo -e "$cert" | openssl x509 -checkend $(( 86400 * DAYS )) -enddate)
      if [[ $enddate =~ (.*)Certificate\ will\ expire ]]; then
        echo "Verification certificate for \"$entityid\" has expired or will do so within the next $DAYS day(s)!"
      else
        echo "Verification certificate for \"$entityid\" is good for another $DAYS day(s)."
      fi
    done
}

case $1 in
	idps)
	    pf_check_expiry "sp/idpConnections" "$2"
		;;
	sps)
	    pf_check_expiry "idp/spConnections" "$2"
		;;
	*)
		echo "Usage: $0 [ idps [<days>] | sps [<days>] ] "
		;;
esac
