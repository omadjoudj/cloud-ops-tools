alias k='kubectl'
alias m='multipass'
#source <(kubectl completion bash)
source <(kubectl completion zsh)

alias kenv='kubectx'
alias gerrit-push='git push origin HEAD:refs/for/`git branch --show-current`'
alias diff-normalizer='docker run -it -v `pwd`:/tmp/repo docker-dev-kaas-virtual.mcp.mirantis.com/services/diff-exporter:0.0.1.dev92-alpine3.20.6-20250416174021 diff-normalize --path /tmp/repo'


ssh() {
    mkdir -p $HOME/workspace/ssh_output_logs
    local logfile="$HOME/workspace/ssh_output_logs/${1//[^a-zA-Z0-9.]/_}_$(date +%Y-%m-%d_%H-%M-%S).log"
    echo "--- Session logging started to $logfile ---"
    /usr/bin/ssh -o PubkeyAuthentication=no "$1" | tee -a "$logfile"
}
