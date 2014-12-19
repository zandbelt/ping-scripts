#!/bin/sh
###########################################################################
# Copyright (C) 2014 Ping Identity Corporation
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
##########################################################################

ADMIN_CREDS="administrator:2Federate"
PF_HOSTPORT="localhost:9999"

CURL_OPTS="-s -k"

TMP1="/tmp/entities.xml"
TMP2="/tmp/entity.xml"

print_usage() {
	MSG=$1
	echo "Usage: $0 [-u <admin-user>:<admin-pwd>] [-s <admin-host>:<admin-port>] [-c <metadata-signing-cert>] [-t <template-connection-entity-id>] <metadata-url> create|delete "
	if [[ -n ${MSG} ]] ; then echo " # ERROR: ${MSG}"; fi
	exit 1
}

utility_check() {
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
			TEMPLATE=${OPTARG}
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
if [[ ${ACTION} != "create" && ${ACTION} != "delete" ]] ; then
	print_usage "unsupported action \"${ACTION}\""
fi

if [[ -z ${TEMPLATE} && ${ACTION} == "create" ]] ; then
	print_usage "action \"${ACTION}\" requires the option \"-t <template-connection-entity-id>\""
fi

echo " # INFO: retrieving metadata file"
${CURL_BIN} -# ${METADATA_URL} -o ${TMP1}
if [[ $? -ne 0 ]] ; then
	echo " # ERROR: could not retrieve metadata file from URL: $1!"
	exit 1
fi

# see if we need to verify the signature on the XML file because a certificate was provided
if [[ -n ${CERT} ]] ; then
	XMLSEC=`utility_check xmlsec1`
	if "${XMLSEC}" verify --id-attr:ID "urn:oasis:names:tc:SAML:2.0:metadata:EntitiesDescriptor" --pubkey-cert-pem ${CERT} ${TMP1} 2>/dev/null ; then
		echo "Succesfully verified the signature on the metadatafile."
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
exec_xmllint() {
	local XMLFILE=$1
	local CMD=$2
	local FILTER=$3
	EXEC="echo \"setns md=urn:oasis:names:tc:SAML:2.0:metadata\n${CMD}\" | ${XMLLINT_BIN} --shell ${XMLFILE}"
	if [ ! -z "$1" ] ; then
		EXEC="${EXEC} | ${GREP_BIN} \"${FILTER}\""
	fi
	eval ${EXEC}
}

# create a JSON request object for the connectionMetadata/convert endpoint
create_convert_json() {
	local TYPE=$1
	local PROTO=$2
	local B64XML=$3
	cat <<HERE
{
  "connectionType" : "${TYPE}",
  "expectedProtocol" : "${PROTO}",
  "samlMetadata" : "${B64XML}",
  "templateConnection" : ${TEMPLATE_CONN}
}
HERE
}

# perform a request to the Admin API
api_request() {
	PATH=$1
	METHOD="GET"
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
		echo " # ERROR: API request to ${URL} failed:" >&2
		echo ${RESPONSE} >&2
		exit 1
	fi

	echo "${RESPONSE}"
}

# create a connection from an EntityDescriptor in an XML file using the Admin REST API
conn_idp_create() {
	local FILE=$1
	
	# base64encode the entity descriptor XML
	B64XML=`cat ${FILE} | ${OPENSSL_BIN} base64 -a -A`
				
	# assemble a request to convert XML to JSON and send it over the Admin API
	REQ=`create_convert_json "IDP" "SAML20" "${B64XML}"`
	RESPONSE=`api_request connectionMetadata/convert POST "${REQ}"` || exit

	# assemble a connection create request 
	REQ=`echo "{ \"conn\": ${RESPONSE}, \"contract\": ${CONTRACT} }" | ${JQ_BIN} '.conn.connection.idpBrowserSso.attributeContract=.contract | .conn.connection | .name="[P] "+ .entityId | del(.credentials.signingSettings)'`
					
	# send the request over the Admin API
	# NB: do not exit if creation/validation fails
	RESPONSE=`api_request sp/idpConnections POST "${REQ}"`

	printf "OK\n"
}
	
conn_idp_delete() {
	local ENTITYID=$1
	
	# find the connection by its entityId in the list of all connections
	CONN=`echo "${ALL_CONNS}" | ${JQ_BIN} --arg entity ${ENTITYID} '.items[] | select(.entityId==$entity)'`
					
	# see if we have a match
	if [ -z "${CONN}" ] ; then
		echo " [SKIP]\n"
		return
	fi
		
	# assemble and send a connection deactivation request over the Admin API
	ID=`echo "${CONN}" | ${JQ_BIN} -r '.id'`
	CONN=`echo "${CONN}" | ${JQ_BIN} '.active=false'`						
	RESPONSE=`api_request sp/idpConnections/${ID} PUT "${CONN}"` || exit
						
	# next send a connection delete request over the Admin API
	# NB: do not exit on suspicious responses
	RESPONSE=`api_request sp/idpConnections/${ID} "DELETE"`

	# should return HTTP 204 with an empty response, check that
	if [ -n "${RESPONSE}" ] ; then
		printf "ERROR\n"
		echo ${RESPONSE}
		exit
	fi

	printf " OK\n"
}

# count the number of EntityDescriptors
COUNT=`exec_xmllint "${TMP1}" "dir /md:EntitiesDescriptor/md:EntityDescriptor" "ELEMENT EntityDescriptor" | wc -l`

# get the list of all current connections from PingFederate
ALL_CONNS=`api_request sp/idpConnections` || exit

# see if we need to obtain info about a template connection
if [[ $ACTION == "create" ]] ; then
	# find the template connection
	TEMPLATE_CONN=`echo "${ALL_CONNS}" | ${JQ_BIN} --arg entity ${TEMPLATE} '.items[] | select(.entityId==$entity)'`
	if [ -z "${TEMPLATE_CONN}" ] ; then
		echo "ERROR: template connection \"${TEMPLATE}\" not found"
		exit
	fi
	# extract the attribute contract from the template connection (workaround because it gets lost??)
	CONTRACT=`echo ${TEMPLATE_CONN} | ${JQ_BIN} '.idpBrowserSso.attributeContract'`
fi

# loop over the EntityDescriptors inside the EntitiesDescriptor
let i=1
while [ $i -le ${COUNT} ]; do

	# store the single entity descriptor in a temporary XML file
	exec_xmllint ${TMP1} "cat /md:EntitiesDescriptor/md:EntityDescriptor[$i]" | ${SED_BIN} "1,1d; $ d" > ${TMP2}

	# grab the entityId	
	ENTITY=`exec_xmllint ${TMP2} "cat /md:EntityDescriptor/@entityID" "entityID" | cut -d"\"" -f2`
	
	# print out which entity we are processing
	printf "[$i] : processing [${ENTITY}] ..."

	# check if it is an IDP	
	if exec_xmllint ${TMP2} "dir /md:EntityDescriptor/md:IDPSSODescriptor" "ELEMENT IDPSSODescriptor" >/dev/null ; then 

		printf " [IDP] "

		# check if it is a SAML 2.0 descriptor
		if exec_xmllint ${TMP2} "cat /md:EntityDescriptor/md:IDPSSODescriptor/@protocolSupportEnumeration" "protocolSupportEnumeration" | ${GREP_BIN} "urn:oasis:names:tc:SAML:2.0:protocol" > /dev/null ; then

			case "${ACTION}" in
				"create")
					conn_idp_create "${TMP2}"
					;;
				"delete")
					conn_idp_delete "${ENTITY}"
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
