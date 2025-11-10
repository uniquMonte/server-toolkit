#!/bin/bash

#######################################
# System Update Script
# Supports: Ubuntu, Debian, CentOS, Fedora, Rocky Linux, AlmaLinux
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

# Update system
update_system() {
    detect_os

    log_info "Starting system update..."

    case $OS in
        ubuntu|debian)
            log_info "Updating system using APT package manager..."
            export DEBIAN_FRONTEND=noninteractive

            log_info "Updating package lists..."
            apt-get update -y

            log_info "Upgrading installed packages..."
            apt-get upgrade -y

            log_info "Performing full upgrade..."
            apt-get full-upgrade -y

            log_info "Cleaning up unused packages..."
            apt-get autoremove -y
            apt-get autoclean -y

            echo ""
            log_success "Ubuntu/Debian system update complete"
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Updating system using YUM/DNF package manager..."

            # Check if dnf is available
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            log_info "Updating system packages..."
            $PKG_MANAGER update -y

            log_info "Cleaning cache..."
            $PKG_MANAGER clean all

            echo ""
            log_success "CentOS/RHEL/Rocky/AlmaLinux/Fedora system update complete"
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    log_success "System update complete!"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    update_system

    # Skip reboot prompt if --no-reboot-prompt is passed
    if [ "$1" = "--no-reboot-prompt" ]; then
        return 0
    fi

    # Ask about reboot
    echo ""
    log_info "All updates completed!"
    log_info "It is recommended to reboot the system to apply all updates"

    read -p "Would you like to reboot now? [Y/n, or press Enter to reboot]: " restart_choice
    if [[ ! $restart_choice =~ ^[Nn]$ ]]; then
        log_info "System will reboot in 5 seconds..."
        sleep 5
        reboot
    fi
}

main "$@"
