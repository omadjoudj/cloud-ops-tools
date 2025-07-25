alias k='kubectl'
alias m='multipass'
#source <(kubectl completion bash)
source <(kubectl completion zsh)

alias benv='kubectx'
alias gerrit-push='git push origin HEAD:refs/for/`git branch --show-current`'
alias diff-normalizer='docker run -it -v `pwd`:/tmp/repo docker-dev-kaas-virtual.mcp.mirantis.com/services/diff-exporter:0.0.1.dev92-alpine3.20.6-20250416174021 diff-normalize --path /tmp/repo'
