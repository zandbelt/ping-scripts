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
LOG_FILE="<YOUR-APACHE-ERROR-LOGFILE-WITH-DEBUG-MESSAGES>"

SETENV="$(dirname "$0")/setenv.sh"
if [[ -x "${SETENV}" ]]; then
	source "${SETENV}"
fi

RP_TEST_URL="https://rp.certification.openid.net:8080"
COOKIE_JAR="/tmp/cookie.jar"
FLAGS="-s -k -b ${COOKIE_JAR} -c ${COOKIE_JAR}"

TESTS="
	rp_discovery_issuer_not_matching_config
	rp_discovery_jwks_uri_keys
	rp_discovery_openid_configuration
	rp_discovery_webfinger_acct
	rp_discovery_webfinger_unknown_member
	rp_discovery_webfinger_url
	rp_registration_dynamic
	rp_response_type_code
	rp_token_endpoint_client_secret_basic
	rp_token_endpoint_client_secret_post
	rp_token_endpoint_client_secret_jwt
	rp_token_endpoint_private_key_jwt
"

#	rp-discovery-webfinger-http-href
#	rp-id_token-aud
#	rp-id_token-bad-sig-es256
#	rp-id_token-bad-sig-hs256
#	rp-id_token-bad-sig-rs256
#	rp-id_token-iat
#	rp-id_token-issuer-mismatch
#	rp-id_token-kid-absent-multiple-jwks
#	rp-id_token-kid-absent-single-jwks
#	rp-id_token-sig+enc
#	rp-id_token-sig-none
#	rp-id_token-sub
#	rp-claims_request-id_token
#	rp-claims_request-userinfo
#	rp-request_uri-enc
#	rp-request_uri-sig
#	rp-request_uri-sig+enc
#	rp-request_uri-unsigned
#	rp-scope-userinfo-claims
#	rp-key-rotation-op-enc-key
#	rp-key-rotation-op-sign-key
#	rp-key-rotation-rp-enc-key
#	rp-key-rotation-rp-sign-key
#	rp-userinfo-bad-sub-claim
#	rp-userinfo-bearer-body
#	rp-userinfo-bearer-header
#	rp-userinfo-enc
#	rp-userinfo-sig
#	rp-userinfo-sig+enc	

if [ -z $1 ] ; then
  echo
  echo "Usage: ${0} [all|${TESTS}]"
  echo
  exit
fi

# printout a test message
function message() {
	local ID=$1
	local MSG=$2
	local PARAM=$3
	printf " [" && date +"%D %T" | tr -d '\n' && printf "] " && printf "%s: %s..." "${ID}" "${MSG}"
	if [ "$PARAM" != "-n" ] ; then
		printf "\n"
	fi
}

# parse the location header value out of a curl -i response
function grep_location_header_value() {
	grep -i "Location:" | cut -d" " -f2 | tr -d '\r' | cut -d"#" -f2
	return $?
}

# find a pattern in the Apache log file
function find_in_logfile() {
	local TEST_ID=$1
	local MESSAGE=$2
	local NUMBER=$3
	local MATCH=$4
	local MATCH2=$5
	
	message "${TEST_ID}" "${MESSAGE}" "-n"
	if [ -z "${MATCH2}" ] ; then
		tail -n ${NUMBER} ${LOG_FILE} | grep -q "${MATCH}" && echo "OK" || { printf "ERROR:\n could not find \"%s\" in logfile\n" "${MATCH}" && exit; }
	else
		tail -n ${NUMBER} ${LOG_FILE} | grep "${MATCH}" | grep -q "${MATCH2}" && echo "OK" || { printf "ERROR:\n could not find \"%s\" and \"%s\" in logfile\n" "${MATCH}" "${MATCH2}" && exit; }
	fi
}

# create CSRF token to be supplied on subsequent calls
function exec_init() {
	local TEST_ID=$1
	message ${TEST_ID} "initiate CSRF" "-n"
	local RESPONSE=`echo ${FLAGS} -j | xargs curl ${TARGET_URL}`
	if [ $? -ne 0 ] ; then
		echo "ERROR"
		exit
	fi
	CSRF=`echo "${RESPONSE}" | grep hidden | grep x_csrf | cut -d"\"" -f6`
	if [ $? -ne 0 ] ; then
		echo "ERROR"
		exit
	else
		echo "OK"
	fi
}

# call the RP endpoint (=mod_auth_openidc's redirect URI) to kick off discovery and/or SSO
function initiate_discovery() {
	local TEST_ID=$1
	local ISSUER=$2
	local RESULT_PARAM=$3

	message "${TEST_ID}" "initiate Discovery" "-n"
	RESULT=`echo ${FLAGS} -i | xargs curl -G --data-urlencode "iss=${ISSUER}" --data-urlencode "target_link_uri=${TARGET_URL}" --data-urlencode "x_csrf=${CSRF}" ${REDIRECT_URI}`
	if [ $? -ne 0 ] ; then
		echo "ERROR"
		exit
	fi

	if [ "${RESULT_PARAM}" != "nogrep" ] ; then
		RESULT=`echo "${RESULT}" | grep_location_header_value`
		if [ $? -ne 0 ] ; then
			echo "ERROR"
			exit
		fi		
	fi

	if [ -z "${RESULT_PARAM}" ] ; then
		echo "OK"
	elif [ "${RESULT_PARAM}" == "authorization" ] ; then
		echo "${RESULT}" | grep -q "${RP_TEST_URL}/${RP_ID}/${TEST_ID}/authorization" && echo "OK" || echo "ERROR"
	fi
	# else it should be "nogrep"
}

function grep_location_header_value_result() {
	if [ $? -ne 0 ] ; then
		echo "ERROR"
		exit
	fi
	RESULT=`echo "${RESULT}" | grep_location_header_value`
	if [ $? -ne 0 ] ; then
		echo "ERROR"
		exit
	else
		echo "OK"
	fi
}

# send an authentication request (passed in $2) to the OP
function send_authentication_request() {
	local TEST_ID=$1
	local REQUEST=$2
	
	message "${TEST_ID}" "send authentication request to OP" "-n"
	RESULT=`echo ${FLAGS} -i | xargs curl "${REQUEST}"` 
	grep_location_header_value_result
}

# send an authentication response (passed in $2) to the RP
function send_authentication_response() {
	local TEST_ID=$1
	local RESPONSE=$2
		
	message ${TEST_ID} "return authentication response to RP" "-n"
	RESULT=`echo ${FLAGS} -i | xargs curl "${RESPONSE}"`
	grep_location_header_value_result
}

# access the original URL that is passed in $2 (after authentication has succeeded)
function application_access() {
	local TEST_ID=$1
	local RETURN=$2

	message ${TEST_ID} "access application as authenticated user" "-n"
	RESULT=`echo ${FLAGS} | xargs curl "${RETURN}"`
	MATCH="\[OIDC_CLAIM_sub\]"
	echo "${RESULT}" | grep -q "${MATCH}" && echo "OK" || { printf "ERROR:\n could not find \"%s\" in client HTML output:\n%s\n" "${MATCH}" "${RESULT}" && exit; }
}

# go through a regular flow from discovery to authenticated application access
function regular_flow() {
	local TEST_ID=$1
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}
	application_access ${TEST_ID} ${RESULT}
}

################################################
# the RP certification tests, one per function #
################################################

function rp_discovery_issuer_not_matching_config() {
	local TEST_ID="rp-discovery-issuer-not-matching-config"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery "${TEST_ID}" "${ISSUER}" "nogrep"
	MATCH="Could not find valid provider metadata"
	echo "${RESULT}" | grep -q "${MATCH}" && echo "OK" || { printf "ERROR:\n could not find \"%s\" in client HTML output:\n%s\n" "${MATCH}" "${RESULT}" && exit; }

	# make sure that we've got the right error message in the error log
	WRONG_ISSUER="https://example.com"
	find_in_logfile "${TEST_ID}" "check issuer mismatch error message" 10 "requested issuer (${ISSUER}) does not match the \"issuer\" value in the provider metadata file: ${WRONG_ISSUER}"
}

function rp_discovery_jwks_uri_keys() {
	local TEST_ID="rp-discovery-jwks_uri-keys"
	
	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# make sure that we've validated and id_token correctly with the jwks discovered on the jwks_uri
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	find_in_logfile "${TEST_ID}" "check id_token parse result" 100 "oidc_proto_parse_idtoken: successfully parsed" "\"iss\": \"${ISSUER}\""
	local KID="a1"
	find_in_logfile "${TEST_ID}" "check JWK retrieval by \"kid\"" 100 "oidc_proto_get_key_from_jwks: found matching kid: \"${KID}\""
	local ALG="RS256"
	find_in_logfile "${TEST_ID}" "check id_token verification" 100 "oidc_proto_jwt_verify: JWT signature verification with algorithm \"${ALG}\" was successful"
}

function rp_discovery_openid_configuration() {
	local TEST_ID="rp-discovery-openid-configuration"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	# check that the authentication request is initiated to the discovered authorization endpoint
	initiate_discovery "${TEST_ID}" "${ISSUER}" "authorization"

	# check that the registration is initiated to the discovered endpoint: ${RP_ID}/${TEST_ID}/registration"
	# TODO: can only do this if the .provider file was cleaned up beforehand
	#find_in_logfile "${TEST_ID}" "check registration request" 50 "oidc_util_http_get: get URL=\"${URL}\""
}

function rp_discovery_webfinger_acct() {
	local TEST_ID="rp-discovery-webfinger-acct"
	local DOMAIN=`echo ${RP_TEST_URL} | cut -d"/" -f3`
	local ACCT="${RP_ID}.${TEST_ID}@${DOMAIN}"

	initiate_discovery ${TEST_ID} ${ACCT}
	
	# check that the authentication request contains a login_hint parameter set to the acct: value
	echo ${RESULT} | grep -q "&login_hint=${RP_ID}" && echo "OK" || echo "ERROR"

	# check that the webfinger request contains acct:"
	URL="${RP_TEST_URL}/.well-known/webfinger?resource=acct%3A${RP_ID}.${TEST_ID}%40rp.certification.openid.net%3A8080&rel=http%3A%2F%2Fopenid.net%2Fspecs%2Fconnect%2F1.0%2Fissuer"
	find_in_logfile "${TEST_ID}" "check webfinger request" 50 "oidc_util_http_get: get URL=\"${URL}\""
	# check that the webfinger request contains the right issuer:"
	find_in_logfile "${TEST_ID}" "check webfinger issuer result" 50 "oidc_proto_account_based_discovery: returning issuer \"https://rp.certification.openid.net:8080/mod_auth_openidc/rp-discovery-webfinger-acct\" for account \"${ACCT}\" after doing successful webfinger-based discovery"
}

function rp_discovery_webfinger_unknown_member() {
	local TEST_ID="rp-discovery-webfinger-unknown-member"
	local DOMAIN=`echo ${RP_TEST_URL} | cut -d"/" -f3`
	local ACCT="${RP_ID}.${TEST_ID}@${DOMAIN}"

	# check that the authentication request is initiated to the discovered authorization endpoint
	initiate_discovery "${TEST_ID}" "${ACCT}" "authorization"

	# check that the webfinger request contains acct:
	URL="${RP_TEST_URL}/.well-known/webfinger?resource=acct%3A${RP_ID}.${TEST_ID}%40rp.certification.openid.net%3A8080&rel=http%3A%2F%2Fopenid.net%2Fspecs%2Fconnect%2F1.0%2Fissuer"
	find_in_logfile "${TEST_ID}" "check webfinger request" 50 "oidc_util_http_get: get URL=\"${URL}\""
	# check that the response contains \"dummy\": \"foobar\""
	find_in_logfile "${TEST_ID}" "check webfinger response" 50 "oidc_util_http_call: response=" "\"dummy\": \"foobar\""
}

function rp_discovery_webfinger_url() {
	local TEST_ID="rp-discovery-webfinger-url"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
		
	# check that the authentication request is initiated to the discovered authorization endpoint
	initiate_discovery "${TEST_ID}" "${ISSUER}" "authorization"

	# check that the registration is initiated to the discovered endpoint: ${RP_ID}/${TEST_ID}/registration"				
	echo " * "
	echo " * [TODO] mod_auth_openidc does not support URL user syntax"
	echo " * "
}

function rp_registration_dynamic() {
	local TEST_ID="rp-registration-dynamic"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	# check that the authentication request is initiated to the discovered authorization endpoint
	initiate_discovery "${TEST_ID}" "${ISSUER}" "authorization"

	# TODO: only when .client file is cleaned up
	# check that the registration is initiated and a successful client registration response is returned"
}

function rp_response_type_code() {
	local TEST_ID="rp-response_type-code"

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"
		
	# check that the code is returned by the OP to the redirect URI"
	find_in_logfile "${TEST_ID}" "check response type" 150 "oidc_check_user_id: incoming request:" "&code="
	
	echo " * "
	echo " * [server] prerequisite: .conf exists and \"response_type\" is set to \"code\""
	echo " * "
}


function rp_token_endpoint_client_secret_basic() {
	local TEST_ID="rp-token_endpoint-client_secret_basic"

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the client was registered with \"token_endpoint_auth_method\" set to \"client_secret_basic\"
	# check that the code is exchanged at the OP with a \"basic_auth\" value passed to the \"oidc_util_http_call\" function
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	find_in_logfile "${TEST_ID}" "check code exchange" 100 "oidc_util_http_call: url=${ISSUER}/token" "grant_type=authorization_code"

	# TODO: check that basic_auth is not "basic_auth=(null)"
	message "${TEST_ID}" "check basic auth" "-n"
	tail -n 100 ${LOG_FILE} | grep "oidc_util_http_call: url=${ISSUER}/token" | grep "grant_type=authorization_code" | grep -q -v "basic_auth=(null)" && echo "OK" || echo "ERROR: basic_auth not found"
	
	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_basic\""
	echo " * "		
}

function rp_token_endpoint_client_secret_post() {
	local TEST_ID="rp-token_endpoint-client_secret_post"

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the client was registered with \"token_endpoint_auth_method\" set to \"client_secret_post\"
	# check that the code is exchanged at the OP with a \"basic_auth=(null)\" and a \"client_id\" and \"client_secret\" value passed 
	# as POST parameters to the \"oidc_util_http_call\" function
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
	find_in_logfile "${TEST_ID}" "check code exchange" 100 "oidc_util_http_call: url=${ISSUER}/token" "grant_type=authorization_code"

	message "${TEST_ID}" "check POST auth" "-n"
	tail -n 100 ${LOG_FILE} | grep "oidc_util_http_call: url=${ISSUER}/token" | grep "grant_type=authorization_code" | grep "content_type=application/x-www-form-urlencoded" | grep "basic_auth=(null)" | grep "client_id=" | grep -q "client_secret=" && echo "OK" || echo "ERROR: POST authentication not found"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_post\""
	echo " * "		
}

function  rp_token_endpoint_client_secret_jwt() {
	regular_flow "rp-token_endpoint-client_secret_jwt"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_jwt\""
	echo " * [server] check that the client was registered with \"token_endpoint_auth_method\" set to \"client_secret_jwt\""
	echo " * [server] check that the code is exchanged at the OP with a \"client_assertion\" passed to the \"oidc_util_http_call\" function as a POST parameter"
	echo " * [client] check that access the to application is granted as an authenticated user (\"OK\")"
	echo " * "		
}

function  rp_token_endpoint_private_key_jwt() {
	regular_flow "rp-token_endpoint-private_key_jwt"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"private_key_jwt\""
	echo " * [server] check that the client was registered with \"token_endpoint_auth_method\" set to \"private_key_jwt\""
	echo " * [server] check that the code is exchanged at the OP with a \"client_assertion\" passed to the \"oidc_util_http_call\" function as a POST parameter"
	echo " * [client] check that access the to application is granted as an authenticated user (\"OK\")"
	echo " * "		
}

exec_init $1

if [ $1 != "all" ] ; then
	eval $1
else
	for TEST_ID in $TESTS; do
		eval $TEST_ID
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

