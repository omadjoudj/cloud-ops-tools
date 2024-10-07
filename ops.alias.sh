alias k='kubectl'
alias m='multipass'
#source <(kubectl completion bash)
source <(kubectl completion zsh)

alias benv=' . ~/kenv `kubectl config get-contexts --no-headers=false -o name | fzf`'

