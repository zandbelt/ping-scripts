#!/bin/sh

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u \"${ADM_USER}:${ADM_PWD}\" -H \"X-XSRF-Header: pingfed\""

FILENAME=$2
if [ -z "${FILENAME}" ] ; then
	DATE=`date "+%Y%m%d"`
	FILENAME="archive-${DATE}.zip"
fi

case $1 in
	export)
		echo ${FLAGS} | xargs curl ${PF_API}/configArchive/export > ${FILENAME}
		;;
	import)
		echo ${FLAGS} | xargs curl -X POST -F "file=@${FILENAME}" ${PF_API}/configArchive/import
		;;
	*)
		echo "Usage: ${0} [ export <filename> | import <filename> ]"
		exit -1;
	;;
esac