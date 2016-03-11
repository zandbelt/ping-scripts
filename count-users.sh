#!/bin/sh

#
# run this in the pingfederate/log directory
#

case $1 in
	idp)
		TYPE="IdP"
		;;
	sp)
		TYPE="SP"
		;;
	oauth)
		TYPE="AS"
		;;
	*)
		echo "Usage: ${0} [ \"idp\" | \"sp\" | \"oauth\" ]"
		exit -1;
	;;
esac
	
grep -R success audit* | grep "| ${TYPE}|" | cut -d"|" -f3 | grep -v "^[[:space:]]*$" | sort -f | uniq -i | wc -l