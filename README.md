ping-scripts
============

Scripts for Ping Identity's products.

pingfed-admin-api
-----------------
Scripts that use the Admin REST API that PingFederate provides since version 7.x.

- connections-from-xml.sh  
  import (or delete from) PingFederate a set of connections specified in an XML metadata file

pingfed-admin-api
-----------------
Scripts that use the Admin REST API that PingFederate provides since version 7.x.

- connections-from-xml.sh  
  import (or delete from) PingFederate a set of connections specified in an XML metadata file
- adapter.sh  
  manage adapters from the commandline
- oauth-client.sh  
  manage OAuth Clients from the commandline
- ca-certs.sh  
  manage Trusted CA certificates from the commandline

pingone-directory
-----------------
Scripts that use the SCIM API provided to the PingOne directory.

- pingone-dir-api.sh  
  manipulate users and groups in the PingOne directory.

init.d
------
Start/stop scripts for *nix operating systems.

replicate-config.sh
-------------------
Replicate the configuration configured in the Admin Console to the cluster using the
commandline instead of the GUI.

show-version.sh
---------------
Show the exact version number of PingFederate including minor/build tags.
