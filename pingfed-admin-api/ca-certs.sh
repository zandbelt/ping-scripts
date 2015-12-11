#!/bin/sh

# sample script to manage CA certificates

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	list)
		echo ${FLAGS} | xargs curl ${PF_API}/certificates/ca
		;;
	get)
		echo ${FLAGS} | xargs curl ${PF_API}/certificates/ca/${2}
		;;
	delete)
		echo ${FLAGS} | xargs curl -X DELETE ${PF_API}/certificates/ca/${2}
		;;
	import)
		DATA=`cat ${2} | sed '$d' | sed '1,1d' | tr -d '\n'`
		JSON_DATA=`cat <<JSON
{
  "fileData": "${DATA}"
}
JSON`
		echo ${FLAGS} | xargs curl -H "Content-Type: application/json" --data-binary "${JSON_DATA}" ${PF_API}/certificates/ca/import
		;;
	*)
		echo "Usage: $0 [ list | get <id> | delete <id> | import <filename>"
		;;
esac
