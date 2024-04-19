#!/bin/sh
#
export MKE_USERNAME=admin

export MKE_CLUSTERNAME=$2

export NAMESPACE=$1

export MKE_PASSWORD=`kubectl get -o 'jsonpath={.data.ucpAdminPassword}' secret -n $NAMESPACE ucp-admin-password-${MKE_CLUSTERNAME}|base64 -d`

export MKE_HOST=`kubectl get cluster  -o 'jsonpath={.status.providerStatus.ucpDashboard}' -n $NAMESPACE  ${MKE_CLUSTERNAME}`

AUTHTOKEN=$(curl --silent --insecure --data '{"username":"'$MKE_USERNAME'","password":"'$MKE_PASSWORD'"}' $MKE_HOST/auth/login | jq --raw-output .auth_token)

curl --silent --insecure -X GET "$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" 


