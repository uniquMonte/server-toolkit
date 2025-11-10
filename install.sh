#!/bin/bash

#######################################
# VPS Quick Setup Script
# Author: uniquMonte
# Purpose: Quickly deploy commonly used tools on newly purchased VPS
#######################################

# Error handling - exit on critical errors only
set -o pipefail

# Trap errors for cleanup
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code=$1
    local line_num=$2
    if [ $exit_code -ne 0 ]; then
        log_error "Error occurred at line $line_num with exit code $exit_code"
    fi
}

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

# Logging functions
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           VPS Quick Setup Script v1.0                     ║
║                                                           ║
║           Supported Components:                           ║
║           - System Update                                 ║
║           - UFW Firewall                                  ║
║           - Docker Container Engine                       ║
║           - Nginx + Certbot SSL Tool                      ║
║           - YABS Performance Test                         ║
║           - Fail2ban Brute Force Protection               ║
║           - SSH Security Configuration                    ║
║           - IP Quality Test                               ║
║           - Network Quality Test                          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Unable to detect operating system type"
        exit 1
    fi

    log_info "Detected operating system: ${OS} ${OS_VERSION}"

    # Check if the operating system is supported
    case $OS in
        ubuntu|debian|centos|fedora|rhel|rocky|almalinux)
            log_success "Operating system is supported"
            ;;
        *)
            log_warning "Untested operating system, issues may occur"
            ;;
    esac
}

# Check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "bash")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Please install them first and try again"
        exit 1
    fi
}

# Download script files (if executed via curl)
download_scripts() {
    if [ ! -d "$SCRIPTS_PATH" ]; then
        log_info "Remote execution detected, downloading script files..."

        REPO_URL="https://raw.githubusercontent.com/uniquMonte/vps-setup/main"
        TEMP_DIR="/tmp/vps-setup-$$"
        mkdir -p "$TEMP_DIR/scripts"

        SCRIPT_DIR="$TEMP_DIR"
        SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

        # Download all script files
        scripts=("system_update.sh" "ufw_manager.sh" "docker_manager.sh" "nginx_manager.sh" "yabs_test.sh" "fail2ban_manager.sh" "ssh_security.sh" "ip_quality_test.sh" "network_quality_test.sh")

        for script in "${scripts[@]}"; do
            log_info "Downloading ${script}..."
            if ! curl -fsSL "${REPO_URL}/scripts/${script}" -o "${SCRIPTS_PATH}/${script}"; then
                log_error "Failed to download ${script}"
                exit 1
            fi
            chmod +x "${SCRIPTS_PATH}/${script}"
        done

        log_success "Script files downloaded successfully"
    fi
}

# System update
system_update() {
    log_step "Performing system update..."
    if [ -f "${SCRIPTS_PATH}/system_update.sh" ]; then
        bash "${SCRIPTS_PATH}/system_update.sh"
    else
        log_error "System update script not found"
    fi
}

# UFW management menu
ufw_menu() {
    echo ""
    log_step "UFW Firewall Management"
    echo -e "${CYAN}1.${NC} Install UFW only (no rule configuration)"
    echo -e "${CYAN}2.${NC} Install UFW and open common ports (22, 80, 443)"
    echo -e "${CYAN}3.${NC} Install UFW with custom configuration"
    echo -e "${CYAN}4.${NC} Uninstall UFW"
    echo -e "${CYAN}5.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-5]: " ufw_choice

    case $ufw_choice in
        1)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-only
            ;;
        2)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common
            ;;
        3)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-custom
            ;;
        4)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" uninstall
            ;;
        5)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Docker management menu
docker_menu() {
    echo ""
    log_step "Docker Container Engine Management"
    echo -e "${CYAN}1.${NC} Install Docker"
    echo -e "${CYAN}2.${NC} Install Docker + Docker Compose"
    echo -e "${CYAN}3.${NC} Uninstall Docker"
    echo -e "${CYAN}4.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-4]: " docker_choice

    case $docker_choice in
        1)
            bash "${SCRIPTS_PATH}/docker_manager.sh" install
            ;;
        2)
            bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose
            ;;
        3)
            bash "${SCRIPTS_PATH}/docker_manager.sh" uninstall
            ;;
        4)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Nginx management menu
nginx_menu() {
    echo ""
    log_step "Nginx + Certbot Management"
    echo -e "${CYAN}1.${NC} Install Nginx"
    echo -e "${CYAN}2.${NC} Install Nginx + Certbot"
    echo -e "${CYAN}3.${NC} Uninstall Nginx"
    echo -e "${CYAN}4.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-4]: " nginx_choice

    case $nginx_choice in
        1)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" install
            ;;
        2)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot
            ;;
        3)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" uninstall
            ;;
        4)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# One-click install all components
install_all() {
    log_step "Starting one-click installation of all components..."

    # System update
    system_update

    # Install UFW and configure common ports
    bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common

    # Install Docker and Docker Compose
    bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose

    # Install Nginx and Certbot
    bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot

    log_success "All components installed successfully!"
}

# YABS performance test menu
yabs_test_menu() {
    if [ -f "${SCRIPTS_PATH}/yabs_test.sh" ]; then
        bash "${SCRIPTS_PATH}/yabs_test.sh" menu
    else
        log_error "YABS test script not found"
    fi
}

# Fail2ban management menu
fail2ban_menu() {
    echo ""
    log_step "Fail2ban Intrusion Prevention Management"
    echo -e "${CYAN}1.${NC} Install and configure Fail2ban"
    echo -e "${CYAN}2.${NC} View Fail2ban status"
    echo -e "${CYAN}3.${NC} View banned IPs"
    echo -e "${CYAN}4.${NC} Unban specific IP"
    echo -e "${CYAN}5.${NC} Uninstall Fail2ban"
    echo -e "${CYAN}6.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-6]: " fail2ban_choice

    case $fail2ban_choice in
        1)
            bash "${SCRIPTS_PATH}/fail2ban_manager.sh" install
            ;;
        2)
            bash "${SCRIPTS_PATH}/fail2ban_manager.sh" status
            ;;
        3)
            bash "${SCRIPTS_PATH}/fail2ban_manager.sh" show-banned
            ;;
        4)
            bash "${SCRIPTS_PATH}/fail2ban_manager.sh" unban
            ;;
        5)
            bash "${SCRIPTS_PATH}/fail2ban_manager.sh" uninstall
            ;;
        6)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# SSH security configuration menu
ssh_security_menu() {
    echo ""
    log_step "SSH Security Configuration"
    echo -e "${CYAN}1.${NC} Configure SSH key login"
    echo -e "${CYAN}2.${NC} Disable root password login"
    echo -e "${CYAN}3.${NC} Change SSH port"
    echo -e "${CYAN}4.${NC} Configure connection timeout"
    echo -e "${CYAN}5.${NC} Full security configuration (recommended)"
    echo -e "${CYAN}6.${NC} View current configuration"
    echo -e "${CYAN}7.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-7]: " ssh_choice

    case $ssh_choice in
        1)
            bash "${SCRIPTS_PATH}/ssh_security.sh" setup-key
            ;;
        2)
            bash "${SCRIPTS_PATH}/ssh_security.sh" disable-password
            ;;
        3)
            bash "${SCRIPTS_PATH}/ssh_security.sh" change-port
            ;;
        4)
            bash "${SCRIPTS_PATH}/ssh_security.sh" timeout
            ;;
        5)
            bash "${SCRIPTS_PATH}/ssh_security.sh" full
            ;;
        6)
            bash "${SCRIPTS_PATH}/ssh_security.sh" show
            ;;
        7)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# IP quality test menu
ip_quality_menu() {
    if [ -f "${SCRIPTS_PATH}/ip_quality_test.sh" ]; then
        bash "${SCRIPTS_PATH}/ip_quality_test.sh" menu
    else
        log_error "IP quality test script not found"
    fi
}

# Network quality test menu
network_quality_menu() {
    if [ -f "${SCRIPTS_PATH}/network_quality_test.sh" ]; then
        bash "${SCRIPTS_PATH}/network_quality_test.sh" menu
    else
        log_error "Network quality test script not found"
    fi
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}           Main Menu                   ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} One-click install all components"
        echo -e "${GREEN}2.${NC} System update"
        echo -e "${GREEN}3.${NC} UFW Firewall management"
        echo -e "${GREEN}4.${NC} Docker management"
        echo -e "${GREEN}5.${NC} Nginx management"
        echo -e "${YELLOW}6.${NC} Fail2ban brute force protection"
        echo -e "${YELLOW}7.${NC} SSH security configuration"
        echo -e "${PURPLE}8.${NC} YABS performance test"
        echo -e "${PURPLE}9.${NC} IP quality check"
        echo -e "${PURPLE}10.${NC} Network quality check"
        echo -e "${RED}0.${NC} Exit"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        read -p "Please select an action [0-10]: " choice

        case $choice in
            1)
                install_all
                ;;
            2)
                system_update
                ;;
            3)
                ufw_menu
                ;;
            4)
                docker_menu
                ;;
            5)
                nginx_menu
                ;;
            6)
                fail2ban_menu
                ;;
            7)
                ssh_security_menu
                ;;
            8)
                yabs_test_menu
                ;;
            9)
                ip_quality_menu
                ;;
            10)
                network_quality_menu
                ;;
            0)
                log_info "Thank you for using!"
                exit 0
                ;;
            *)
                log_error "Invalid selection, please try again"
                ;;
        esac
    done
}

# Main function
main() {
    # Clear screen
    clear

    # Print banner
    print_banner

    # Check root privileges
    check_root

    # Check dependencies
    check_dependencies

    # Detect operating system
    detect_os

    # Download scripts (if needed)
    download_scripts

    # Display main menu
    main_menu
}

# Execute main function
main "$@"
