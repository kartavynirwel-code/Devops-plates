# Cluster & Context Management

## 🌍 Contexts (switching clusters)

```bash
# List all contexts
kubectl config get-contexts

# Current context
kubectl config current-context

# Switch context
kubectl config use-context <context-name>

# Rename a context
kubectl config rename-context <old-name> <new-name>

# Delete a context
kubectl config delete-context <context-name>

# Set default namespace for current context
kubectl config set-context --current --namespace=<namespace>
```

---

## 🔌 Cluster Info

```bash
kubectl cluster-info
kubectl cluster-info dump                  # full dump (large output)
kubectl version
kubectl api-resources                      # list all resource types
kubectl api-versions                       # list all API versions
kubectl explain pod                        # docs for a resource
kubectl explain pod.spec
kubectl explain pod.spec.containers
```

---

## 🗂️ kubeconfig Management

```bash
# View kubeconfig
kubectl config view
kubectl config view --minify              # only current context

# Set kubeconfig file
export KUBECONFIG=~/.kube/config

# Merge multiple kubeconfigs
export KUBECONFIG=~/.kube/config:~/.kube/other-config
kubectl config view --flatten > ~/.kube/merged-config
```

---

## 🛠️ Useful Aliases to Add to ~/.bashrc or ~/.zshrc

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'
alias kds='kubectl describe service'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias klogs='kubectl logs -f'
alias kexec='kubectl exec -it'
alias kns='kubectl config set-context --current --namespace'   # quick namespace switch

# Example: kns my-namespace
```

---

## ⚡ kubectx & kubens (Recommended Tools)

```bash
# Install kubectx for fast context switching
brew install kubectx           # mac
# or: https://github.com/ahmetb/kubectx

kubectx                        # list contexts
kubectx <context-name>         # switch context
kubectx -                      # switch to previous context

kubens                         # list namespaces
kubens <namespace>             # switch namespace
kubens -                       # switch to previous namespace
```
