#!/bin/bash
#
# Commandline access to the PingOne directory REST API using cURL
#
# Checkout the pingone-dir-api.sh script and the setenv.sh.defaults script
# then create a script called "setenv.sh" in the same directory that contains
# at least your PingOne directory API credentials in the form of:
#
#     #!/bin/bash
#     CLIENT_ID="<your-pingone-api-username>"
#     CLIENT_SECRET="<your-pingone-api-password>"
#
# Swagger docs for the PingOne API are at: https://directory-api.pingone.com/api/docs/
#
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#

CONF_DEFAULTS="$(dirname "$0")/setenv.sh.defaults"
CONF_OVERRIDE="$(dirname "$0")/setenv.sh"

if [ ! -x "${CONF_OVERRIDE}" ] ; then 
  echo " #";
  echo " # Error: first create a file called \"setenv.sh\" in the directory \"$(dirname "$0")\"";
  echo " # in which you configure at least your PingOne API credentials in the";
  echo " # CLIENT_ID and CLIENT_SECRET environment variables and possibly override";
  echo " # other settings from the defaults in the file \"setenv.sh.defaults\"!";
  echo " #";
  exit -1
fi

source "${CONF_DEFAULTS}"
source "${CONF_OVERRIDE}"

if [[ -z ${CLIENT_ID} || -z ${CLIENT_SECRET} ]] ; then
  echo " #";
  echo " # Error: CLIENT_ID and/or CLIENT_SECRET is missing from the file \"setenv.sh\"";
  echo " #";
  exit -1
fi

CURL_AUTH="-u \"${CLIENT_ID}:${CLIENT_SECRET}\""
CURL_HDRS="-H \"Content-Type: application/json\" -H \"Accept: application/json\""
CURL_ALL_OPTS="${CURL_OPTS} ${CURL_AUTH} ${CURL_HDRS}"

function user_list_all() {
	echo ${CURL_ALL_OPTS} | xargs curl ${PINGONE_URL}/directory/user
}

function group_list_all() {
	echo ${CURL_ALL_OPTS} | xargs curl ${PINGONE_URL}/directory/group
}

function group_get_by_displayname() {
	DISPLAY_NAME="$1"
	echo ${CURL_ALL_OPTS} | xargs curl -G --data-urlencode "filter=displayName eq \"${DISPLAY_NAME}\"" ${PINGONE_URL}/directory/group
}

function group_create() {
	DISPLAY_NAME="$1"
	JSON_DATA="{\"displayName\":\"${DISPLAY_NAME}\"}";
	echo ${CURL_ALL_OPTS} | xargs curl -X POST --data-binary "${JSON_DATA}" ${PINGONE_URL}/directory/group
}

function group_delete() {
	UUID="$1"
	echo ${CURL_ALL_OPTS} | xargs curl -X DELETE "${PINGONE_URL}/directory/group/${UUID}"
}

function user_create() {
	USERNAME="$1"
	EMAIL="$2"
	FIRSTNAME="$3"
	LASTNAME="$4"
	JSON_DATA=`cat <<JSON
{
	"name": {
		"familyName": "${LASTNAME}",
		"givenName": "${FIRSTNAME}"
	},
	"userName": "${USERNAME}",
	"emails": [
		{
			"primary": true,
			"value": "${EMAIL}",
			"type": "work"
		}
	],
	"urn:scim:schemas:com_pingone:1.0": {
		"state": "ACTIVE"
	}
}
JSON`
	echo ${CURL_ALL_OPTS} | xargs curl -X POST --data-binary "${JSON_DATA}" ${PINGONE_URL}/directory/user
}
	
function user_delete() {
	UUID="$1"
	echo ${CURL_ALL_OPTS} | xargs curl -X DELETE "${PINGONE_URL}/directory/user/${UUID}"
}

function user_get_by_username() {
	USERNAME="$1"
	echo ${CURL_ALL_OPTS} | xargs curl -G --data-urlencode "filter=userName eq \"${USERNAME}\"" ${PINGONE_URL}/directory/user
}

function resource_owner_password_credentials() {
	USERNAME="$1"
	USERPWD="$2"
	echo "${CURL_OPTS} ${CURL_AUTH} -H \"Accept: application/json\"" | xargs curl -X POST --data "grant_type=password" --data-urlencode "username=${USERNAME}" --data-urlencode "password=${USERPWD}" ${PINGONE_URL}/oauth/token
}

function print_usage_and_exit() {
	echo "Usage: ${0} ${1}"
	exit -2;
}
						
case $1 in

	user-list)
		user_list_all
		;;

	group-list)
		group_list_all
		;;

	#	group)
	#	group_get_by_displayname "$2"
    #	;;

	group-create)
		if [ $# -ne 2 ] ; then print_usage_and_exit "group-create <display-name>"; fi
		group_create "$2"
		;;
	
	group-delete)
		if [ $# -ne 2 ] ; then print_usage_and_exit "group-delete <group-uuid>"; fi
		group_delete "$2"
		;;
	
	user-create) 
		if [ $# -ne 5 ] ; then print_usage_and_exit "user-create <username> <email> <first-name> <last-name>"; fi
		user_create "$2" "$3" "$4" "$5"
		;;

	user-delete)
		if [ $# -ne 2 ] ; then print_usage_and_exit "user-delete <user-uuid>"; fi
		user_delete "$2"
		;;
		
	user)
		if [ $# -ne 2 ] ; then print_usage_and_exit "user <username>"; fi
		user_get_by_username "$2"
		;;

	ropc)
		if [ $# -ne 3 ] ; then print_usage_and_exit "ropc <username> <password>"; fi
		resource_owner_password_credentials "$2" "$3"
		;;

	*)
		print_usage_and_exit "[ user-list | group-list | group-create | group-delete | user-create | user-delete | user | ropc ]"
		;;

esac
