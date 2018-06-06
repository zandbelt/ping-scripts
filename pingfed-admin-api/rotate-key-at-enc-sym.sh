#!/bin/bash
###########################################################################
# Copyright (C) 2018 ZmartZone IAM
# Author: Hans Zandbelt <hzandbelt@zmartzone.eu
###########################################################################

#
# Rotate symmetric encryption key in a token manager instance
#
# NB: one should align the token lifetime with the frequency that this script runs

# PREREQS:
# - system utilities: bash curl jq openssl
# - TOKEN_MANAGER_ID is an existing JWT token manager instance and a suitable encryption key + algorithm was already configured, seel also KEY_SIZE

TOKEN_MANAGER_ID="jwt"

PF_HOST_PORT="localhost:9999"
PF_CREDS="administrator:2Federate"

# names of the rotating keys
KEY_ID_ONE="rot1"
KEY_ID_TWO="rot2"

# for 256 bit algorithms like AES-CBC-128 HMAC-SHA-256
KEY_SIZE="32"

#
# should not need to modify below 
#
CURL_FLAGS="-s -S -k -H \"X-XSRF-Header: pingfed\" -H \"Content-Type: application/json\" -u \"${PF_CREDS}\""
API_URL="https://${PF_HOST_PORT}/pf-admin-api/v1/oauth/accessTokenManagers"

CUR_DATA=`echo "${CURL_FLAGS}" | xargs curl "${API_URL}/${TOKEN_MANAGER_ID}"` || exit -1
KEY_ID_CUR=`jq -r ".configuration.fields | (map(select(.name==\"Active Symmetric Encryption Key ID\") | .value) | .[0])" <(echo ${CUR_DATA})`
KEY_ID=`[[ "${KEY_ID_CUR}" == "${KEY_ID_ONE}" ]] && echo "${KEY_ID_TWO}" || echo "${KEY_ID_ONE}"`

function make_sure_key_exists() {
	local KID="$1"
	local KVAL=$(openssl rand -hex ${KEY_SIZE})
	if ! jq -e ".configuration.tables | (map(select(.name==\"Symmetric Keys\") | (.rows | map(.fields | (map(select(.name == \"Key ID\" and .value == \"${KID}\"))))))) | flatten | any" <(echo ${CUR_DATA}) >/dev/null ; then
		#echo "create new key: ${KID}"
		DATA=$(jq ".configuration.tables |= (map(select(.name==\"Symmetric Keys\") |= (.rows |= . + [ { \"fields\":  [ { \"name\": \"Key ID\", \"value\": \"${KID}\" }, { \"name\": \"Key\", \"value\": \"${KVAL}\" } ] } ] )))" <(echo ${CUR_DATA}))
	else
		#echo "existing key: ${KID}"
		DATA="${CUR_DATA}"
	fi
	CUR_DATA="${DATA}"
}

make_sure_key_exists "${KEY_ID_ONE}"
make_sure_key_exists "${KEY_ID_TWO}"

# update new key value
# KVAL="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
# VAL=`hexdump -n 32 -e '8/4 "%08X" 1 "\n"' /dev/random`
KVAL=$(openssl rand -hex ${KEY_SIZE})
UPD_DATA=`jq ".configuration.tables |= (map(select(.name==\"Symmetric Keys\") |= (.rows |= map(.fields |= (map(select(.name == \"Key ID\" and .value == \"${KEY_ID}}\") = .) | (map(select(.name == \"Key\") |= (.value=\"${KVAL}\") | del(.encryptedValue)))))))) " <(echo ${CUR_DATA})`

# update active key
UPD_DATA=`jq ".configuration.fields |= (map(select(.name==\"Active Symmetric Encryption Key ID\") |= (.value=\"${KEY_ID}\"))) " <(echo ${CUR_DATA})`

# push the new token manager configuration to PingFederate
NEW_DATA=`echo "${CURL_FLAGS}" | xargs curl -X PUT -d "${UPD_DATA}" "${API_URL}/${TOKEN_MANAGER_ID}"` || exit -1

jq '.' <(echo ${NEW_DATA})
