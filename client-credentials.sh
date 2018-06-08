#!/bin/bash
###########################################################################
# Copyright (C) 2018 ZmartZone IAM
# Author: Hans Zandbelt <hzandbelt@zmartzone.eu
###########################################################################

# PREREQS:
# - system utilities: bash curl jq
# - OAuth Playground is installed on/next to PingFederate

PF_HOST_PORT="localhost:9031"
PF_CREDS="administrator:2Federate"

# credentials for client credentials grant
CC_CLIENT_ID="cc_secret_client"
CC_CLIENT_SECRET="2Federate"

# introspection client_id/client_secret
RS_CLIENT_ID="rs_client"
RS_CLIENT_SECRET="2Federate"

CURL_FLAGS="-s -S -k"

case $1 in
	request)
		echo ${CURL_FLAGS} | xargs curl -u "${CC_CLIENT_ID}:${CC_CLIENT_SECRET}" -d "grant_type=client_credentials" "https://${PF_HOST_PORT}/as/token.oauth2" | jq '.'
		;;
	introspect)
		if [  -z "$2" ] ; then echo "Usage $0 introspect <token" ; exit ; fi
		echo ${CURL_FLAGS} | xargs curl -u "${RS_CLIENT_ID}:${RS_CLIENT_SECRET}" -d "token=$2" "https://${PF_HOST_PORT}/as/introspect.oauth2" | jq '.'
		;;
	run)
		${0} request | jq '.access_token' | xargs ${0} introspect
		;;
	*)
		echo "Usage: $0 request | introspect <token> | run"
		;;
esac
