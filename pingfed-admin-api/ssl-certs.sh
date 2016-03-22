#!/bin/sh

# sample script to manage SSL certificates

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	list)
		echo ${FLAGS} | xargs curl ${PF_API}/keyPairs/sslServer
		;;
	get)
		echo ${FLAGS} | xargs curl ${PF_API}/keyPairs/sslServer/${2}
		;;
	pkcs12-get)
		JSON_DATA=`cat <<JSON
{
  "password": "2Federate"
}
JSON`
		echo ${FLAGS} | xargs curl -H "Content-Type: application/json" --data-binary "${JSON_DATA}" ${PF_API}/keyPairs/sslServer/${2}/pkcs12
		;;
	delete)
		echo ${FLAGS} | xargs curl -X DELETE ${PF_API}/keyPairs/sslServer/${2}
		;;
	import)
		DATA=`cat ${2} | openssl base64 | tr -d '\n'`
		JSON_DATA=`cat <<JSON
{
  "fileData": "${DATA}",
  "password": "2Federate"
}
JSON`
		echo ${FLAGS} | xargs curl -H "Content-Type: application/json" --data-binary "${JSON_DATA}" ${PF_API}/keyPairs/sslServer/import
		;;
	*)
		echo "Usage: $0 [ list | get <id> | pkcs12-get <id> | delete <id> | import <pkcs12-filename>"
		;;
esac
