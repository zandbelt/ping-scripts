#!/bin/sh

###########################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# Script used to do automated OpenID Connect Relying Party Certification
# Testing for the mod_auth_openidc OIDC RP implementation for Apache HTTPd.
# 
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
###########################################################################

# TODO:
# rp_token_endpoint_private_key_jwt
# rp_id_token_kid_absent_single_jwks
# rp_id_token_sig_enc

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
	rp_id_token_aud
	rp_id_token_bad_sig_es256
	rp_id_token_bad_sig_hs256
	rp_id_token_bad_sig_rs256
	rp_id_token_iat
	rp_id_token_issuer_mismatch
	rp_id_token_kid_absent_multiple_jwks
	rp_id_token_kid_absent_single_jwks
	rp_id_token_sig_enc
	rp_id_token_sig_none
	rp_id_token_sub
"

#	rp-discovery-webfinger-http-href
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
	printf " [" && date +"%D %T" | tr -d '\n' && printf "] " && printf "%s: %s ... " "${ID}" "${MSG}"
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
	echo ""
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
	echo ""
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
	# else it should be "nogrep" or "return"
}

function grep_location_header_value_result() {
	if [ $? -ne 0 ] ; then
		echo "ERROR: result is: \"${RESULT}\""
		exit
	fi
	RESULT=`echo "${RESULT}" | grep_location_header_value`
	if [ $? -ne 0 ] ; then
		echo "ERROR: could not parse Location header from: \"${RESULT}\""
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

	initiate_discovery ${TEST_ID} ${ACCT} "return"
	
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

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"response_type\" is set to \"code\""
	echo " * "

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"
		
	# check that the code is returned by the OP to the redirect URI"
	find_in_logfile "${TEST_ID}" "check response type" 150 "oidc_check_user_id: incoming request:" "&code="	
}

function rp_token_endpoint_client_secret_basic() {
	local TEST_ID="rp-token_endpoint-client_secret_basic"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_basic\""
	echo " * "		

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the token endpoint auth method is set to "client_secret_basic"
	find_in_logfile "${TEST_ID}" "check token endpoint auth method" 100 "oidc_proto_token_endpoint_request: token_endpoint_auth=client_secret_basic"

	# check that basic_auth is set to something other than "basic_auth=(null)"
	message "${TEST_ID}" "check basic auth" "-n"
	tail -n 100 ${LOG_FILE} | grep "oidc_util_http_call: url=${ISSUER}/token" | grep "grant_type=authorization_code" | grep -q "basic_auth=(null)" && { echo "ERROR: basic_auth found" && exit; } || echo "OK"
	
	# check that the response from the token endpoint call is successful
	find_in_logfile "${TEST_ID}" "check token exchange response" 100 "oidc_util_http_call: response={" "\"id_token\": "
}

function rp_token_endpoint_client_secret_post() {
	local TEST_ID="rp-token_endpoint-client_secret_post"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_post\""
	echo " * "		

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the token endpoint auth method is set to "client_secret_post"
	find_in_logfile "${TEST_ID}" "check token endpoint auth method" 100 "oidc_proto_token_endpoint_request: token_endpoint_auth=client_secret_post"

	# check that the client_secret is passed 
	find_in_logfile "${TEST_ID}" "check post auth" 100 "oidc_util_http_call: url=${ISSUER}/token" "client_secret="

	# check that the response from the token endpoint call is successful
	find_in_logfile "${TEST_ID}" "check token exchange response" 100 "oidc_util_http_call: response={" "\"id_token\": "
}

function  rp_token_endpoint_client_secret_jwt() {
	local TEST_ID="rp-token_endpoint-client_secret_jwt"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"client_secret_jwt\""
	echo " * "		

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the token endpoint auth method is set to "client_secret_jwt"
	find_in_logfile "${TEST_ID}" "check token endpoint auth method" 100 "oidc_proto_token_endpoint_request: token_endpoint_auth=client_secret_jwt"

	# check that the client_assertion is passed 
	find_in_logfile "${TEST_ID}" "check client assertion auth" 100 "oidc_util_http_call: url=${ISSUER}/token" "client_assertion="

	# check that the response from the token endpoint call is successful
	find_in_logfile "${TEST_ID}" "check token exchange response" 100 "oidc_util_http_call: response={" "\"id_token\": "		
}

function  rp_token_endpoint_private_key_jwt() {
	local TEST_ID="rp-token_endpoint-private_key_jwt"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"token_endpoint_auth\" is set to \"private_key_jwt\""
	echo " * "

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# check that the token endpoint auth method is set to "private_key_jwt"
	find_in_logfile "${TEST_ID}" "check token endpoint auth method" 100 "oidc_proto_token_endpoint_request: token_endpoint_auth=private_key_jwt"

	# check that the client_assertion is passed 
	find_in_logfile "${TEST_ID}" "check client assertion auth" 100 "oidc_util_http_call: url=${ISSUER}/token" "client_assertion="

	# check that the response from the token endpoint call is successful
	find_in_logfile "${TEST_ID}" "check token exchange response" 100 "oidc_util_http_call: response={" "\"id_token\": "
}

function rp_id_token_auth() {
	local TEST_ID="rp-id_token-aud"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}
		
	find_in_logfile "${TEST_ID}" "check aud mismatch" 10 "oidc_proto_validate_aud_and_azp: our configured client_id (" ") could not be found in the array of values for \"aud\" claim"
}

function rp_id_token_bad_sig_es256() {
	local TEST_ID="rp-id_token-bad-sig-es256"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"
		
	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check EC id_token" 25 "oidc_proto_parse_idtoken: successfully parsed" "\"alg\":\"ES256\""
	find_in_logfile "${TEST_ID}" "check EC signature mismatch" 10 "oidc_proto_jwt_verify: JWT signature verification failed" "_cjose_jws_verify_sig_ec"
}

function rp_id_token_bad_sig_hs256() {
	local TEST_ID="rp-id_token-bad-sig-hs256"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check HS id_token" 25 "oidc_proto_parse_idtoken: successfully parsed" "\"alg\":\"HS256\""
	find_in_logfile "${TEST_ID}" "check HS signature mismatch" 10 "oidc_proto_jwt_verify: JWT signature verification failed" "could not verify signature against any of the (1) provided keys"
}

function rp_id_token_bad_sig_rs256() {
	local TEST_ID="rp-id_token-bad-sig-rs256"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check RS id_token" 25 "oidc_proto_parse_idtoken: successfully parsed" "\"alg\":\"RS256\""
	find_in_logfile "${TEST_ID}" "check RS signature mismatch" 10 "oidc_proto_jwt_verify: JWT signature verification failed" "_cjose_jws_verify_sig_rs"
}

function rp_id_token_iat() {
	local TEST_ID="rp-id_token-iat"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check missing iat" 25 "oidc_proto_validate_iat: JWT did not contain an \"iat\" number value"
	find_in_logfile "${TEST_ID}" "check abort" 25 "oidc_proto_parse_idtoken: id_token payload could not be validated, aborting"
}

function rp_id_token_issuer_mismatch() {
	local TEST_ID="rp-id_token-issuer-mismatch"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check issuer mismatch" 25 "oidc_proto_validate_jwt: requested issuer (${ISSUER}) does not match received \"iss\" value in id_token (https://example.org/)"
	find_in_logfile "${TEST_ID}" "check abort" 25 "oidc_proto_parse_idtoken: id_token payload could not be validated, aborting"
}

function rp_id_token_kid_absent_multiple_jwks() {
	local TEST_ID="rp-id_token-kid-absent-multiple-jwks"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}

	find_in_logfile "${TEST_ID}" "check missing JWK" 25 "oidc_proto_jwt_verify: JWT signature verification failed" "could not verify signature against any of the"
	find_in_logfile "${TEST_ID}" "check abort" 25 "oidc_proto_parse_idtoken: id_token signature could not be validated, aborting"
}

function rp_id_token_kid_absent_single_jwks() {
	local TEST_ID="rp-id_token-kid-absent-single-jwks"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# TODO: search for successful validation using one key without a "kid"
	find_in_logfile "${TEST_ID}" "check missing kid" 100 "blabla"
}

function rp_id_token_sig_enc() {
	local TEST_ID="rp-id_token-sig+enc"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	echo " * "
	echo " * [server] prerequisite: .conf exists and \"id_token_encrypted_response_alg\" is set to e.g. \"A128KW\""
	echo " * [server] prerequisite: .conf exists and \"id_token_encrypted_response_enc\" is set to e.g. \"A256CBC-HS512\""
	echo " * "

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

}

function rp_id_token_sig_none() {
	local TEST_ID="rp-id_token-sig-none"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	# test a regular flow up until successful authenticated application access
	regular_flow "${TEST_ID}"

	# make sure we were using the code flow
	find_in_logfile "${TEST_ID}" "check code flow" 100 "oidc_util_http_post_form: post data=\"grant_type=authorization_code&code="
	# make sure the id_token has alg "none" set
	find_in_logfile "${TEST_ID}" "check alg none" 100 "oidc_proto_parse_idtoken: successfully parsed" "JWT with header={\"alg\":\"none\"}"
	# check that we finished id_token validation succesfully
	find_in_logfile "${TEST_ID}" "check valid id_token" 100 "oidc_proto_parse_idtoken: valid id_token for user"
}

function rp_id_token_sub() {
	local TEST_ID="rp-id_token-sub"
	local ISSUER="${RP_TEST_URL}/${RP_ID}/${TEST_ID}"

	initiate_discovery ${TEST_ID} ${ISSUER}
	send_authentication_request ${TEST_ID} ${RESULT}
	send_authentication_response ${TEST_ID} ${RESULT}
	
	find_in_logfile "${TEST_ID}" "check missing sub" 25 "oidc_proto_validate_idtoken: id_token JSON payload did not contain the required-by-spec \"sub\" string value"
	find_in_logfile "${TEST_ID}" "check abort" 25 "oidc_proto_parse_idtoken: id_token payload could not be validated, aborting"
}

function execute_test() {
	local TEST_ID="${1}"
	
	echo "  # ${TEST_ID}"
	echo ""
	eval "${TEST_ID}"
	echo ""
}

exec_init $1

if [ $1 != "all" ] ; then
		execute_test "${1}"
else
	for TEST_ID in $TESTS; do
		execute_test "${TEST_ID}"
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

