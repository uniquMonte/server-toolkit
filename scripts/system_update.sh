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

            log_info "Preparing to install common tools..."
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}Installing the following tools:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "  📥 ${GREEN}Network Tools${NC}  : curl, wget"
            echo -e "  📝 ${GREEN}Version Control${NC}: git"
            echo -e "  ✏️  ${GREEN}Text Editors${NC}   : vim, nano"
            echo -e "  📊 ${GREEN}System Monitor${NC} : htop, net-tools"
            echo -e "  📦 ${GREEN}Compression${NC}    : unzip, zip, tar, gzip, bzip2"
            echo -e "  🔒 ${GREEN}Security Certs${NC} : ca-certificates, gnupg"
            echo -e "  ⚙️  ${GREEN}System Tools${NC}   : lsb-release, software-properties-common"
            echo -e "  🌐 ${GREEN}Transport${NC}      : apt-transport-https"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            log_info "Starting tool installation..."
            apt-get install -y \
                curl \
                wget \
                git \
                vim \
                nano \
                htop \
                net-tools \
                ca-certificates \
                gnupg \
                lsb-release \
                software-properties-common \
                apt-transport-https \
                unzip \
                zip \
                tar \
                gzip \
                bzip2

            log_info "Cleaning up unused packages..."
            apt-get autoremove -y
            apt-get autoclean -y

            echo ""
            log_success "Ubuntu/Debian system update complete"
            log_success "Common tools installed successfully!"
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

            log_info "Preparing to install common tools..."
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}Installing the following tools:${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "  📥 ${GREEN}Network Tools${NC}  : curl, wget"
            echo -e "  📝 ${GREEN}Version Control${NC}: git"
            echo -e "  ✏️  ${GREEN}Text Editors${NC}   : vim, nano"
            echo -e "  📊 ${GREEN}System Monitor${NC} : htop, net-tools"
            echo -e "  📦 ${GREEN}Compression${NC}    : unzip, zip, tar, gzip, bzip2"
            echo -e "  🔒 ${GREEN}Security Certs${NC} : ca-certificates, gnupg"
            echo -e "  ⚙️  ${GREEN}Package Tools${NC}  : yum-utils"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""

            log_info "Starting tool installation..."
            $PKG_MANAGER install -y \
                curl \
                wget \
                git \
                vim \
                nano \
                htop \
                net-tools \
                ca-certificates \
                gnupg \
                yum-utils \
                unzip \
                zip \
                tar \
                gzip \
                bzip2

            log_info "Cleaning cache..."
            $PKG_MANAGER clean all

            echo ""
            log_success "CentOS/RHEL/Rocky/AlmaLinux/Fedora system update complete"
            log_success "Common tools installed successfully!"
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    log_success "System update complete!"
}

# Install rclone
install_rclone() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}rclone - Cloud Storage Sync Tool${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ☁️  Supports 40+ cloud storage services"
    echo -e "  📦 Google Drive, Dropbox, OneDrive, S3, etc"
    echo -e "  🔄 File sync, backup, and mount features"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    log_info "Checking rclone installation status..."

    if command -v rclone &> /dev/null; then
        log_success "rclone is already installed"
        rclone version | head -n 1
        return
    fi

    log_info "Installing rclone (using official installation script)..."

    # Use official installation script
    if curl -fsSL https://rclone.org/install.sh | bash; then
        echo ""
        log_success "rclone installed successfully!"
        rclone version | head -n 1
        echo ""
        log_info "Usage tips:"
        echo -e "  ${GREEN}Configure rclone${NC}: rclone config"
        echo -e "  ${GREEN}View help${NC}      : rclone --help"
        echo -e "  ${GREEN}Documentation${NC}  : https://rclone.org/docs/"
    else
        log_error "Official script installation failed, trying repository installation..."

        # Manual installation method
        detect_os
        case $OS in
            ubuntu|debian)
                apt-get install -y rclone 2>/dev/null || log_warning "Repository installation failed, please visit https://rclone.org to install manually"
                ;;
            centos|rhel|rocky|almalinux|fedora)
                if command -v dnf &> /dev/null; then
                    dnf install -y rclone 2>/dev/null || log_warning "Repository installation failed, please visit https://rclone.org to install manually"
                else
                    yum install -y rclone 2>/dev/null || log_warning "Repository installation failed, please visit https://rclone.org to install manually"
                fi
                ;;
        esac

        if command -v rclone &> /dev/null; then
            log_success "rclone installed from system repository"
            rclone version | head -n 1
        fi
    fi
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    update_system

    # Install rclone
    echo ""
    read -p "Would you like to install rclone (cloud storage sync tool)? (Y/n): " install_rclone_choice
    if [[ ! $install_rclone_choice =~ ^[Nn]$ ]]; then
        install_rclone
    fi

    # Ask about reboot
    echo ""
    log_info "All updates completed!"
    log_info "It is recommended to reboot the system to apply all updates"

    read -p "Would you like to reboot now? (y/N): " restart_choice
    if [[ $restart_choice =~ ^[Yy]$ ]]; then
        log_info "System will reboot in 5 seconds..."
        sleep 5
        reboot
    fi
}

main "$@"
