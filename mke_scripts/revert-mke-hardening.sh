#!/bin/sh
#
rm mke-config.toml
export MKE_USERNAME=admin

export MKE_CLUSTERNAME=$2

export NAMESPACE=$1

export MKE_PASSWORD=`kubectl get -o 'jsonpath={.data.ucpAdminPassword}' secret -n $NAMESPACE ucp-admin-password-${MKE_CLUSTERNAME}|base64 -d`

export MKE_HOST=`kubectl get cluster  -o 'jsonpath={.status.providerStatus.ucpDashboard}' -n $NAMESPACE  ${MKE_CLUSTERNAME}`

AUTHTOKEN=$(curl --silent --insecure --data '{"username":"'$MKE_USERNAME'","password":"'$MKE_PASSWORD'"}' $MKE_HOST/auth/login | jq --raw-output .auth_token)

curl --silent --insecure -X GET "$MKE_HOST/api/ucp/config-toml" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" > mke-config.toml



sed -i bak 's/k8s_always_pull_images_ac_enabled = true/k8s_always_pull_images_ac_enabled = false/' mke-config.toml
sed -i bak 's/hardening_enabled = true/hardening_enabled = false/' mke-config.toml
sed -i bak 's/use_strong_tls_ciphers = true/use_strong_tls_ciphers = false/' mke-config.toml


curl --silent --insecure -X PUT -H "X-Ucp-Allow-Restricted-Api: i-solemnly-swear-i-am-up-to-no-good" -H "accept: application/toml" -H "Authorization: Bearer $AUTHTOKEN" --upload-file 'mke-config.toml' $MKE_HOST/api/ucp/config-toml

