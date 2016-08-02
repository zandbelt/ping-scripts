#!/bin/sh

# sample script to add an adapter + attribute mapping/lookup to an existing SP Connection

ADM_USER=administrator
ADM_PWD=2Federate
PF_API=https://localhost:9999/pf-admin-api/v1

FLAGS="-k -s -u ${ADM_USER}:${ADM_PWD} --header X-XSRF-Header:\ pingfed"

function print_usage() {
  echo "Usage: $0 <connection-id>"
  exit 1
}

if [ $# -lt 1 ] ; then print_usage; fi

SPID=$1

JSON_DATA=`cat <<JSON
      {
        "attributeSources": [
          {
            "type": "JDBC",
            "dataStoreRef": {
              "id": "ProvisionerDS",
              "location": "https://localhost:9999/pf-admin-api/v1/dataStores/ProvisionerDS"
            },
            "description": "ldap",
            "attributeContractFulfillment": {
              "Member Status": {
                "source": {
                  "type": "JDBC_DATA_STORE"
                },
                "value": "GRANTEE"
              },
              "First Name": {
                "source": {
                  "type": "JDBC_DATA_STORE"
                },
                "value": "GRANTEE"
              },
              "Last Name": {
                "source": {
                  "type": "JDBC_DATA_STORE"
                },
                "value": "GRANTEE"
              },
              "SAML_SUBJECT": {
                "source": {
                  "type": "JDBC_DATA_STORE"
                },
                "value": "GRANTEE"
              },
              "Email Address": {
                "source": {
                  "type": "JDBC_DATA_STORE"
                },
                "value": "GRANTEE"
              }
            },
            "schema": "INFORMATION_SCHEMA",
            "table": "ADMINISTRABLE_ROLE_AUTHORIZATIONS",
            "filter": "cn=\\\${username}"
          }
        ],
       "attributeContractFulfillment": {
          "Member Status": {
            "source": {
              "type": "ADAPTER"
            },
            "value": "salary"
          },
          "First Name": {
            "source": {
              "type": "ADAPTER"
            },
            "value": "fname"
          },
          "Last Name": {
            "source": {
              "type": "ADAPTER"
            },
            "value": "lname"
          },
          "SAML_SUBJECT": {
            "source": {
              "type": "ADAPTER"
            },
            "value": "subject"
          },
          "Email Address": {
            "source": {
              "type": "ADAPTER"
            },
            "value": "email"
          }
        },
        "issuanceCriteria": {
          "conditionalCriteria": []
        },
        "idpAdapterRef": {
          "id": "idpadapter2",
          "location": "https://localhost:9999/pf-admin-api/v1/idp/adapters/idpadapter2"
        },
        "restrictVirtualEntityIds": false,
        "restrictedVirtualEntityIds": []
      }
JSON`

curl ${FLAGS} ${PF_API}/idp/spConnections/${SPID} | jq ".spBrowserSso.adapterMappings |=.+ [ ${JSON_DATA} ]" | curl ${FLAGS} -H "Content-Type: application/json" -X PUT -d @- ${PF_API}/idp/spConnections/${SPID}
