#!/usr/bin/env bash
#
# devops-ec2-setup.sh
# ---------------------------------------------------------------------------
# Bootstraps a fresh EC2 (or any Linux VM) with common DevOps tooling:
#   - git
#   - Docker
#   - kubectl
#   - AWS CLI v2
#   - Helm
#   - Jenkins (Java + Jenkins)
#   - Interactive choice of local/managed Kubernetes: k3s / minikube / eksctl (for EKS)
#
# Works on: Ubuntu/Debian (apt) and Amazon Linux 2 / 2023 / RHEL/CentOS (yum/dnf)
#
# Usage:
#   chmod +x devops-ec2-setup.sh
#   sudo ./devops-ec2-setup.sh
#
# The script will ask you interactively which pieces to install.
# ---------------------------------------------------------------------------

set -euo pipefail

# ------------------------------ Helpers ------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

ask_yes_no() {
    # $1 = prompt text ; returns 0 for yes, 1 for no
    local prompt="$1"
    local ans
    while true; do
        read -r -p "$prompt [y/n]: " ans
        case "$ans" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer y or n." ;;
        esac
    done
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        err "Please run this script with sudo/root: sudo ./devops-ec2-setup.sh"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="$ID"
        OS_LIKE="${ID_LIKE:-}"
    else
        err "Cannot detect OS (/etc/os-release missing)."
        exit 1
    fi

    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" || "$OS_LIKE" == *"debian"* ]]; then
        PKG_MANAGER="apt"
    elif [[ "$OS_ID" == "amzn" || "$OS_ID" == "rhel" || "$OS_ID" == "centos" || "$OS_ID" == "fedora" || "$OS_LIKE" == *"rhel"* || "$OS_LIKE" == *"fedora"* ]]; then
        if command -v dnf >/dev/null 2>&1; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="yum"
        fi
    else
        err "Unsupported OS: $OS_ID. This script supports Ubuntu/Debian and Amazon Linux/RHEL/CentOS."
        exit 1
    fi

    log "Detected OS: $OS_ID  |  Package manager: $PKG_MANAGER"
}

# Get the non-root sudo user (so we can add them to the docker group etc.)
detect_real_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        REAL_USER="$SUDO_USER"
    else
        REAL_USER="$(logname 2>/dev/null || echo ec2-user)"
    fi
    log "Target non-root user for group memberships: $REAL_USER"
}

update_system() {
    log "Updating system packages..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get update -y
        apt-get upgrade -y
    else
        $PKG_MANAGER update -y
    fi
}

install_prereqs() {
    log "Installing base prerequisites (curl, wget, unzip, ca-certificates, gnupg)..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get install -y curl wget unzip ca-certificates gnupg lsb-release software-properties-common apt-transport-https
    else
        $PKG_MANAGER install -y curl wget unzip ca-certificates gnupg2 shadow-utils
    fi
}

# ------------------------------ Git -----------------------------------------
install_git() {
    if command -v git >/dev/null 2>&1; then
        log "git already installed: $(git --version)"
        return
    fi
    log "Installing git..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get install -y git
    else
        $PKG_MANAGER install -y git
    fi
    log "git installed: $(git --version)"
}

# ------------------------------ Docker --------------------------------------
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log "Docker already installed: $(docker --version)"
    else
        log "Installing Docker..."
        if [ "$PKG_MANAGER" = "apt" ]; then
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update -y
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        else
            # Amazon Linux 2023 / RHEL / CentOS
            if [ "$OS_ID" = "amzn" ]; then
                $PKG_MANAGER install -y docker
            else
                $PKG_MANAGER install -y yum-utils
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || true
                $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
        fi
    fi

    systemctl enable docker
    systemctl start docker

    if id "$REAL_USER" >/dev/null 2>&1; then
        usermod -aG docker "$REAL_USER"
        log "Added '$REAL_USER' to the docker group (log out/in or run 'newgrp docker' to apply)."
    fi

    log "Docker installed: $(docker --version)"
}

# ------------------------------ kubectl --------------------------------------
install_kubectl() {
    if command -v kubectl >/dev/null 2>&1; then
        log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
        return
    fi
    log "Installing kubectl (latest stable)..."
    local KVERSION
    KVERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KVERSION}/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    log "kubectl installed: $(kubectl version --client 2>/dev/null | head -n1)"
}

# ------------------------------ AWS CLI v2 -----------------------------------
install_aws_cli() {
    if command -v aws >/dev/null 2>&1; then
        log "AWS CLI already installed: $(aws --version)"
        return
    fi
    log "Installing AWS CLI v2..."
    local tmpdir
    tmpdir=$(mktemp -d)
    pushd "$tmpdir" >/dev/null
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    popd >/dev/null
    rm -rf "$tmpdir"
    log "AWS CLI installed: $(aws --version)"
}

# ------------------------------ Helm -----------------------------------------
install_helm() {
    if command -v helm >/dev/null 2>&1; then
        log "Helm already installed: $(helm version --short)"
        return
    fi
    log "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log "Helm installed: $(helm version --short)"
}

# ------------------------------ k3s -----------------------------------------
install_k3s() {
    log "Installing k3s (lightweight single-node Kubernetes)..."
    curl -sfL https://get.k3s.io | sh -
    log "k3s installed. Check status: sudo systemctl status k3s"
    log "kubeconfig at /etc/rancher/k3s/k3s.yaml (use: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml)"
}

# ------------------------------ minikube --------------------------------------
install_minikube() {
    log "Installing minikube..."
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube /usr/local/bin/minikube
    rm -f minikube
    log "minikube installed: $(minikube version --short 2>/dev/null || minikube version)"
    warn "Start it as the non-root user (not root), e.g.: sudo -u $REAL_USER minikube start --driver=docker"
}

# ------------------------------ eksctl (for EKS) -------------------------------
install_eksctl() {
    log "Installing eksctl (for creating/managing Amazon EKS clusters)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C "$tmpdir"
    install -m 0755 "$tmpdir/eksctl" /usr/local/bin/eksctl
    rm -rf "$tmpdir"
    log "eksctl installed: $(eksctl version)"
    warn "Make sure 'aws configure' is set up with credentials that have EKS permissions before creating a cluster."
    warn "Example: eksctl create cluster --name my-cluster --region ap-south-1 --nodes 2"
}

# ------------------------------ Jenkins ---------------------------------------
install_jenkins() {
    log "Installing Java (Jenkins prerequisite)..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get install -y fontconfig openjdk-17-jre
        log "Adding Jenkins apt repo..."
        curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee \
          /usr/share/keyrings/jenkins-keyring.asc > /dev/null
        echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
          https://pkg.jenkins.io/debian-stable binary/ | tee \
          /etc/apt/sources.list.d/jenkins.list > /dev/null
        apt-get update -y
        apt-get install -y jenkins
    else
        if [ "$OS_ID" = "amzn" ]; then
            $PKG_MANAGER install -y java-17-amazon-corretto
        else
            $PKG_MANAGER install -y java-17-openjdk
        fi
        wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
        rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
        $PKG_MANAGER install -y jenkins
    fi

    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins

    log "Jenkins installed and started on port 8080."
    log "Access it at: http://<your-ec2-public-ip>:8080  (open port 8080 in your Security Group!)"

    sleep 5
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        log "Jenkins initial admin password:"
        cat /var/lib/jenkins/secrets/initialAdminPassword
    else
        warn "Jenkins initial admin password file not found yet. Run this after a minute:"
        warn "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
    fi

    if command -v docker >/dev/null 2>&1; then
        usermod -aG docker jenkins || true
        log "Added 'jenkins' user to the docker group so Jenkins can build/run Docker images (restart jenkins after: sudo systemctl restart jenkins)."
    fi
}

# ------------------------------ Main -----------------------------------------
main() {
    require_root
    detect_os
    detect_real_user

    log "=========================================="
    log " DevOps EC2 Bootstrap Script"
    log "=========================================="

    update_system
    install_prereqs
    install_git
    install_docker
    install_kubectl
    install_aws_cli

    if ask_yes_no "Install Helm (Kubernetes package manager)?"; then
        install_helm
    fi

    echo
    echo "Which local/managed Kubernetes tool do you want to install?"
    echo "  1) k3s       - lightweight Kubernetes, runs directly on this instance"
    echo "  2) minikube  - single-node local Kubernetes (needs docker driver)"
    echo "  3) eksctl    - CLI to create/manage clusters on Amazon EKS (managed, in AWS)"
    echo "  4) none      - skip this step"
    read -r -p "Enter choice [1-4]: " K8S_CHOICE

    case "$K8S_CHOICE" in
        1) install_k3s ;;
        2) install_minikube ;;
        3) install_eksctl ;;
        4) log "Skipping Kubernetes tooling installation." ;;
        *) warn "Invalid choice, skipping Kubernetes tooling installation." ;;
    esac

    if ask_yes_no "Install Jenkins (CI/CD server)?"; then
        install_jenkins
    fi

    echo
    log "=========================================="
    log " Installation Summary"
    log "=========================================="
    command -v git     >/dev/null 2>&1 && log "git:      $(git --version)"
    command -v docker  >/dev/null 2>&1 && log "docker:   $(docker --version)"
    command -v kubectl >/dev/null 2>&1 && log "kubectl:  $(kubectl version --client 2>/dev/null | head -n1)"
    command -v aws     >/dev/null 2>&1 && log "aws-cli:  $(aws --version)"
    command -v helm    >/dev/null 2>&1 && log "helm:     $(helm version --short)"
    command -v k3s     >/dev/null 2>&1 && log "k3s:      installed"
    command -v minikube>/dev/null 2>&1 && log "minikube: $(minikube version --short 2>/dev/null || echo installed)"
    command -v eksctl  >/dev/null 2>&1 && log "eksctl:   $(eksctl version)"
    command -v jenkins >/dev/null 2>&1 || systemctl status jenkins >/dev/null 2>&1 && log "jenkins:  running on port 8080"

    warn "IMPORTANT: Log out and log back in (or run 'newgrp docker') for the docker group change to take effect for user '$REAL_USER'."
    log "All done! Happy DevOps-ing 🚀"
}

main "$@"
