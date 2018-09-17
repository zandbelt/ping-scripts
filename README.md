ping-scripts
============

Scripts for Ping Identity's products.

pingfed-admin-api
-----------------
Scripts that use the Admin REST API that PingFederate provides since version 7.x.

- connections-from-xml.sh  
  import into (or delete from) PingFederate a set of IDP connections specified in an XML metadata file
- adapter.sh  
  manage adapters from the commandline
- oauth-client.sh  
  manage OAuth Clients from the commandline
- oauth-grants.sh  
  manage OAuth Persistent Grants for a user from the commandline
- ca-certs.sh  
  manage Trusted CA certificates from the commandline
- ssl-certs.sh  
  manage SSL server certificates from the commandline
- archive.sh  
  backup/restore from the commandline
- connection-update-virtual-server-id.sh  
  add a virtual server ID to an existing SP Connection
- rotate-key-at-enc-sym.sh  
  rotate a symmetric encryption key for a JWT access token

pingaccess-admin-api
-----------------
Scripts that use the PingAccess Admin REST API.

- pa-version.sh  
  access the PingAccess Admin API with an OAuth 2.0 Client

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

count-users.sh
--------------
Count users by analyzing the audit.log files.

hypersonic.sh
-------------
Start a Java-based GUI to inspect the Hypersonic database used e.g. for refresh token storage.

ropc-oidc.sh
------------
Demonstrates alternatives for leveraging the Resource Owner Password Credentials (ROPC) grant type in an OpenID Connect fashion.

authorization-code.sh
---------------------
Demonstrate the authorization code flow from the commandline using cURL.

token-introspection.sh
----------------------
Perform RFC 7662 compliant token introspection from the commandline.

client-credentials.sh
---------------------
Demonstrate the client credentials flow from the commandline using cURL.

refresh-token.sh
---------------------
Demonstrate the refresh token grant type (after initial ROPC) from the commandline using cURL.

flexible-persistent-grant-lifetime.sh
-------------------------------------
Demonstrates setting the lifetime of persistent grants based on context of the authorization request (scopes).
