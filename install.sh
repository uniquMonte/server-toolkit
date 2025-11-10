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
║           - System Update & Basic Tools                   ║
║           - UFW Firewall / Docker / Nginx + Certbot       ║
║           - Fail2ban / SSH Security / BBR Optimization    ║
║           - Timezone & NTP / Hostname / Log Management    ║
║           - YABS / IP Quality / Network Quality Tests     ║
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

    # If script already exists and not forcing update, no need to download
    if [ -f "$script_path" ] && [ "$FORCE_UPDATE" != "true" ]; then
        return 0
    fi

    # If not in remote execution mode, script should exist locally
    if [ "$IS_REMOTE_MODE" != "true" ]; then
        log_error "${script_name} not found at ${script_path}"
        return 1
    fi

    # Remote execution mode - download the script
    if [ "$FORCE_UPDATE" = "true" ] && [ -f "$script_path" ]; then
        log_info "Force updating ${script_name}..."
    else
        log_info "Downloading ${script_name}..."
    fi

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
        bash "${SCRIPTS_PATH}/system_update.sh" "$@"
    else
        log_error "Failed to load system update script"
    fi
}

# Basic tools installation
basic_tools() {
    log_step "Installing basic tools..."
    if download_script_if_needed "basic_tools.sh"; then
        bash "${SCRIPTS_PATH}/basic_tools.sh"
    else
        log_error "Failed to load basic tools script"
    fi
}

# BBR management menu
bbr_menu() {
    if ! download_script_if_needed "bbr_manager.sh"; then
        log_error "Failed to load BBR manager script"
        return 1
    fi

    echo ""
    log_step "BBR TCP Congestion Control"

    # Show current status first
    bash "${SCRIPTS_PATH}/bbr_manager.sh" status

    echo ""
    echo -e "${CYAN}1.${NC} Enable BBR"
    echo -e "${CYAN}2.${NC} Disable BBR"
    echo -e "${CYAN}3.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-3]: " bbr_choice

    case $bbr_choice in
        1)
            bash "${SCRIPTS_PATH}/bbr_manager.sh" enable
            ;;
        2)
            bash "${SCRIPTS_PATH}/bbr_manager.sh" disable
            ;;
        3)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Timezone and NTP management menu
timezone_ntp_menu() {
    if ! download_script_if_needed "timezone_ntp.sh"; then
        log_error "Failed to load timezone/NTP script"
        return 1
    fi

    echo ""
    log_step "Timezone and NTP Time Synchronization"

    # Show current status first
    bash "${SCRIPTS_PATH}/timezone_ntp.sh" status

    echo ""
    echo -e "${CYAN}1.${NC} Set timezone to Asia/Shanghai"
    echo -e "${CYAN}2.${NC} Enable NTP time synchronization"
    echo -e "${CYAN}3.${NC} Configure both (recommended)"
    echo -e "${CYAN}4.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-4]: " tz_choice

    case $tz_choice in
        1)
            bash "${SCRIPTS_PATH}/timezone_ntp.sh" timezone
            ;;
        2)
            bash "${SCRIPTS_PATH}/timezone_ntp.sh" ntp
            ;;
        3)
            bash "${SCRIPTS_PATH}/timezone_ntp.sh" all
            ;;
        4)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Hostname management menu
hostname_menu() {
    if ! download_script_if_needed "hostname_manager.sh"; then
        log_error "Failed to load hostname manager script"
        return 1
    fi

    echo ""
    log_step "Hostname Modification"

    # Show current status first
    bash "${SCRIPTS_PATH}/hostname_manager.sh" status

    echo ""
    echo -e "${CYAN}1.${NC} Change hostname (interactive)"
    echo -e "${CYAN}2.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-2]: " hostname_choice

    case $hostname_choice in
        1)
            bash "${SCRIPTS_PATH}/hostname_manager.sh" interactive
            ;;
        2)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Log management menu
log_management_menu() {
    if ! download_script_if_needed "log_manager.sh"; then
        log_error "Failed to load log manager script"
        return 1
    fi

    echo ""
    log_step "System and Docker Log Management"

    # Show current status first
    bash "${SCRIPTS_PATH}/log_manager.sh" status

    echo ""
    echo -e "${CYAN}1.${NC} Apply intelligent log configuration (recommended)"
    echo -e "${CYAN}2.${NC} Configure Docker logs only"
    echo -e "${CYAN}3.${NC} Configure system journal only"
    echo -e "${CYAN}4.${NC} Clean old logs"
    echo -e "${CYAN}5.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-5]: " log_choice

    case $log_choice in
        1)
            bash "${SCRIPTS_PATH}/log_manager.sh" configure
            ;;
        2)
            bash "${SCRIPTS_PATH}/log_manager.sh" docker
            ;;
        3)
            bash "${SCRIPTS_PATH}/log_manager.sh" journald
            ;;
        4)
            bash "${SCRIPTS_PATH}/log_manager.sh" clean
            ;;
        5)
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
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
    log_step "Starting complete setup (all-in-one)..."

    # Download all required scripts first
    local required_scripts=("system_update.sh" "basic_tools.sh" "ufw_manager.sh" "docker_manager.sh" "nginx_manager.sh")
    for script in "${required_scripts[@]}"; do
        if ! download_script_if_needed "$script"; then
            log_error "Failed to load $script, aborting installation"
            return 1
        fi
    done

    # Pre-installation detection
    echo ""
    log_info "Checking current installation status..."
    echo ""

    local ufw_before=$(command -v ufw &> /dev/null && echo "installed" || echo "not_installed")
    local docker_before=$(command -v docker &> /dev/null && echo "installed" || echo "not_installed")
    local docker_compose_before=$(command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1 && echo "installed" || echo "not_installed")
    local nginx_before=$(command -v nginx &> /dev/null && echo "installed" || echo "not_installed")
    local certbot_before=$(command -v certbot &> /dev/null && echo "installed" || echo "not_installed")

    # Display pre-installation status
    echo -e "${CYAN}Current Status:${NC}"
    echo -e "  UFW Firewall      : $([ "$ufw_before" = "installed" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo -e "  Docker Engine     : $([ "$docker_before" = "installed" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo -e "  Docker Compose    : $([ "$docker_compose_before" = "installed" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo -e "  Nginx             : $([ "$nginx_before" = "installed" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo -e "  Certbot           : $([ "$certbot_before" = "installed" ] && echo -e "${GREEN}Installed${NC}" || echo -e "${YELLOW}Not installed${NC}")"
    echo ""

    # System update (skip reboot prompt in complete setup)
    system_update --no-reboot-prompt

    # Install basic tools
    basic_tools

    # Install UFW and configure common ports
    if [ "$ufw_before" = "not_installed" ]; then
        log_step "Installing UFW firewall..."
        bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common
    else
        log_info "UFW already installed, skipping..."
    fi

    # Install Docker and Docker Compose
    if [ "$docker_before" = "not_installed" ]; then
        log_step "Installing Docker and Docker Compose..."
        bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose
    else
        log_info "Docker already installed, skipping..."
    fi

    # Install Nginx and Certbot
    if [ "$nginx_before" = "not_installed" ]; then
        log_step "Installing Nginx and Certbot..."
        bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot
    else
        log_info "Nginx already installed, skipping..."
    fi

    # Post-installation detection
    local ufw_after=$(command -v ufw &> /dev/null && echo "installed" || echo "not_installed")
    local docker_after=$(command -v docker &> /dev/null && echo "installed" || echo "not_installed")
    local docker_compose_after=$(command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1 && echo "installed" || echo "not_installed")
    local nginx_after=$(command -v nginx &> /dev/null && echo "installed" || echo "not_installed")
    local certbot_after=$(command -v certbot &> /dev/null && echo "installed" || echo "not_installed")

    # Categorize components
    local newly_installed=()
    local already_latest=()

    [ "$ufw_before" = "not_installed" ] && [ "$ufw_after" = "installed" ] && newly_installed+=("UFW Firewall")
    [ "$ufw_before" = "installed" ] && already_latest+=("UFW Firewall")

    [ "$docker_before" = "not_installed" ] && [ "$docker_after" = "installed" ] && newly_installed+=("Docker Engine")
    [ "$docker_before" = "installed" ] && already_latest+=("Docker Engine")

    [ "$docker_compose_before" = "not_installed" ] && [ "$docker_compose_after" = "installed" ] && newly_installed+=("Docker Compose")
    [ "$docker_compose_before" = "installed" ] && already_latest+=("Docker Compose")

    [ "$nginx_before" = "not_installed" ] && [ "$nginx_after" = "installed" ] && newly_installed+=("Nginx")
    [ "$nginx_before" = "installed" ] && already_latest+=("Nginx")

    [ "$certbot_before" = "not_installed" ] && [ "$certbot_after" = "installed" ] && newly_installed+=("Certbot")
    [ "$certbot_before" = "installed" ] && already_latest+=("Certbot")

    # Display comprehensive summary
    echo ""
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${GREEN}Complete Setup Summary${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${YELLOW}System Updates:${NC}"
    echo -e "  ${GREEN}✓${NC} System packages updated"
    echo ""

    echo -e "${YELLOW}Basic Tools:${NC}"
    echo -e "  ${CYAN}Note:${NC} See basic tools installation output above for details"
    echo ""

    if [ ${#newly_installed[@]} -gt 0 ]; then
        echo -e "${YELLOW}Newly Installed Services:${NC}"
        for service in "${newly_installed[@]}"; do
            echo -e "  ${GREEN}✓${NC} $service"
        done
        echo ""
    fi

    if [ ${#already_latest[@]} -gt 0 ]; then
        echo -e "${YELLOW}Already Installed (Skipped):${NC}"
        for service in "${already_latest[@]}"; do
            echo -e "  ${BLUE}○${NC} $service - already installed"
        done
        echo ""
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Installed Services Status:${NC}"
    if command -v ufw &> /dev/null; then
        local ufw_ver=$(ufw version 2>/dev/null | head -n1 | grep -o '[0-9.]*' | head -n1)
        [ -n "$ufw_ver" ] && echo -e "  ${GREEN}✓${NC} UFW Firewall - v${ufw_ver}" || echo -e "  ${GREEN}✓${NC} UFW Firewall - installed"
    fi
    if command -v docker &> /dev/null; then
        local docker_ver=$(docker --version 2>/dev/null | grep -o '[0-9.]*' | head -n1)
        [ -n "$docker_ver" ] && echo -e "  ${GREEN}✓${NC} Docker - v${docker_ver}" || echo -e "  ${GREEN}✓${NC} Docker - installed"
    fi
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        local dc_ver=$(docker-compose --version 2>/dev/null | grep -o '[0-9.]*' | head -n1)
        if [ -z "$dc_ver" ]; then
            dc_ver=$(docker compose version 2>/dev/null | grep -o '[0-9.]*' | head -n1)
        fi
        [ -n "$dc_ver" ] && echo -e "  ${GREEN}✓${NC} Docker Compose - v${dc_ver}" || echo -e "  ${GREEN}✓${NC} Docker Compose - installed"
    fi
    if command -v nginx &> /dev/null; then
        local nginx_ver=$(nginx -v 2>&1 | grep -o '[0-9.]*' | head -n1)
        [ -n "$nginx_ver" ] && echo -e "  ${GREEN}✓${NC} Nginx - v${nginx_ver}" || echo -e "  ${GREEN}✓${NC} Nginx - installed"
    fi
    if command -v certbot &> /dev/null; then
        local certbot_ver=$(certbot --version 2>/dev/null | grep -o '[0-9.]*' | head -n1)
        [ -n "$certbot_ver" ] && echo -e "  ${GREEN}✓${NC} Certbot - v${certbot_ver}" || echo -e "  ${GREEN}✓${NC} Certbot - installed"
    fi
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Next Steps:${NC}"
    if command -v ufw &> /dev/null; then
        echo -e "  • Check UFW status: ${CYAN}ufw status${NC}"
    fi
    if command -v docker &> /dev/null; then
        echo -e "  • Check Docker: ${CYAN}docker ps${NC}"
    fi
    if command -v nginx &> /dev/null; then
        echo -e "  • Check Nginx: ${CYAN}systemctl status nginx${NC}"
    fi
    if command -v certbot &> /dev/null; then
        echo -e "  • Configure SSL: ${CYAN}certbot --nginx -d yourdomain.com${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    log_success "Complete setup finished successfully!"

    # Ask about reboot at the end
    echo ""
    log_info "It is recommended to reboot the system to apply all updates"
    read -p "Would you like to reboot now? [Y/n, or press Enter to reboot]: " restart_choice
    if [[ ! $restart_choice =~ ^[Nn]$ ]]; then
        log_info "System will reboot in 5 seconds..."
        sleep 5
        reboot
    else
        log_info "Skipping reboot. You can reboot later by running: reboot"
    fi
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
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}              Main Menu${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${CYAN}┌─ Basic System Setup ─────────────────┐${NC}"
        echo -e "${GREEN}1.${NC} System update"
        echo -e "${GREEN}2.${NC} Install basic tools"
        echo -e "${GREEN}3.${NC} Complete setup (all-in-one)"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Service Management ─────────────────┐${NC}"
        echo -e "${GREEN}4.${NC} UFW Firewall management"
        echo -e "${GREEN}5.${NC} Docker management"
        echo -e "${GREEN}6.${NC} Nginx management"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Security & Optimization ────────────┐${NC}"
        echo -e "${YELLOW}7.${NC} Fail2ban brute force protection"
        echo -e "${YELLOW}8.${NC} SSH security configuration"
        echo -e "${YELLOW}9.${NC} BBR TCP optimization"
        echo -e "${YELLOW}10.${NC} Timezone and NTP sync"
        echo -e "${YELLOW}11.${NC} Hostname modification"
        echo -e "${YELLOW}12.${NC} Log management (system & Docker)"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ VPS Testing Tools ──────────────────┐${NC}"
        echo -e "${PURPLE}13.${NC} YABS performance test"
        echo -e "${PURPLE}14.${NC} IP quality check"
        echo -e "${PURPLE}15.${NC} Network quality check"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${RED}0.${NC} Exit"
        echo ""
        read -p "Please select an action [0-15, or press Enter to exit]: " choice

        case $choice in
            1)
                system_update
                ;;
            2)
                basic_tools
                ;;
            3)
                install_all
                ;;
            4)
                ufw_menu
                ;;
            5)
                docker_menu
                ;;
            6)
                nginx_menu
                ;;
            7)
                fail2ban_menu
                ;;
            8)
                ssh_security_menu
                ;;
            9)
                bbr_menu
                ;;
            10)
                timezone_ntp_menu
                ;;
            11)
                hostname_menu
                ;;
            12)
                log_management_menu
                ;;
            13)
                yabs_test_menu
                ;;
            14)
                ip_quality_menu
                ;;
            15)
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
            --force-update|--refresh)
                FORCE_UPDATE="true"
                shift
                ;;
            --help|-h)
                echo "VPS Quick Setup Script"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --branch <name>       Specify git branch for remote script downloads"
                echo "  --force-update        Force re-download all scripts (clear cache)"
                echo "  --refresh             Same as --force-update"
                echo "  --help, -h            Show this help message"
                echo ""
                echo "Examples:"
                echo "  # Use default (main) branch"
                echo "  bash install.sh"
                echo ""
                echo "  # Force refresh cached scripts"
                echo "  bash install.sh --force-update"
                echo ""
                echo "  # Use specific branch for testing"
                echo "  bash install.sh --branch claude/review-script-optimization-011CUySPawcwxfwf39n9MnYv"
                echo ""
                echo "  # Remote execution with force update"
                echo "  curl -Ls https://raw.githubusercontent.com/.../install.sh | bash -s -- --force-update"
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

    # Show force update message if enabled
    if [ "$FORCE_UPDATE" = "true" ]; then
        log_info "Force update mode enabled - all scripts will be re-downloaded"
        echo ""
    fi

    # Display main menu
    main_menu
}

# Execute main function
main "$@"
