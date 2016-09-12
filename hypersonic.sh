#!/bin/sh

#
# connect the internal Swing DB GUI with the default PF database
#

PFBASE="/Users/hzandbelt/pingfederate/deploy/oauthplayground-3.3.0/pingfederate-8.2.0"
URL="jdbc:hsqldb:file:${PFBASE}/pingfederate/server/default/data/hypersonic/PFDefaultDB"
USER="sa"
PWD="secretpass"

java -cp ${PFBASE}/pingfederate/server/default/lib/hsqldb.jar org.hsqldb.util.DatabaseManagerSwing --user ${USER} --password ${PWD} --url ${URL}
