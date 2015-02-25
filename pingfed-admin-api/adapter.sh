#!/bin/sh

# sample script to obtain adapter settings from a template adapter,
# modify the Authentication Service by adding a "tenant" parameter
# to it, and create a new adapter with the updated settings

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	list)
		echo ${FLAGS} | xargs curl ${PF_API}/idp/adapters
		;;
	get)
		echo ${FLAGS} | xargs curl ${PF_API}/idp/adapters/${2}
		;;
	delete)
		echo ${FLAGS} | xargs curl -X DELETE ${PF_API}/idp/adapters/${2}
		;;
	copy)
		FROM_JSON=`echo ${FLAGS} | xargs curl ${PF_API}/idp/adapters/${2}`
		TO_JSON=`echo ${FROM_JSON} | jq " \
			.name = \"$3\" | .id   = \"$3\" | (.configuration.fields[] | \
				select(.name == \"Authentication Service\") | .value) |= . + \"&tenantid=\" + \"$3\""`
		echo ${FLAGS} | xargs curl -H "Content-Type: application/json" --data-binary "${TO_JSON}" ${PF_API}/idp/adapters
		;;
	*)
		echo "Usage: $0 [ list | get <id> | delete <id> | copy <from_id> <to_id>"
		;;		
esac
