#!/bin/sh

###########################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# Script to demonstrate standards compliant token introspection conform
# RFC 7662 based on the stock OAuth 2.0 Playground installation.
# 
# prerequisites: OAuth 3.x Playground installed
#
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
###########################################################################

PFBASE=https://localhost:9031

case $1 in

get)

    CLIENT_ID="ro_client"
    USER=joe
    PASSWD=2Federate
    SCOPE="edit"
    >&2 echo "ROPC for access token..."
    curl -k -s -d "client_id=${CLIENT_ID}&scope=${SCOPE}&grant_type=password&username=${USER}&password=${PASSWD}" ${PFBASE}/as/token.oauth2 

    ;;

introspect)

    if [ -z $2 ] ; then
      echo "Usage: $0 introspect <access_token>"
      exit
    fi

    AT="$2"
    CLIENT_ID="rs_client"
    CLIENT_SECRET="2Federate"
    >&2 echo "Token Introspection for \"${AT}\"..."
    curl -k -s -d "client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&token=${AT}" ${PFBASE}/as/introspect.oauth2

    ;;

  *)
    echo "Usage: $0 [get|introspect]"
    ;;
esac

