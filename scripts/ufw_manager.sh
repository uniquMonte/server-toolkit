#!/bin/bash

#######################################
# UFW Firewall Management Script
# Supports installation, configuration, and uninstallation
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
    else
        log_error "Unable to detect operating system"
        exit 1
    fi
}

# Check if UFW is installed
check_ufw_installed() {
    if command -v ufw &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install UFW only (no configuration)
install_ufw_base() {
    log_info "Starting UFW firewall installation..."

    detect_os

    if check_ufw_installed; then
        log_warning "UFW is already installed"
        ufw --version
        return 0
    fi

    case $OS in
        ubuntu|debian)
            log_info "Installing UFW using APT..."
            apt-get update
            apt-get install -y ufw
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Installing UFW using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf install -y ufw
            else
                # EPEL repository may need to be installed first
                yum install -y epel-release
                yum install -y ufw
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    if check_ufw_installed; then
        log_success "UFW installed successfully"
        ufw --version
        return 0
    else
        log_error "UFW installation failed"
        exit 1
    fi
}

# Install UFW only, without configuring rules
install_only() {
    install_ufw_base
    log_success "UFW has been installed, but no rules configured"
    log_info "Note: UFW is not enabled, you can configure rules manually later"
}

# Install UFW and configure common ports (22, 80, 443)
install_common() {
    install_ufw_base

    log_info "Configuring common ports..."
    configure_ufw_common
}

# Install UFW with custom configuration
install_custom() {
    install_ufw_base

    log_info "Starting custom configuration..."
    configure_ufw_custom
}

# Configure common ports (22, 80, 443)
configure_ufw_common() {
    log_info "Configuring UFW firewall rules (common ports)..."

    # Warn about resetting UFW
    echo ""
    log_warning "⚠️  IMPORTANT: Resetting UFW will temporarily remove all firewall rules!"
    log_warning "This may briefly interrupt your SSH connection if not configured properly."
    echo ""
    if [ "$AUTO_INSTALL" = "true" ]; then
        reset_confirm="y"
        log_info "Auto-install mode: Proceeding with UFW reset..."
    else
        read -p "Continue with UFW reset? (y/N) (press Enter to cancel): " reset_confirm
        if [[ ! $reset_confirm =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            return
        fi
    fi

    # Reset UFW rules
    log_info "Resetting existing rules..."
    ufw --force reset

    # Set default policies
    log_info "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing

    # Ask for SSH port
    if [ "$AUTO_INSTALL" = "true" ]; then
        ssh_port=22
        log_info "Auto-install mode: Using default SSH port 22..."
    else
        read -p "Enter SSH port (default: 22) (press Enter for default): " ssh_port
        ssh_port=${ssh_port:-22}
    fi

    log_info "Allowing SSH port ${ssh_port}..."
    ufw allow ${ssh_port}/tcp comment 'SSH'

    # Automatically open HTTP and HTTPS
    log_info "Allowing HTTP port 80..."
    ufw allow 80/tcp comment 'HTTP'

    log_info "Allowing HTTPS port 443..."
    ufw allow 443/tcp comment 'HTTPS'

    # Enable UFW
    log_info "Enabling UFW firewall..."
    ufw --force enable

    # Display status
    log_success "UFW configuration complete! Current status:"
    ufw status verbose

    # Set to start on boot
    log_info "Setting UFW to start on boot..."
    systemctl enable ufw

    log_success "UFW firewall configuration complete! Opened ports: ${ssh_port}(SSH), 80(HTTP), 443(HTTPS)"
}

# Custom UFW configuration
configure_ufw_custom() {
    log_info "Configuring UFW firewall rules (custom mode)..."

    # Warn about resetting UFW
    echo ""
    log_warning "⚠️  IMPORTANT: Resetting UFW will temporarily remove all firewall rules!"
    log_warning "This may briefly interrupt your SSH connection if not configured properly."
    echo ""
    read -p "Continue with UFW reset? (y/N) (press Enter to cancel): " reset_confirm
    if [[ ! $reset_confirm =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        return
    fi

    # Reset UFW rules
    log_info "Resetting existing rules..."
    ufw --force reset

    # Set default policies
    log_info "Setting default policies..."
    ufw default deny incoming
    ufw default allow outgoing

    # Ask for SSH port
    read -p "Enter SSH port (default: 22) (press Enter for default): " ssh_port
    ssh_port=${ssh_port:-22}

    log_info "Allowing SSH port ${ssh_port}..."
    ufw allow ${ssh_port}/tcp comment 'SSH'

    # Ask about HTTP/HTTPS
    read -p "Open HTTP (80) port? (Y/n) (press Enter to confirm): " http_choice
    if [[ ! $http_choice =~ ^[Nn]$ ]]; then
        log_info "Allowing HTTP port 80..."
        ufw allow 80/tcp comment 'HTTP'
    fi

    read -p "Open HTTPS (443) port? (Y/n) (press Enter to confirm): " https_choice
    if [[ ! $https_choice =~ ^[Nn]$ ]]; then
        log_info "Allowing HTTPS port 443..."
        ufw allow 443/tcp comment 'HTTPS'
    fi

    # Ask about custom ports
    while true; do
        read -p "Do you need to open additional ports? (y/N) (press Enter to skip): " custom_choice
        if [[ $custom_choice =~ ^[Yy]$ ]]; then
            read -p "Enter port number: " custom_port
            read -p "Protocol (tcp/udp/both, default tcp) (press Enter for default): " protocol
            protocol=${protocol:-tcp}

            if [ "$protocol" == "both" ]; then
                ufw allow ${custom_port} comment 'Custom'
            else
                ufw allow ${custom_port}/${protocol} comment 'Custom'
            fi
            log_success "Port ${custom_port} (${protocol}) has been opened"
        else
            break
        fi
    done

    # Enable UFW
    log_info "Enabling UFW firewall..."
    ufw --force enable

    # Display status
    log_success "UFW configuration complete! Current status:"
    ufw status verbose

    # Set to start on boot
    log_info "Setting UFW to start on boot..."
    systemctl enable ufw

    log_success "UFW firewall installation and configuration complete!"
}

# Uninstall UFW
uninstall_ufw() {
    log_warning "Starting UFW firewall uninstallation..."

    if ! check_ufw_installed; then
        log_warning "UFW is not installed, no need to uninstall"
        return
    fi

    read -p "Are you sure you want to uninstall UFW? This will remove all firewall rules (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi

    detect_os

    # Stop and disable UFW
    log_info "Stopping UFW service..."
    ufw --force disable
    systemctl stop ufw
    systemctl disable ufw

    # Uninstall UFW
    case $OS in
        ubuntu|debian)
            log_info "Uninstalling UFW using APT..."
            apt-get purge -y ufw
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Uninstalling UFW using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf remove -y ufw
            else
                yum remove -y ufw
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Delete configuration files
    log_info "Deleting configuration files..."
    rm -rf /etc/ufw
    rm -f /etc/default/ufw

    if check_ufw_installed; then
        log_error "UFW uninstallation failed"
        exit 1
    else
        log_success "UFW uninstallation complete!"
    fi
}

# Display help
show_help() {
    echo "Usage: $0 {install-only|install-common|install-custom|uninstall}"
    echo ""
    echo "Commands:"
    echo "  install-only    - Install UFW only, without configuring rules"
    echo "  install-common  - Install UFW and open common ports (22, 80, 443)"
    echo "  install-custom  - Install UFW with custom configuration"
    echo "  uninstall       - Uninstall UFW"
    echo ""
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "$1" in
        install-only)
            install_only
            ;;
        install-common)
            install_common
            ;;
        install-custom)
            install_custom
            ;;
        uninstall)
            uninstall_ufw
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
