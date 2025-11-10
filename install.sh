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

# Initialize remote execution mode (if executed via curl)
init_remote_mode() {
    if [ ! -d "$SCRIPTS_PATH" ]; then
        IS_REMOTE_MODE=true

        # Priority: CLI arg > env var > default (main)
        # SETUP_BRANCH is set in main() from command line args
        BRANCH="${SETUP_BRANCH:-${VPS_SETUP_BRANCH:-main}}"
        REPO_URL="https://raw.githubusercontent.com/uniquMonte/server-toolkit/${BRANCH}"
        TEMP_DIR="/tmp/vps-setup-$$"
        mkdir -p "$TEMP_DIR/scripts"

        SCRIPT_DIR="$TEMP_DIR"
        SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

        log_info "Remote execution mode enabled, scripts will be downloaded on demand"
        log_info "Using branch: ${BRANCH}"
    else
        IS_REMOTE_MODE=false
    fi
}

# Download a single script if needed (for remote execution)
download_script_if_needed() {
    local script_name="$1"
    local script_path="${SCRIPTS_PATH}/${script_name}"

    # If script already exists, no need to download
    if [ -f "$script_path" ]; then
        return 0
    fi

    # If not in remote execution mode, script should exist locally
    if [ "$IS_REMOTE_MODE" != "true" ]; then
        log_error "${script_name} not found at ${script_path}"
        return 1
    fi

    # Remote execution mode - download the script
    log_info "Downloading ${script_name}..."

    if ! curl -fsSL --proto '=https' --tlsv1.2 "${REPO_URL}/scripts/${script_name}" -o "${script_path}"; then
        log_error "Failed to download ${script_name}"
        log_error "URL: ${REPO_URL}/scripts/${script_name}"
        return 1
    fi

    chmod +x "${script_path}"
    return 0
}

# System update
system_update() {
    log_step "Performing system update..."
    if download_script_if_needed "system_update.sh"; then
        bash "${SCRIPTS_PATH}/system_update.sh"
    else
        log_error "Failed to load system update script"
    fi
}

# UFW management menu
ufw_menu() {
    if ! download_script_if_needed "ufw_manager.sh"; then
        log_error "Failed to load UFW manager script"
        return 1
    fi

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
    if ! download_script_if_needed "docker_manager.sh"; then
        log_error "Failed to load Docker manager script"
        return 1
    fi

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
    if ! download_script_if_needed "nginx_manager.sh"; then
        log_error "Failed to load Nginx manager script"
        return 1
    fi

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

    # Download all required scripts first
    local required_scripts=("system_update.sh" "ufw_manager.sh" "docker_manager.sh" "nginx_manager.sh")
    for script in "${required_scripts[@]}"; do
        if ! download_script_if_needed "$script"; then
            log_error "Failed to load $script, aborting installation"
            return 1
        fi
    done

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
    if download_script_if_needed "yabs_test.sh"; then
        bash "${SCRIPTS_PATH}/yabs_test.sh" menu
    else
        log_error "Failed to load YABS test script"
    fi
}

# Fail2ban management menu
fail2ban_menu() {
    if ! download_script_if_needed "fail2ban_manager.sh"; then
        log_error "Failed to load Fail2ban manager script"
        return 1
    fi

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
    if ! download_script_if_needed "ssh_security.sh"; then
        log_error "Failed to load SSH security script"
        return 1
    fi

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
    if download_script_if_needed "ip_quality_test.sh"; then
        bash "${SCRIPTS_PATH}/ip_quality_test.sh" menu
    else
        log_error "Failed to load IP quality test script"
    fi
}

# Network quality test menu
network_quality_menu() {
    if download_script_if_needed "network_quality_test.sh"; then
        bash "${SCRIPTS_PATH}/network_quality_test.sh" menu
    else
        log_error "Failed to load network quality test script"
    fi
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}           Main Menu                   ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} System update"
        echo -e "${GREEN}2.${NC} Complete essential setup (System/UFW/Docker/Nginx)"
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
        read -p "Please select an action [0-10, or press Enter to exit]: " choice

        case $choice in
            1)
                system_update
                ;;
            2)
                install_all
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
            0|"")
                log_info "Thank you for using!"
                exit 0
                ;;
            *)
                log_error "Invalid selection, please try again"
                ;;
        esac
    done
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                SETUP_BRANCH="$2"
                shift 2
                ;;
            --help|-h)
                echo "VPS Quick Setup Script"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --branch <name>    Specify git branch for remote script downloads"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "Examples:"
                echo "  # Use default (main) branch"
                echo "  bash install.sh"
                echo ""
                echo "  # Use specific branch for testing"
                echo "  bash install.sh --branch claude/review-script-optimization-011CUySPawcwxfwf39n9MnYv"
                echo ""
                echo "  # Remote execution with branch"
                echo "  curl -Ls https://raw.githubusercontent.com/.../install.sh | bash -s -- --branch dev"
                echo ""
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"

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

    # Initialize remote mode (if needed)
    init_remote_mode

    # Display main menu
    main_menu
}

# Execute main function
main "$@"
