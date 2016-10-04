#!/bin/sh

USERNAME=heuristics
PASSWD=Changeme1
URL=https://localhost:9999/pf-mgmt-ws/ws/ConfigReplication

CURL_FLAGS="-k -v -u \"${USERNAME}:${PASSWD}\" -H \"soapAction: ${URL}\""

XML_DATA=`cat <<XML
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
	<s:Body>
		<replicateConfiguration/>
	</s:Body>
</s:Envelope>
XML`

echo ${CURL_FLAGS} | xargs curl --data-binary "${XML_DATA}" ${URL}
