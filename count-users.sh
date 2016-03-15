#!/bin/sh

#
# Run this script in the pingfederate/log directory.
# If you are running in clustered mode, run this script on each of the CLUSTERED_ENGINE nodes and add
# the totals together for a complete count. Also, you will want to see how many audit*.log files are
# in the folder to understand the time period that the counter in measuring.
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