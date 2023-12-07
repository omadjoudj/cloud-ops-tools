alias k='kubectl'
#source <(kubectl completion bash)
. ~/.kubectl_bash_compl
complete -o default -F __start_kubectl k

alias r="kubectl exec -n rook-ceph deploy/rook-ceph-tools -it --"
alias o="kubectl exec -it -n openstack deploy/keystone-client -c keystone-client -it --"
alias silence-list="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence"
alias silence-add="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence add -a $USER "
alias silence-all='silence-add -d 2h -c "Temporary silence for 2H"  "alertname!~Watchdog|TestVMCreateError|TestVMPingError|TestVMCountTooHigh|TestVMCreateTooLong|OpenstackServiceInternalApiOutage|OpenstackServicePublicApiOutage|OpenstackPublicAPI5xxCritical|OpenstackAPI5xxCritical|OpenstackAPI401Critical"'
alias silence-upgrade='silence-add -d 7d -c "MOSK Upgrade"  "alertname!~Watchdog|TestVMCreateError|TestVMPingError|TestVMCountTooHigh|TestVMCreateTooLong|OpenstackServiceInternalApiOutage|OpenstackServicePublicApiOutage|OpenstackPublicAPI5xxCritical|OpenstackAPI5xxCritical|OpenstackAPI401Critical"'
export KUBE_EDITOR='code --wait'

alias benv='. ~/kenv `cat ~/workspace/mos_access/b.com_envs  | fzf`'

function k_get_pods_per_node 
{ 
    kubectl get pods -A -o wide  --field-selector spec.nodeName=$1 
}


