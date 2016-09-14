#!/bin/sh

###########################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# Script used to do semi-automated OpenID Connect Relying Party Certification
# Testing for the mod_auth_openidc OIDC RP implementation for Apache HTTPd.
# 
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
###########################################################################

REDIRECT_URI="<THE-REDIRECT_URI-OF-YOUR-APACHE-MOD_AUTH_OPENIDC-INSTANCE>"
TARGET_URL="<YOUR-APPLICATION-URL-PROTECTED-BY-MOD_AUTH_OPENIDC>"
RP_ID="<YOUR-RP-TEST-CLIENT-IDENTIFIER>"

SETENV="$(dirname "$0")/setenv.sh"
if [[ -x "${SETENV}" ]]; then
	source "${SETENV}"
fi

RP_TEST_URL="https://rp.certification.openid.net:8080"
COOKIE_JAR="/tmp/cookie.jar"
FLAGS="-s -k -b ${COOKIE_JAR} -c ${COOKIE_JAR}"

function grep_location_header_value() {
	grep -i "Location:" | cut -d" " -f2 | tr -d '\r' | cut -d"#" -f2
}

TESTS="
	rp_discovery_webfinger_url
	rp_discovery_webfinger_acct
	rp_discovery_issuer_not_matching_config
	rp_discovery_openid_configuration
	rp_discovery_jwks_uri_keys
	rp_discovery_webfinger_unknown_member
	rp_registration_dynamic
	rp_response_type_code
	rp_token_endpoint_client_secret_basic
	rp_token_endpoint_client_secret_post
"

if [ -z $1 ] ; then
  echo
  echo "Usage: ${0} [all|${TESTS}]"
  echo
  exit
fi

# create CSRF token to be supplied on subsequent calls
function exec_init() {
 local BEHAVIOR=$1
 echo " [${BEHAVIOR}] initiate CSRF..."
 CSRF=`echo ${FLAGS} -j | xargs curl ${TARGET_URL} | grep hidden | grep x_csrf | cut -d"\"" -f6`
}

# call the RP endpoint (=mod_auth_openidc's redirect URI) to kick off discovery and/or SSO
function exec_discovery() {
	local TEST_ID=$1
	local CSRF=$2
	local ISSUER=$3
	echo ${FLAGS} -i | xargs curl -G --data-urlencode "iss=${ISSUER}" --data-urlencode "target_link_uri=${TARGET_URL}" --data-urlencode "x_csrf=${CSRF}" ${REDIRECT_URI}
}

function rp_discovery_webfinger_url() {
	local TEST_ID="rp-discovery-webfinger-url"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " [${TEST_ID}] initiate Discovery..."
	exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} >/dev/null
	
	echo " * "
	echo " * [server] check that the registration is initiated to the discovered endpoint: ${RP_ID}/${TEST_ID}/registration"
	echo " * [server] the registration itself will fail with an \"incorrect_behavior: You should not talk to this endpoint in this test\""
	echo " * "
}

function rp_discovery_webfinger_acct() {
	local TEST_ID="rp-discovery-webfinger-acct"
	local CSRF=$1
	local DOMAIN=`echo ${RP_TEST_URL} | cut -d"/" -f3`
	local ACCT="${RP_ID}.${TEST_ID}@${DOMAIN}"

	echo " [${TEST_ID}] initiate Discovery..."
	exec_discovery ${TEST_ID} ${CSRF} ${ACCT} | grep_location_header_value

	echo " * "
	echo " * [server] check that the webfinger request contains acct:"
	echo " * [client] check that the authentication request is initiated to the discovered authorization endpoint with the login_hint set to the acct: value"
	echo " * "
}

function rp_discovery_issuer_not_matching_config() {
	local TEST_ID="rp-discovery-issuer-not-matching-config"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " [${TEST_ID}] initiate Discovery..."
	exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} >/dev/null

	echo " * "
	echo " * [server] check that discovery failed with \"requested issuer (${ISSUER}) does not match the \"issuer\" in the provider metadata file: https://example.com\" "
	echo " * "
}

function rp_discovery_openid_configuration() {
	local TEST_ID="rp-discovery-openid-configuration"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " [${TEST_ID}] initiate Discovery..."
	exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} >/dev/null

	echo " * "
	echo " * [server] check that the registration is initiated to the discovered endpoint: ${RP_ID}/${TEST_ID}/registration (and may fail)"
	echo " * "
}

function rp_discovery_jwks_uri_keys() {
	local TEST_ID="rp-discovery-jwks_uri-keys"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " [${TEST_ID}] initiate Discovery..."
	REQUEST=`exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} | grep_location_header_value`
	echo " [${TEST_ID}] send authentication request to OP..."
	RESPONSE=`echo ${FLAGS} -i | xargs curl "${REQUEST}" | grep_location_header_value`
	echo " [${TEST_ID}] return authentication response to RP..."
	RETURN=`echo ${FLAGS} -i | xargs curl "${RESPONSE}" | grep_location_header_value`
	printf " [${TEST_ID}] access application as authenticated user..."
	echo ${FLAGS} | xargs curl "${RETURN}" | grep -q "\[OIDC_CLAIM_sub\]" && echo "SUCCESS" || echo "ERROR"

	echo " * "
	echo " * [server] check that the id_token returned by the OP verifies correctly with the discovered key"
	echo " * [client] check that access the to application is granted as an authenticated user (\"SUCCESS\")"
	echo " * "
}

 
function rp_discovery_webfinger_unknown_member() {
	local TEST_ID="rp-discovery-webfinger-unknown-member"
	local CSRF=$1
	local DOMAIN=`echo ${RP_TEST_URL} | cut -d"/" -f3`
	local ACCT="${RP_ID}.${TEST_ID}@${DOMAIN}"

	echo " [${TEST_ID}] initiate Discovery..."
	exec_discovery ${TEST_ID} ${CSRF} ${ACCT} | grep_location_header_value

	echo " * "
	echo " * [server] check that the webfinger request contains acct: and the response contains \"dummy\": \"foobar\""
	echo " * [server] check that the registration is initiated to the discovered endpoint: ${RP_ID}/${TEST_ID}/registration (and may fail)"
	echo " * "
}

function rp_registration_dynamic() {
	local TEST_ID="rp-registration-dynamic"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	printf " [${TEST_ID}] initiate Discovery and Client Registration..."
	exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} | grep_location_header_value | grep -q "${RP_TEST_URL}/${RP_ID}/${TEST_ID}/authorization" && echo "SUCCESS" || echo "ERROR"

	echo " * "
	echo " * [server] check that the registration is initiated and a succesful client registration response is returned"
	echo " * [client] check that the authentication request is initiated to the discovered authorization endpoint (\"SUCCESS\")"
	echo " * "
}

function rp_response_type_code() {
	local TEST_ID="rp-response_type-code"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	
	echo " [${TEST_ID}] initiate Discovery..."
	REQUEST=`exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} | grep_location_header_value`
	echo " [${TEST_ID}] send authentication request to OP..."
	RESPONSE=`echo ${FLAGS} -i | xargs curl "${REQUEST}" | grep_location_header_value`
	echo " [${TEST_ID}] return authentication response to RP..."
	RETURN=`echo ${FLAGS} -i | xargs curl "${RESPONSE}" | grep_location_header_value`
	printf " [${TEST_ID}] access application as authenticated user..."
	echo ${FLAGS} | xargs curl "${RETURN}" | grep -q "\[OIDC_CLAIM_sub\]" && echo "SUCCESS" || echo "ERROR"

	echo " * "
	echo " * [server] check that the code is returned by the OP to the redirect URI"
	echo " * [client] check that access the to application is granted as an authenticated user (\"SUCCESS\")"
	echo " * "	
}

function rp_token_endpoint_client_secret_basic() {
	local TEST_ID="rp-token_endpoint-client_secret_basic"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	
	echo " [${TEST_ID}] initiate Discovery..."
	REQUEST=`exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} | grep_location_header_value`
	echo " [${TEST_ID}] send authentication request to OP..."
	RESPONSE=`echo ${FLAGS} -i | xargs curl "${REQUEST}" | grep_location_header_value`
	echo " [${TEST_ID}] return authentication response to RP..."
	RETURN=`echo ${FLAGS} -i | xargs curl "${RESPONSE}" | grep_location_header_value`
	printf " [${TEST_ID}] access application as authenticated user..."
	echo ${FLAGS} | xargs curl "${RETURN}" | grep -q "\[OIDC_CLAIM_sub\]" && echo "SUCCESS" || echo "ERROR"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_basic\""
	echo " * [server] check that the client was registered with \"token_endpoint_auth_method\" set to \"client_secret_basic\""
	echo " * [server] check that the code is exchanged at the OP with a \"basic_auth\" value passed to the \"oidc_util_http_call\" function"
	echo " * [client] check that access the to application is granted as an authenticated user (\"SUCCESS\")"
	echo " * "		
}

function rp_token_endpoint_client_secret_post() {
	local TEST_ID="rp-token_endpoint-client_secret_post"
	local CSRF=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	
	echo " [${TEST_ID}] initiate Discovery..."
	REQUEST=`exec_discovery ${TEST_ID} ${CSRF} ${ISSUER} | grep_location_header_value`
	echo " [${TEST_ID}] send authentication request to OP..."
	RESPONSE=`echo ${FLAGS} -i | xargs curl "${REQUEST}" | grep_location_header_value`
	echo " [${TEST_ID}] return authentication response to RP..."
	RETURN=`echo ${FLAGS} -i | xargs curl "${RESPONSE}" | grep_location_header_value`
	printf " [${TEST_ID}] access application as authenticated user..."
	echo ${FLAGS} | xargs curl "${RETURN}" | grep -q "\[OIDC_CLAIM_sub\]" && echo "SUCCESS" || echo "ERROR"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_post\""
	echo " * [server] check that the client was registered with \"token_endpoint_auth_method\" set to \"client_secret_post\""
	echo " * [server] check that the code is exchanged at the OP with a \"client_id\" and \"client_secret\" passed to the \"oidc_util_http_call\" function as POST parameters"
	echo " * [client] check that access the to application is granted as an authenticated user (\"SUCCESS\")"
	echo " * "		
}

exec_init $1

if [ $1 != "all" ] ; then
	eval $1 $CSRF
else
	for TEST_ID in $TESTS; do
		eval $TEST_ID $CSRF		
	done
fi

#
# OLD:
#
# exec_implicit "${1}" "${CSRF}"
# if [[ $? -eq 0 ]] ; then echo "yes" ; else echo "no"; fi

#
# Implicit, parsing out fragment encoded response and posting to RP
#
# presumes that the implicit grant is pre-configured in a pre-existing <issuer.conf file...
#
function exec_implicit() {
  local BEHAVIOR=$1
  local CSRF=$2
  local ISSUER="${RP_TEST_URL}/${RP_ID}/_/_/${BEHAVIOR}/normal"
  echo " [${BEHAVIOR}] initiate SSO..."
  REQUEST=`echo ${FLAGS} -i | xargs curl -G --data-urlencode "iss=${ISSUER}" --data-urlencode "target_link_uri=${TARGET_URL}" --data-urlencode "x_csrf=${CSRF}" ${REDIRECT_URI} | grep_location_header_value`
  echo " [${BEHAVIOR}] send authentication request to OP..."
  POST_DATA=`echo ${FLAGS} -i | xargs curl "${REQUEST}" | grep_location_header_value`
  echo " [${BEHAVIOR}] return authentication response to RP..."
  RESULT=`echo ${FLAGS} | xargs curl -L -d "${POST_DATA}&response_mode=fragment" ${REDIRECT_URI}`
  echo " [${BEHAVIOR}] parsing result..."
  echo "${RESULT}" | grep -q "\[Cookie\] => mod_auth_openidc_session="
}

