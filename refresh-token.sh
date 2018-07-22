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

# credentials for client
CLIENT_ID=ro_client
USER=joe
PASSWD=2Federate

CURL_FLAGS="-s -S -k"

case $1 in
	request)
		echo ${CURL_FLAGS} | xargs curl -d "grant_type=password" -d "client_id=${CLIENT_ID}" -d "username=${USER}" -d "password=${PASSWD}"  "https://${PF_HOST_PORT}/as/token.oauth2" | jq '.'
		;;
	refresh)
		if [  -z "$2" ] ; then echo "Usage $0 refresh <refresh_token>" ; exit ; fi
		echo ${CURL_FLAGS} | xargs curl -d "grant_type=refresh_token" -d "client_id=${CLIENT_ID}"  -d "refresh_token=$2" "https://${PF_HOST_PORT}/as/token.oauth2" | jq '.'
		;;
	run)
		${0} request | jq '.access_token' | xargs ${0} refresh
		;;
	*)
		echo "Usage: $0 request | refresh <refresh_token> | run"
		;;
esac
