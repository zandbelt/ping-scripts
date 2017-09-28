#!/bin/sh

# sample script to check verification certificate expiry on connections

ADM_USER="administrator"
ADM_PWD="2Federate"
PF_API="https://localhost:9999/pf-admin-api/v1"

FLAGS="-k -S -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	idps)
		DAYS=30
		if [ -n "$2" ] ; then
			DAYS=$2
		fi
		echo ${FLAGS} | xargs curl ${PF_API}/sp/idpConnections | jq '.items[] | .entityId as $entityid | .credentials.certs[] | [$entityid, .x509File.fileData] | join("|")' |
		  while IFS="|" read -r entityid cert ; do
		    id=$(echo $id | tr -d '"')
		    cert=$(echo $cert | tr -d '"')
		    enddate=$(echo "$cert" | openssl x509 -checkend $(( 86400 * DAYS )) -enddate)
		    if [[ $enddate =~ (.*)Certificate\ will\ expire ]]; then
		      echo "Verification certificate for \"$entityid\" has expired or will do so within the next $DAYS day(s)!"
		    else
		      echo "Verification certificate for \"$entityid\" is good for another $DAYS day(s)."
		    fi
		  done
		;;
	*)
		echo "Usage: $0 [ idps [<days>] ] "
		;;
esac
