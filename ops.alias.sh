alias k='kubectl'
alias m='multipass'
#source <(kubectl completion bash)
source <(kubectl completion zsh)
complete -o default -F __start_kubectl k

#alias r="kubectl exec -n rook-ceph deploy/rook-ceph-tools -it --"
#alias o="kubectl exec -it -n openstack deploy/keystone-client -c keystone-client -it --"
alias silence-list="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence"
alias silence-del="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence expire"
alias silence-add="kubectl -n stacklight exec sts/prometheus-alertmanager -c prometheus-alertmanager -- amtool --alertmanager.url http://127.0.0.1:9093 silence add -a $USER "

alias benv='. ~/kenv `cat ~/.kube/config| grep "\- name:" | cut -d: -f2 | tr -d " " | fzf`'

