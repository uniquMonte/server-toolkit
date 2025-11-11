#!/bin/bash

#######################################
# Docker Management Script
# Supports installation, configuration, and uninstallation of Docker and Docker Compose
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Unable to detect operating system"
        exit 1
    fi
}

# Check if Docker is installed
check_docker_installed() {
    if command -v docker &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if Docker Compose is installed
check_compose_installed() {
    if docker compose version &> /dev/null 2>&1; then
        return 0
    elif command -v docker-compose &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install Docker (Ubuntu/Debian)
install_docker_debian() {
    log_info "Installing Docker on Ubuntu/Debian..."

    # Remove old versions
    log_info "Removing old versions..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Update package index
    log_info "Updating package index..."
    apt-get update

    # Install required packages
    log_info "Installing dependencies..."
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker official GPG key
    log_info "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up repository
    log_info "Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index
    apt-get update

    # Install Docker Engine
    log_info "Installing Docker Engine..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Install Docker (CentOS/RHEL/Rocky/AlmaLinux)
install_docker_rhel() {
    log_info "Installing Docker on CentOS/RHEL/Rocky/AlmaLinux..."

    # Remove old versions
    log_info "Removing old versions..."
    if command -v dnf &> /dev/null; then
        dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    else
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    fi

    # Install required packages
    log_info "Installing dependencies..."
    if command -v dnf &> /dev/null; then
        dnf install -y yum-utils
    else
        yum install -y yum-utils
    fi

    # Set up repository
    log_info "Setting up Docker repository..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # Install Docker Engine
    log_info "Installing Docker Engine..."
    if command -v dnf &> /dev/null; then
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
}

# Detect region for mirror selection
detect_region() {
    # Try to detect if server is in China
    local country=$(curl -s --connect-timeout 3 https://ipapi.co/country 2>/dev/null || echo "")
    if [ "$country" = "CN" ]; then
        echo "CN"
    else
        echo "OTHER"
    fi
}

# Configure Docker
configure_docker() {
    log_info "Configuring Docker..."

    # Start Docker service
    log_info "Starting Docker service..."
    systemctl start docker
    systemctl enable docker

    log_info "Using Docker default configuration"

    # Add current user to docker group (if not root)
    if [ "$SUDO_USER" ]; then
        log_info "Adding user $SUDO_USER to docker group..."
        usermod -aG docker $SUDO_USER
        log_info "Note: You need to log out and back in for non-root users to run docker commands"
    fi

    # Verify installation
    log_info "Verifying Docker installation..."
    docker --version

    if docker run hello-world &> /dev/null; then
        log_success "Docker installed successfully!"
    else
        log_warning "Docker installation completed, but test run failed"
    fi
}

# Install Docker
install_docker() {
    log_info "Starting Docker installation..."

    if check_docker_installed; then
        log_warning "Docker is already installed"
        docker --version
        return
    fi

    detect_os

    case $OS in
        ubuntu|debian)
            install_docker_debian
            ;;

        centos|rhel|rocky|almalinux)
            install_docker_rhel
            ;;

        fedora)
            install_docker_rhel
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    configure_docker
}

# Install Docker Compose
install_compose() {
    if check_compose_installed; then
        log_success "Docker Compose is already installed"
        docker compose version
        return
    fi

    log_info "Docker Compose plugin should already be installed with Docker"
    log_info "If not installed, attempting to install..."

    detect_os

    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y docker-compose-plugin
            ;;

        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y docker-compose-plugin
            else
                yum install -y docker-compose-plugin
            fi
            ;;
    esac

    if check_compose_installed; then
        log_success "Docker Compose installed successfully"
        docker compose version
    else
        log_error "Docker Compose installation failed"
    fi
}

# Install Docker and Docker Compose
install_docker_and_compose() {
    install_docker
    install_compose
}

# Uninstall Docker
uninstall_docker() {
    log_warning "Starting Docker uninstallation..."

    if ! check_docker_installed; then
        log_warning "Docker is not installed, no need to uninstall"
        return
    fi

    read -p "Are you sure you want to uninstall Docker? This will delete all containers, images, and data (Y/n) (press Enter to confirm): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi

    detect_os

    # Stop all running containers
    log_info "Stopping all running containers..."
    if [ -n "$(docker ps -q)" ]; then
        docker stop $(docker ps -q) || log_warning "Failed to stop some containers"
    else
        log_info "No running containers to stop"
    fi

    # Remove all containers
    log_info "Removing all containers..."
    if [ -n "$(docker ps -aq)" ]; then
        docker rm -f $(docker ps -aq) || log_warning "Failed to remove some containers"
    else
        log_info "No containers to remove"
    fi

    # Remove all images
    log_info "Removing all images..."
    if [ -n "$(docker images -q)" ]; then
        docker rmi -f $(docker images -q) || log_warning "Failed to remove some images"
    else
        log_info "No images to remove"
    fi

    # Stop Docker service
    log_info "Stopping Docker service..."
    systemctl stop docker
    systemctl disable docker

    # Uninstall Docker
    local uninstall_status=0
    case $OS in
        ubuntu|debian)
            log_info "Uninstalling Docker using APT..."
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            uninstall_status=$?
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Uninstalling Docker using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                uninstall_status=$?
            else
                yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                uninstall_status=$?
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Delete Docker data automatically (user already confirmed uninstall)
    log_info "Deleting Docker data and configuration..."
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    rm -rf /etc/apt/keyrings/docker.gpg
    rm -rf /etc/apt/sources.list.d/docker.list
    rm -rf /etc/yum.repos.d/docker-ce.repo

    # Clear command hash to ensure docker command is no longer cached
    hash -r 2>/dev/null || true

    if [ $uninstall_status -eq 0 ]; then
        log_success "Docker uninstallation complete!"
    else
        log_error "Docker uninstallation encountered errors"
        exit 1
    fi
}

# Display help
show_help() {
    echo "Usage: $0 {install|install-compose|uninstall}"
    echo ""
    echo "Commands:"
    echo "  install          - Install Docker"
    echo "  install-compose  - Install Docker and Docker Compose"
    echo "  uninstall        - Uninstall Docker"
    echo ""
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "$1" in
        install)
            install_docker
            ;;
        install-compose)
            install_docker_and_compose
            ;;
        uninstall)
            uninstall_docker
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
