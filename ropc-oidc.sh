#!/bin/sh

###########################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# Script to demonstrate the alternatives for leveraging the Resource Owner
# Password Credentials (ROPC) grant type in an OpenID Connect fashion.
# 
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
###########################################################################

PFBASE=https://localhost:9031
CLIENT_ID=ac_oic_client
CLIENT_SECRET=abc123DEFghijklmnop4567rstuvwxyzZYXWUT8910SRQPOnmlijhoauthplaygroundapplication
USER=joe
PASSWD=2Federate
SCOPE="openid%20email%20profile"

function base64_url_decode() {
  _l=$((${#1} % 4))
  if [ $_l -eq 2 ]; then _s="$1"'=='
  elif [ $_l -eq 3 ]; then _s="$1"'='
  else _s="$1" ; fi
  echo "$_s" | tr '_-' '/+' | openssl enc -d -a -A
}

case $1 in

  userinfo)

    #
    # using an OpenID Connect client with a pure OAuth 2.0 ROPC flow to receive an AT that can be used to call the userinfo endpoint
    # attributes are mapped from the OIDC Policy
    #

    #
    # prerequisites: OAuth 3.x Playground installed and ROPC grant enabled for client ac_oic_client
    #

    # bare commands for copy/paste:
    #curl -k -s -X POST -d "client_id=ac_oic_client&client_secret=abc123DEFghijklmnop4567rstuvwxyzZYXWUT8910SRQPOnmlijhoauthplaygroundapplication&grant_type=password&username=joe&password=2Federate&scope=openid%20email%20profile" https://localhost:9031/as/token.oauth2
    #curl -k --header "Authorization: Bearer apixmZnpMOLEsJ0XzSTaSW0rmUex" https://localhost:9031/idp/userinfo.openid

    >&2 echo "Obtain Access Token using ROPC..."
    AT=`curl -s -k -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=password&username=${USER}&password=${PASSWD}&scope=${SCOPE}" ${PFBASE}/as/token.oauth2 | grep -o '\"access_token\":.*' | cut -d":" -f2 | cut -d"\"" -f2`
    >&2 echo "Call UserInfo endpoint with Access Token \"${AT}\"..."
    curl -s -k -H "Authorization: Bearer ${AT}" ${PFBASE}/idp/userinfo.openid

    ;;

  implicit)

    #
    # prerequisites: OAuth 3.x Playground installed and "Bypass Authorization Approval" is set for the im_oic_client Client
    #

    CLIENT_ID="im_oic_client"
    >&2 echo "OIDC Implicit grant..."
    IDTOKEN=`curl -k -s -i -d "client_id=${CLIENT_ID}&scope=${SCOPE}&response_type=token%20id_token&nonce=nonce&pf.username=${USER}&pf.pass=${PASSWD}" ${PFBASE}/as/authorization.oauth2 | grep "Location:" | cut -d"&" -f2 | cut -d "=" -f2 | cut -d"." -f2`
    base64_url_decode "${IDTOKEN}"

    ;;

  jwt)

    #
    # prerequisites: OAuth 3.x Playground installed
    #                "jwt" JWT Token Manager instance has been created
    #                Access Token Mapping has been created for "jwt" and UserPass PCV
    #

    TOKEN_MGR="jwt"
    CLIENT_ID="ro_client"
    >&2 echo "ROPC for JWT access token..."
    AT=`curl -k -s -d "client_id=${CLIENT_ID}&scope=${SCOPE}&grant_type=password&username=${USER}&password=${PASSWD}&access_token_manager_id=${TOKEN_MGR}" ${PFBASE}/as/token.oauth2 | cut -d"," -f1 | cut -d":" -f2 | tr -d "\""`
    >&2 echo "Got JWT access token \"${AT}\"..."
    PAYLOAD=`echo "${AT}" | cut -d"." -f2`
    >&2 echo "Decoded JWT access token payload..."
    base64_url_decode "${PAYLOAD}"

    ;;

  validate)
    #
    # Token Validation
    #

    if [ -z $2 ] ; then
      echo "Usage: $0 validate <access_token>"
      exit
    fi

    AT="$2"
    CLIENT_ID="rs_client"
    CLIENT_SECRET="2Federate"
    >&2 echo "Token validation for \"${AT}\"..."
    GT="urn:pingidentity.com:oauth2:grant_type:validate_bearer"
    curl -k -s -X POST -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&grant_type=${GT}&token=${AT}" ${PFBASE}/as/token.oauth2
    #&access_token_manager_id=jwt

    ;;

  *)
    echo "Usage: $0 [userinfo|implicit|jwt|validate]"
    ;;
esac

