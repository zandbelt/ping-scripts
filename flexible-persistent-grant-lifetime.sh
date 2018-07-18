#!/bin/bash
###########################################################################
# Copyright (C) 2018 ZmartZone IAM
# Author: Hans Zandbelt <hzandbelt@zmartzone.eu
###########################################################################

#
# Demonstrates flexible persistent grant lifetime
#

# PREREQS:
# - system utilities: bash curl jq openssl
# - OAuth 2.0 Playground installed

PF_HOST=localhost
PF_PORT_ADMIN=9999
PF_PORT_RUNTIME=9031
PF_CREDS="administrator:2Federate"

#
# should not need to modify below 
#

# default persistent grant lifetime in minutes
# 90 days
LIFETIME_DEFAULT=`expr 90 \* 24 \* 60`
#LIFETIME_DEFAULT=300

# special persistent grant lifetime in minutes for requests that contain a special scope 
# 1 year
LIFETIME_SPECIAL=`expr 365 \* 24 \* 60`
#LIFETIME_SPECIAL=600

# scopes requested resulting in default lifetime
SCOPES_DEFAULT="admin"
# scope requested resulting in special lifetime
SCOPE_SPECIAL="edit"

PF_HOST_PORT="${PF_HOST}:${PF_PORT_ADMIN}"
CURL_FLAGS="-s -S -k -H \"X-XSRF-Header: pingfed\" -H \"Content-Type: application/json\" -u \"${PF_CREDS}\""
API_URL="https://${PF_HOST_PORT}/pf-admin-api/v1"
WS_URL="https://${PF_HOST}:${PF_PORT_RUNTIME}/pf-ws"
CLIENT_ID="ro_client"
MAPPING_ID="UserPass"

REQ_PF_HOST_PORT="${PF_HOST}:${PF_PORT_RUNTIME}"
REQ_CURL_FLAGS="-s -S -k"
REQ_USERNAME="joe"
REQ_PASSWD="2Federate"

GRANTS_USERNAME="${REQ_USERNAME}"
GRANTS_PASSWD="${REQ_PASSWD}"
GRANT_CURL_FLAGS="-s -S -k -H \"X-XSRF-Header: pingfed\" -H \"Content-Type: application/json\" -u \"${GRANTS_USERNAME}:${GRANTS_PASSWD}\""

function playground_setup() {
  #
  # add the reserved attribute name PERSISTENT_GRANT_LIFETIME to list of Persistent Grant Extended Attributes
  # and enable the admin ws service with a password credential validator
  #
  CUR_DATA=`echo "${CURL_FLAGS}" | xargs curl "${API_URL}/oauth/authServerSettings"` || exit -1
  UPD_DATA=`jq '.persistentGrantContract.extendedAttributes |= [ { "name": "PERSISTENT_GRANT_LIFETIME" } ]' <(echo ${CUR_DATA})`
  UPD_DATA=`jq '.adminWebServicePcvRef |= { "id": "UserPass" }' <(echo ${UPD_DATA})`
  NEW_DATA=`echo "${CURL_FLAGS}" | xargs curl -X PUT -d "${UPD_DATA}" "${API_URL}/oauth/authServerSettings"` || exit -1

  jq '.' <(echo ${NEW_DATA})
 
  #
  # add a refresh token to the authorization response for the Resource Owner Password Credentials client
  # so that it generates a persistent grant when an authorization request comes in and a refresh token is issued
  #
  CUR_DATA=`echo "${CURL_FLAGS}" | xargs curl "${API_URL}/oauth/clients/${CLIENT_ID}"` || exit -1
  UPD_DATA=`jq '.grantTypes += [ "REFRESH_TOKEN" ]' <(echo ${CUR_DATA})`
  NEW_DATA=`echo "${CURL_FLAGS}" | xargs curl -X PUT -d "${UPD_DATA}" "${API_URL}/oauth/clients/${CLIENT_ID}"` || exit -1

  # map the PERSISTENT_GRANT_LIFETIME in the resource owner credentials mapping
  # with an OGNL expression that sets it to a value based on the requested scope
  #
  # for other request parameters access:
  # #this.get("context.HttpRequest").getObjectValue() is an instance of javax.servlet.http.HttpServletRequest 
  CUR_DATA=`echo "${CURL_FLAGS}" | xargs curl "${API_URL}/oauth/resourceOwnerCredentialsMappings/${MAPPING_ID}"` || exit -1
  UPD_DATA=`jq ".attributeContractFulfillment += { \
\"PERSISTENT_GRANT_LIFETIME\": { \
  \"source\": { \"type\": \"EXPRESSION\" }, \
  \"value\": \"#this.get(\\\\\"context.OAuthScopes\\\\\") != NULL && #this.get(\\\\\"context.OAuthScopes\\\\\").hasValue(\\\\\"${SCOPE_SPECIAL}\\\\\") ? ${LIFETIME_SPECIAL} : ${LIFETIME_DEFAULT}\" } \
}" <(echo ${CUR_DATA})`
  NEW_DATA=`echo "${CURL_FLAGS}" | xargs curl -X PUT -d "${UPD_DATA}" "${API_URL}/oauth/resourceOwnerCredentialsMappings/${MAPPING_ID}"` || exit -1

  jq '.' <(echo ${NEW_DATA})
}

case $1 in
	setup)
		playground_setup
		;;
	request)
		if [  -z "$2" ] ; then echo "Usage $0 request <scopes>" ; exit ; fi
		echo ${REQ_CURL_FLAGS} | xargs curl -d "scope=${2}" -d "grant_type=password" -d "client_id=${CLIENT_ID}" -d "username=${REQ_USERNAME}" -d "password=${REQ_PASSWD}"  "https://${REQ_PF_HOST_PORT}/as/token.oauth2" | jq '.'
		;;
	grants)
 		#CUR_DATA=`echo "${CURL_FLAGS}" | xargs curl "${WS_URL}/rest/oauth/clients/${CLIENT_ID}/grants"` || exit -1
 		CUR_DATA=`echo "${GRANT_CURL_FLAGS}" | xargs curl "${WS_URL}/rest/oauth/users/${REQ_USERNAME}/grants"` || exit -1		
	 	jq '.' <(echo ${CUR_DATA})
	    ;;
	run)
		${0} setup >/dev/null && ${0} request "${SCOPES_DEFAULT}" > /dev/null && ${0} request "${SCOPES_DEFAULT} ${SCOPE_SPECIAL}" >/dev/null && ${0} grants
		;;
	*)
		echo "Usage: $0 setup | request <scopes> | grants | run"
		;;
esac
