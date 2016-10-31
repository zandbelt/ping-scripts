#!/bin/sh

###################################################################################
# Copyright (C) 2016 Ping Identity Corporation
#
# Script to demonstrate accessing the PingAccess Admin API with an OAuth 2.0 Client
#
# Prerequisites:
# 1. install PingFederate and PingAccess with the PingAccess Quickstart application
# 2. create an additional OAuth client "ro", no client secret, grant type allowed Resource Owner Password Credentials
# 3. create a Resource Owner Password Credentials mapping to the PCV that authenticates the PingAccess Admin API users (simplePCV)
# 4. enable authentication for the PingAccess API System -> Admin Authentication -> API -> Enable
# 5. use client_id "pa_rs", client_secret "Password1", scope "admin" and Subject Attribute Name "Username"
# 
# @Author: Hans Zandbelt - hzandbelt@pingidentity.com
#
###################################################################################

PFBASE=https://localhost:9031
PABASE=https://localhost:9000
CLIENT_ID_ROPC=ro
USERNAME=joe
PASSWORD=2Federate
SCOPE=admin

FLAGS="-k -v -H \"X-Xsrf-Header: PingAccess\""

RESPONSE=`echo ${FLAGS} | xargs curl -d "client_id=${CLIENT_ID_ROPC}&grant_type=password&username=${USERNAME}&password=${PASSWORD}&scope=${SCOPE}" ${PFBASE}/as/token.oauth2`
AT=`echo ${RESPONSE} | cut -d"\"" -f4`
echo ${FLAGS} | xargs curl -H "Authorization: Bearer ${AT}" ${PABASE}/pa-admin-api/v2/version
