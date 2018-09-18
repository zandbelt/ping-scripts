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

# credentials for resource owner password credentials grant
RO_CLIENT_ID="ro_client"

USERNAME="joe"
PASSWORD="2Federate"

#SCOPES="openid admin edit"

# introspection client_id/client_secret
RS_CLIENT_ID="rs_client"
RS_CLIENT_SECRET="2Federate"

CURL_FLAGS="-s -S -k"

if [ ! -z "${SCOPES}" ] ; then
  SCOPES_POST="-d scope=\"${SCOPES}\""
fi


case $1 in
	request)
		echo "${CURL_FLAGS} ${SCOPES_POST}" | xargs curl -d "client_id=${RO_CLIENT_ID}" -d "grant_type=password" -d "username=${USERNAME}" -d "password=${PASSWORD}" "https://${PF_HOST_PORT}/as/token.oauth2" | jq '.'	
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