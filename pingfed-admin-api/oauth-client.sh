#!/bin/sh

# sample script to manage OAuth clients

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	list)
		echo ${FLAGS} | xargs curl ${PF_API}/oauth/clients
		;;
	get)
		echo ${FLAGS} | xargs curl ${PF_API}/oauth/clients/${2}
		;;
	delete)
		echo ${FLAGS} | xargs curl -X DELETE ${PF_API}/oauth/clients/${2}
		;;
	create)
		JSON_DATA=`cat <<JSON
{
  "clientId": "${2}",
  "redirectUris": [
    "https://localhost:9031/OAuthPlayground/case1A-callback.jsp"
  ],
  "grantTypes": [
    "CLIENT_CREDENTIALS"
  ],
  "name": "${2}",
  "clientAuth": {
    "type": "CERTIFICATE",
    "clientCertIssuerDn": "CN=localhost, OU=Development, O=PingIdentity, L=Denver, ST=CO, C=US",
    "clientCertSubjectDn": "CN=${2}"
  }
}
JSON`
		echo ${FLAGS} | xargs curl -H "Content-Type: application/json" --data-binary "${JSON_DATA}" ${PF_API}/oauth/clients
		;;
	*)
		echo "Usage: $0 [ list | get <id> | delete <id> | create <id>"
		;;		
esac
