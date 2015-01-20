#!/bin/sh
###########################################################################
# Copyright (C) 2014-2015 Ping Identity Corporation
# All rights reserved.
#
# For further information please contact:
#
# Ping Identity Corporation
# 1099 18th St Suite 2950
# Denver, CO 80202
# 303.468.2900
#       http://www.pingidentity.com
#
# DISCLAIMER OF WARRANTIES:
#
# THE SOFTWARE PROVIDED HEREUNDER IS PROVIDED ON AN "AS IS" BASIS, WITHOUT
# ANY WARRANTIES OR REPRESENTATIONS EXPRESS, IMPLIED OR STATUTORY; INCLUDING,
# WITHOUT LIMITATION, WARRANTIES OF QUALITY, PERFORMANCE, NONINFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.  NOR ARE THERE ANY
# WARRANTIES CREATED BY A COURSE OR DEALING, COURSE OF PERFORMANCE OR TRADE
# USAGE.  FURTHERMORE, THERE ARE NO WARRANTIES THAT THE SOFTWARE WILL MEET
# YOUR NEEDS OR BE FREE FROM ERRORS, OR THAT THE OPERATION OF THE SOFTWARE
# WILL BE UNINTERRUPTED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###########################################################################
#
# Author: Hans Zandbelt <hzandbelt@pingidentity.com>
#
# A Bash shell script to import (or delete from) PingFederate a set of
# connections specified in an XML metadata file.
#
# TODO: expired certificates are refused -> PF/API feature request?
# TODO: cert order/labeling on (templated) create and update
# TODO: double-check error handling (return/exit depending on calling in subshell)
# 
##########################################################################

ADMIN_CREDS="administrator:2Federate"
PF_HOSTPORT="localhost:9999"

CURL_OPTS="-s -S -k"

TMP_ENTITIES="/tmp/entities.xml"
TMP_ENTITY="/tmp/entity.xml"

function print_usage() {
	MSG=$1
	echo "Usage: $0 [-u <admin-user>:<admin-pwd>] [-s <admin-host>:<admin-port>] [-c <metadata-signing-cert>] [-t <template-connection-entity-id>] <metadata-url> create|delete|update "
	if [[ -n ${MSG} ]] ; then echo " # ERROR: ${MSG}"; fi
	exit 1
}

function utility_check() {
	BIN=`which $1`
	if [[ -z ${BIN} ]] ; then
		echo " # ERROR: required utility $1 is missing: install it first."
		exit 1
	fi
	echo "${BIN}"
}

# assuming echo and cat and cut exist
CURL_BIN=`utility_check curl`
XMLLINT_BIN=`utility_check xmllint`
JQ_BIN=`utility_check jq`
GREP_BIN=`utility_check grep`
SED_BIN=`utility_check sed`
OPENSSL_BIN=`utility_check openssl`

while getopts ":c:t:u:s:" opt; do
	case $opt in
		c)
			CERT=${OPTARG}
			;;
		t)
			TEMPLATE_ENTITY_ID=${OPTARG}
			;;
		u)
			ADMIN_CREDS=${OPTARG}
			;;
		s)
			PF_HOSTPORT=${OPTARG}
			;;			
		\?)
			print_usage "invalid option: -$OPTARG"
			;;
    	:)
    		print_usage "option -$OPTARG requires an argument."
		;;
	esac
done

shift $((OPTIND-1))

if [ $# -lt 2 ] ; then print_usage; fi

METADATA_URL=$1

ACTION=$2
if [[ ${ACTION} != "create"  && ${ACTION} != "update" && ${ACTION} != "delete" ]] ; then
	print_usage "unsupported action \"${ACTION}\""
fi

if [[ -z ${TEMPLATE_ENTITY_ID} && ${ACTION} == "create" ]] ; then
	print_usage "action \"${ACTION}\" requires the option \"-t <template-connection-entity-id>\""
fi

echo " # INFO: retrieving metadata file"
${CURL_BIN} -# ${METADATA_URL} -o ${TMP_ENTITIES}
if [[ $? -ne 0 ]] ; then
	echo " # ERROR: could not retrieve metadata file from URL: $1!"
	exit 1
fi

# see if we need to verify the signature on the XML file because a certificate was provided
if [[ -n ${CERT} ]] ; then
	XMLSEC=`utility_check xmlsec1`
	if "${XMLSEC}" verify --id-attr:ID "urn:oasis:names:tc:SAML:2.0:metadata:EntitiesDescriptor" --pubkey-cert-pem ${CERT} ${TMP_ENTITIES} 2>/dev/null ; then
		echo "Successfully verified the signature on the metadata file."
	else
		echo " # ERROR: signature verification on the metadata file failed!"
		exit 1
	fi
else
	echo " #"
	echo " # WARNING: No certificate was provided so signature(s) on the metadata will not be verified!"
	echo " # WARNING: Use the -c option to provide a verification certificate, otherwise you must ensure"
	echo " # WARNING: that you've verified the source of the metadata in some other way!"
	echo " #"
fi

# execute an xmllint command, optionally filtered
function exec_xmllint() {
	local XMLFILE=$1
	local CMD="setns md=urn:oasis:names:tc:SAML:2.0:metadata\n${2}"
	local FILTER=$3

	if [ -z "${FILTER}" ] ; then
		echo "${CMD}" | "${XMLLINT_BIN}" --shell "${XMLFILE}"
	else
		echo "${CMD}" | "${XMLLINT_BIN}" --shell "${XMLFILE}" | "${GREP_BIN}" "${FILTER}"
	fi
}

# perform a request to the Admin API
function api_request() {
	local PATH=$1
	local METHOD="GET"
	if [ ! -z "$2" ] ; then
		METHOD=$2
	fi
	if [ ! -z "$3" ] ; then
		JSON="$3"
		CONTENTTYPE="-H \"Content-type: application/json\""
	fi
	
	URL="https://${PF_HOSTPORT}/pf-admin-api/v1/${PATH}"	
	
	if [[ ${METHOD} == "GET" ]] ; then
		RESPONSE=`${CURL_BIN} ${CURL_OPTS} -u "${ADMIN_CREDS}" -H "X-XSRF-Header: dummy" ${URL}`
	else 
		RESPONSE=`${CURL_BIN} ${CURL_OPTS} -u "${ADMIN_CREDS}" -H "Content-type: application/json" -H "X-XSRF-Header: dummy" -X "${METHOD}" --data-binary "${JSON}" ${URL}`
	fi

	# NB: if there's an empty response the caller needs to deal with it...
	if [[ -z ${RESPONSE} ]] ; then
		exit 2
	fi
	
	if echo ${RESPONSE} | ${JQ_BIN} -e '.resultId' >/dev/null ; then
		printf "\n # ERROR: API request to ${URL} failed:\n" >&2
		echo "${RESPONSE}" | ${JQ_BIN} '.' >&2
		exit 1
	fi

	echo "${RESPONSE}"
}

# get the connection with the specified entity id from the (global) list of (JSON) connections retrieved from PF earlier
function conn_get_by_entityid() {
	local ENTITYID=$1
	echo "${GLOB_ALL_CONS}" | ${JQ_BIN} --arg entity ${ENTITYID} '.items[] | select(.entityId==$entity)'
}

# convert SAML 2.0 metadata XML to PF JSON connection description using the PF connectionMetadata/convert endpoint
function conn_xml_to_json {
	local XML_FILE=$1
	local TYPE=$2
	local TEMPLATE_CONN_JSON=$3

	# base64encode the entity descriptor XML
	B64XML=`cat ${XML_FILE} | ${OPENSSL_BIN} base64 -a -A`

	# assemble a request to convert XML to JSON and send it over the Admin API	
	REQ=`cat <<EOF
{
 "connectionType" : "${TYPE}",
 "expectedProtocol" : "SAML20",
 "samlMetadata" : "${B64XML}",
 "templateConnection" : ${TEMPLATE_CONN_JSON}
}
EOF`
	RESPONSE=`api_request connectionMetadata/convert POST "${REQ}"` || exit 1

	echo "${RESPONSE}"
}

# create a connection from an EntityDescriptor in an XML file using the Admin REST API
function conn_idp_create() {
	local FILE=$1
	local TEMPLATE_CONN_JSON=$2

	# convert the XML to a JSON connection description using the PF API
	RESPONSE=`conn_xml_to_json "${FILE}" "IDP" "${TEMPLATE_CONN_JSON}"` || exit 1

	# extract the attribute contract from the template connection (TODO: workaround because it gets lost??)
	CONTRACT=`echo ${TEMPLATE_CONN_JSON} | ${JQ_BIN} '.idpBrowserSso.attributeContract'`
	
	# assemble a connection create request 
	REQ=`echo "{ \"conn\": ${RESPONSE}, \"contract\": ${CONTRACT} }" | ${JQ_BIN} '.conn.connection.idpBrowserSso.attributeContract=.contract | .conn.connection | .name="[P] "+ .entityId | del(.credentials.signingSettings)'`

	# send the request over the Admin API
	# NB: do not exit if creation/validation fails
	RESPONSE=`api_request sp/idpConnections POST "${REQ}" > /dev/null` || return
	
	printf "OK\n"
}
	
# update a connection from an EntityDescriptor in an XML file using the Admin REST API
function conn_idp_update() {
	local FILE=$1
	local ENTITYID=$2

	# find the connection by its entityId in the list of all connections
	CONN=`conn_get_by_entityid "${ENTITYID}"`
	# see if we have a match
	if [ -z "${CONN}" ] ; then
		printf " [SKIP]\n"
		return
	fi

	# override the global template variables, since the template is now the existing connection
	TEMPLATE_CONN_JSON=`echo "${CONN}" | ${JQ_BIN} 'del(.credentials.certs)'`
	# extract the attribute contract from the template connection (TODO: workaround because it gets lost??)
	CONTRACT=`echo "${TEMPLATE_CONN_JSON}" | ${JQ_BIN} '.idpBrowserSso.attributeContract'`

	# convert the XML to a JSON connection description using the PF API
	RESPONSE=`conn_xml_to_json "${FILE}" "IDP" "${TEMPLATE_CONN_JSON}"` || exit 1

	# some hacking on the verification cert labels
	CERTS=`echo "${RESPONSE}" | ${JQ_BIN} '.connection.credentials.certs | if (. | length) > 1 then .[0].secondaryVerificationCert = true | .[1].primaryVerificationCert = true else . end'`
	# set/override the certs & contract in the PUT request
	REQ=`echo "{ \"conn\": ${RESPONSE}, \"contract\": ${CONTRACT}, \"certs\": ${CERTS} }" | ${JQ_BIN} '.conn.connection.idpBrowserSso.attributeContract=.contract | .conn.connection.credentials.certs=.certs | .conn.connection'`
	#REQ=`echo "{ \"conn\": ${RESPONSE}, \"contract\": ${CONTRACT} }" | ${JQ_BIN} '.conn.connection.idpBrowserSso.attributeContract=.contract | .conn.connection'`

	# assemble and send a connection update request over the Admin API
	ID=`echo "${CONN}" | ${JQ_BIN} -r '.id'`
	
	RESPONSE=`api_request "sp/idpConnections/${ID}" PUT "${REQ}" > /dev/null` || return

	printf "OK\n"
}

function conn_idp_delete() {
	local ENTITYID=$1
	
	# find the connection by its entityId in the list of all connections
	CONN=`conn_get_by_entityid "${ENTITYID}"`
	# see if we have a match
	if [ -z "${CONN}" ] ; then
		printf " [SKIP]\n"
		return
	fi
		
	# assemble and send a connection deactivation request over the Admin API
	ID=`echo "${CONN}" | ${JQ_BIN} -r '.id'`
	CONN=`echo "${CONN}" | ${JQ_BIN} '.active=false'`
	RESPONSE=`api_request sp/idpConnections/${ID} PUT "${CONN}"`

	# next send a connection delete request over the Admin API
	# NB: do not exit on suspicious responses
	RESPONSE=`api_request sp/idpConnections/${ID} "DELETE"`

	# should return HTTP 204 with an empty response, check that
	if [ -n "${RESPONSE}" ] ; then
		printf "ERROR\n"
		printf "${RESPONSE}\n"
		return
	fi

	printf " OK\n"
}

# count the number of EntityDescriptors
COUNT=`exec_xmllint "${TMP_ENTITIES}" "dir /md:EntitiesDescriptor/md:EntityDescriptor" "ELEMENT EntityDescriptor" | wc -l`

# get the list of all current connections from PingFederate
GLOB_ALL_CONS=`api_request sp/idpConnections` || (echo "ERROR: could not obtain list of connections from PingFederate" && exit 1)

# see if we need to obtain info about a template connection
if [[ $ACTION == "create" ]] ; then
	# find the template connection
	TEMPLATE_CONN_JSON=`conn_get_by_entityid "${TEMPLATE_ENTITY_ID}"`
	if [ -z "${TEMPLATE_CONN_JSON}" ] ; then
		echo "ERROR: template connection \"${TEMPLATE_ENTITY_ID}\" not found"
		exit 1
	fi
fi

# loop over the EntityDescriptors inside the EntitiesDescriptor
let i=1
while [ $i -le ${COUNT} ]; do

	# store the single entity descriptor in a temporary XML file
	exec_xmllint ${TMP_ENTITIES} "cat /md:EntitiesDescriptor/md:EntityDescriptor[$i]" | ${SED_BIN} '1d;$d' > ${TMP_ENTITY} || exit 1
	
	# grab the entityId	
	ENTITY_ID=`exec_xmllint ${TMP_ENTITY} "cat /md:EntityDescriptor/@entityID" "entityID" | cut -d"\"" -f2` || exit 1

	# print out which entity we are processing
	printf "[$i] : processing [${ENTITY_ID}] ..."

	# check if it is an IDP	
	if exec_xmllint ${TMP_ENTITY} "dir /md:EntityDescriptor/md:IDPSSODescriptor" "ELEMENT IDPSSODescriptor" >/dev/null ; then 

		printf " [IDP] "

		# check if it is a SAML 2.0 descriptor
		if exec_xmllint ${TMP_ENTITY} "cat /md:EntityDescriptor/md:IDPSSODescriptor/@protocolSupportEnumeration" "protocolSupportEnumeration" | ${GREP_BIN} "urn:oasis:names:tc:SAML:2.0:protocol" > /dev/null ; then

			case "${ACTION}" in
				"create")
					conn_idp_create "${TMP_ENTITY}" "${TEMPLATE_CONN_JSON}"
					;;
				"update")
					conn_idp_update "${TMP_ENTITY}" "${ENTITY_ID}"
					;;
				"delete")
					conn_idp_delete "${ENTITY_ID}"
					;;
				*)
					echo "ERROR: unsupported action: \"${ACTION}\""
					;;
			esac
		else
			printf " [UNSUPPORTED PROTOCOL]\n"
		fi
	else
		printf " [SP]\n"
	fi
	let i+=1
done
