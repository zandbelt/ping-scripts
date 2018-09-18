#!/bin/sh

###########################################################################
# Copyright (C) 2018 ZmartZone IAM
#
# Demonstrate the authorization code flow from the commandline using cURL.
#  
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
###########################################################################

# PREREQS:
# - system utilities: bash curl openssl jq
# - OAuth 2.0 Playground is installed on/next to PingFederate

SCOPES="openid edit admin"

BASE_URL="https://localhost:9031"
USERNAME=joe
PASSWORD=2Federate

REDIRECT_URI="${BASE_URL}/OAuthPlayground/authorization_code/oidc/callback"
CLIENT_ID="ac_oic_client"
CLIENT_SECRET="abc123DEFghijklmnop4567rstuvwxyzZYXWUT8910SRQPOnmlijhoauthplaygroundapplication"

AUTHZ_ENDPOINT="${BASE_URL}/as/authorization.oauth2"
TOKEN_ENDPOINT="${BASE_URL}/as/token.oauth2"
#TOKEN_ENDPOINT="${BASE_URL}/wrap/as/token.oauth2"
#TOKEN_ENDPOINT="${BASE_URL}/wrap/rest/as/token.oauth2"

FLAGS="-s -k -b /tmp/cookie.jar -c /tmp/cookie.jar"
STATE=$(openssl rand -hex 4)
#echo "${STATE}"

LOGIN_HTML=$(echo "${FLAGS}" | xargs curl -G --data-urlencode "client_id=${CLIENT_ID}" --data-urlencode "response_type=code" --data-urlencode "scope=${SCOPES}" --data-urlencode "redirect_uri=${REDIRECT_URI}" --data-urlencode "state=${STATE}" "${AUTHZ_ENDPOINT}")
#echo "login html: ${LOGIN_HTML}"

RESUME_PATH=$(echo "${LOGIN_HTML}" | grep "action=" | cut -d"=" -f3 | cut -d"\"" -f2)
#echo "resume path: ${RESUME_PATH}"

RESUME_URL="${BASE_URL}${RESUME_PATH}"
#echo "resume URL: ${RESUME_URL}"

CONSENT_HTML=$(echo "${FLAGS}" | xargs curl -d "pf.username=${USERNAME}" -d "pf.pass=${PASSWORD}" "${RESUME_URL}")
#echo "consent html: ${CONSENT_HTML}"

CSRF_TOKEN=$(echo "${CONSENT_HTML}" | grep cSRFToken | cut -d"=" -f4 | cut -d"\"" -f2)
#echo "CSRF token: ${CSRF_TOKEN}"

SCOPES_FORM_POST=""
for scope in ${SCOPES} ; do
 SCOPES_FORM_POST="${SCOPES_FORM_POST} -d \"scope=${scope}\""
done
#echo "${SCOPES_FORM_POST}" 

HEADERS=$(echo "${FLAGS} ${SCOPES_FORM_POST}" | xargs curl -D - -o /dev/null -d "check-user-approved-scope=true" -d "cSRFToken=${CSRF_TOKEN}" -d "pf.oauth.authz.consent=allow" "${RESUME_URL}")
#echo "headers: ${HEADERS}"

CODE=$(echo "${HEADERS}" | grep "Location:" | cut -d"=" -f2 | cut -d"&" -f1)
#echo "code: ${CODE}" 

TOKEN_RESPONSE=$(echo "${FLAGS}" | xargs curl -d "grant_type=authorization_code" -d "client_id=${CLIENT_ID}" -d "redirect_uri=${REDIRECT_URI}" -d "client_secret=${CLIENT_SECRET}" -d "state=${STATE}" -d "code=${CODE}" "${TOKEN_ENDPOINT}")
echo "${TOKEN_RESPONSE}" | jq '.'

