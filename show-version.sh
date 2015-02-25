#!/bin/sh

if [ -z $1 ] ; then DIR="."; else DIR=$1; fi

tar -xOf ${DIR}/pingfederate/bin/pf-startup.jar META-INF/maven/pingfederate/pf-startup/pom.properties | grep version | cut -d"=" -f2
