#!/bin/sh

# sample script to add a new verification certificate to a SP Connection

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u ${ADM_USER}:${ADM_PWD} --header X-XSRF-Header:\ pingfed"

SPID=$2
#SPID=iIsFjLr8PxZhoE1h8zFEG4Rre3P
PEM=$3

case $1 in
	list)
		echo ${FLAGS} | xargs curl ${PF_API}/idp/spConnections
		;;

	add)
		DATA=`cat "${PEM}" | sed '$d' | sed '1,1d' | tr -d '\n'`
		JSON_DATA=`cat <<JSON
{
  "primaryVerificationCert": false,
  "secondaryVerificationCert": false,
  "x509File": {
    "fileData": "${DATA}"
  },
  "activeVerificationCert": false,
  "encryptionCert": false
}	
JSON`
		echo ${FLAGS} | xargs curl ${PF_API}/idp/spConnections/${SPID} | \
			jq ".credentials.certs += [ ${JSON_DATA} ]" | \
			curl ${FLAGS} -H "Content-Type: application/json" -X PUT -d @- ${PF_API}/idp/spConnections/${SPID}
		;;
	*)
		echo "Usage: $0 [ list | add <sp-connection-id> <pem-filename>"
		;;		
esac
