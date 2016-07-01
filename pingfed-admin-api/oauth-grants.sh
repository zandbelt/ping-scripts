#!/bin/sh

#
# sample script to list/delete OAuth persistent grants for a user
#

# NB: ADM_* are user details valid for the PCV configured in the OAuth Settings
ADM_USER=joe
ADM_PWD=2Federate
PF_API=https://localhost:9031/pf-ws/rest/oauth

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

case $1 in
	get)
		echo ${FLAGS} | xargs curl ${PF_API}/users/${2}/grants
		;;
	delete)
		echo ${FLAGS} | xargs curl -X DELETE ${PF_API}/users/joe/grants/${2}
		;;
	*)
		echo "Usage: $0 [ get <username> | delete <id> ]"
		;;		
esac
