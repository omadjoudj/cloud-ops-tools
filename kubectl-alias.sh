alias k=kubectl
complete -o default -F __start_kubectl k

# set up autocomplete in bash into the current shell, bash-completion package should be installed first.
# source <(kubectl completion bash)

# add autocomplete permanently to your bash shell.
echo "source <(kubectl completion bash)" >> ~/.bashrc 

