#!/bin/sh

###########################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
# Script to demonstrate the alternatives for leveraging the Resource Owner
# Password Credentials (ROPC) grant type in an OpenID Connect fashion.
# Alternatives are:
#
# 1. "userinfo"
# Access the OIDC user info endpoint with the access token obtained in a regular
# OAuth 2.0 flow by an OIDC client (where the openid scope will not return an id_token)
# - standard ROPC and obtain claims as regular JSON
#
# 2. "implicit"
# Mimic a browser and post the username/password credentials against the authorization endpoint
# and obtain the id_token from the Location header that is returned
# - non-standard ROPC and obtain claims in id_token
# 
# 3. "jwt"
# Obtain a JWT access token that is decorated as an id_token (8.2 allows for a jwks_uri to validate)
# - standard ROPC and obtain claims in a signed JWT that cannot be distinguished from an id_token
#
#
# Sample Output:
#
# $ ./ropc-oidc.sh implicit | jq -S '.'
# OIDC Implicit grant...
# {
#   "at_hash": "V5Z5xEw7atBZqbtAznEVGQ",
#   "aud": "im_oic_client",
#   "auth_time": 1480529154,
#   "exp": 1480529454,
#   "iat": 1480529154,
#   "iss": "https://localhost:9031",
#   "jti": "mBUxAzaeBgoc482D0Gs119",
#   "nonce": "nonce",
#   "sub": "joe"
# }
#
# $ ./ropc-oidc.sh jwt | jq -S '.'
# ROPC for JWT access token...
# Got JWT access token "eyJhbGciOiJSUzI1NiIsImtpZCI6Imp3dCJ9.eyJzdWIiOiJqb2UiLCJpYXQiOjE0ODA1MjkxNTgsIm5vbmNlIjoiZnVqZlh6S09YeiIsImp0aSI6InJ0Qm5HaDhlMlExVUljUUNoanNXbEEiLCJhdXRoX3RpbWUiOjE0ODA1MjkxNTgsImV4cCI6MTQ4MDUzNjM1OCwiaXNzIjoiaHR0cHM6Ly9sb2NhbGhvc3Q6OTAzMSIsImF1ZCI6ImltX29pY19jbGllbnQifQ.BNQ9QnvT9eUACOr0e_WhcST4KlwjNSqfLh8iHPWmlG0ZXAW0ipZolFw8fu8HmCO7MF6y4I580Ia0TbTygpct6hDB4UAiGOZZ9nmGnTj3YMAdlRH6Jv-c9jeN5_ab-FSmxS9MVrlFo0C21YJ54deHG5vWZK7DQEfdruR2gIdylLVUE49Fm2sQuP6tPLV6_cilGIXakBYMf0GVz49HQsnPS3PBaxH3jHS7aVGnImZYa_K9Rm-tru6lJ1wnk1lQ-qI7Tpq4qt43MayBjhF5Ig_iY7TvpVNpsaorc_H6E0DYs9OdkvMFVO0xKK_qf2VG9RyqMMia3iM2KUQaJvRdmb1Xzw"...
# Decoded JWT access token payload...
# {
#   "aud": "im_oic_client",
#   "auth_time": 1480529158,
#   "exp": 1480536358,
#   "iat": 1480529158,
#   "iss": "https://localhost:9031",
#   "jti": "rtBnGh8e2Q1UIcQChjsWlA",
#   "nonce": "fujfXzKOXz",
#   "sub": "joe"
# }
#
#
# With "jwt" settings in access token manager set to:
#
# Access Token Management Configuration Summary
# Create Access Token Management Instance
# Type	
# Instance Name	jwt
# Instance Id	jwt
# Type	JSON Web Tokens
# Class Name	com.pingidentity.pf.access.token.management.plugins.JwtBearerAccessTokenManagementPlugin
# Parent Instance Name	None
# Instance Configuration	
# Certificates	jwt, CN=jwt, O=jwt, C=US
# Token Lifetime	120
# JWS Algorithm	RSA using SHA-256
# Active Symmetric Key ID	None Selected
# Active Signing Certificate Key ID	jwt
# JWE Algorithm	None Selected
# JWE Content Encryption Algorithm	None Selected
# Active Symmetric Encryption Key ID	None Selected
# Asymmetric Encryption Key	
# Asymmetric Encryption JWKS URL	
# Include Key ID Header Parameter	true
# Include X.509 Thumbprint Header Parameter	false
# Default JWKS URL Cache Duration	720
# Include JWE Key ID Header Parameter	true
# Include JWE X.509 Thumbprint Header Parameter	false
# Client ID Claim Name	
# Scope Claim Name	
# Space Delimit Scope Values	false
# Issuer Claim Value	https://localhost:9031
# Audience Claim Value	im_oic_client
# JWT ID Claim Length	0
# Access Grant GUID Claim Name	
# JWKS Endpoint Path	
# JWKS Endpoint Cache Duration	720
# Publish Key ID X.509 URL	false
# Publish Thumbprint X.509 URL	false
# Access Token Attribute Contract	
# Attribute	auth_time
# Attribute	iat
# Attribute	jti
# Attribute	nonce
# Attribute	sub
# Resource URIs	
# Access Control	
# Restrict Allowed Clients	false
#
#
# And "jwt" access token mapping settings to:
#
# Mapping Summary
# Access Token Mapping
# Attribute Sources & User Lookup	
# Data Sources	(None)
# Contract Fulfillment	
# sub	username (Password Credential Validator)
# auth_time	@java.lang.Long@valueOf(@org.jose4j.jwt.NumericDate@now().getValue())
# (Expression)
# iat	@java.lang.Long@valueOf(@org.jose4j.jwt.NumericDate@now().getValue()) (Expression)
# nonce	@org.sourceid.common.IDGenerator@rndAlphaNumeric(10) (Expression)
# jti	@org.sourceid.common.IDGenerator@rndAlphaNumeric(22) (Expression)
# Issuance Criteria	
# Criterion	(None)
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
    #                "jwt" JWT Token Manager instance has been created (see top of script)
    #                Access Token Mapping has been created for "jwt" and UserPass PCV (see top of script)
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

