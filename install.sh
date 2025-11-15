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
║           - Fail2ban / SSH Security / SSH Notifications   ║
║           - BBR / Timezone & NTP / Hostname / Logs        ║
║           - Swap / Traffic Monitor / Backup Manager       ║
║           - YABS / IP Quality / Network Quality Tests     ║
║           - Streaming & AI Unlock Check                   ║
║           - System Reinstallation (DD)                    ║
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

    while true; do
        echo ""
        log_step "BBR TCP Congestion Control"

        # Show current status
        echo ""
        bash "${SCRIPTS_PATH}/bbr_manager.sh" status

        echo ""
        echo -e "${CYAN}1.${NC} Enable BBR"
        echo -e "${CYAN}2.${NC} Disable BBR"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-2, or press Enter to return]: " bbr_choice

        case $bbr_choice in
            1)
                bash "${SCRIPTS_PATH}/bbr_manager.sh" enable
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/bbr_manager.sh" disable
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# Timezone and NTP management menu
timezone_ntp_menu() {
    if ! download_script_if_needed "timezone_ntp.sh"; then
        log_error "Failed to load timezone/NTP script"
        return 1
    fi

    while true; do
        echo ""
        log_step "Timezone and NTP Time Synchronization"

        # Show current status
        echo ""
        bash "${SCRIPTS_PATH}/timezone_ntp.sh" status

        echo ""
        echo -e "${CYAN}1.${NC} Set timezone to Asia/Shanghai"
        echo -e "${CYAN}2.${NC} Enable NTP time synchronization"
        echo -e "${CYAN}3.${NC} Configure both (recommended)"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-3, or press Enter for option 3]: " tz_choice
        tz_choice="${tz_choice:-3}"

        case $tz_choice in
            1)
                bash "${SCRIPTS_PATH}/timezone_ntp.sh" timezone
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/timezone_ntp.sh" ntp
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/timezone_ntp.sh" all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# Hostname management menu
hostname_menu() {
    if ! download_script_if_needed "hostname_manager.sh"; then
        log_error "Failed to load hostname manager script"
        return 1
    fi

    while true; do
        echo ""
        log_step "Hostname Modification"

        # Show current status
        echo ""
        bash "${SCRIPTS_PATH}/hostname_manager.sh" status

        echo ""
        echo -e "${CYAN}1.${NC} Change hostname (interactive)"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-1, or press Enter to return]: " hostname_choice

        case $hostname_choice in
            1)
                bash "${SCRIPTS_PATH}/hostname_manager.sh" interactive
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# Log management menu
log_management_menu() {
    if ! download_script_if_needed "log_manager.sh"; then
        log_error "Failed to load log manager script"
        return 1
    fi

    while true; do
        echo ""
        log_step "System and Docker Log Management"

        # Show current status
        echo ""
        bash "${SCRIPTS_PATH}/log_manager.sh" status

        echo ""
        echo -e "${CYAN}1.${NC} Apply intelligent log configuration (recommended)"
        echo -e "${CYAN}2.${NC} Configure Docker logs only"
        echo -e "${CYAN}3.${NC} Configure system journal only"
        echo -e "${CYAN}4.${NC} Configure Nginx logs only"
        echo -e "${CYAN}5.${NC} Clean old logs"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-5, or press Enter to return]: " log_choice

        case $log_choice in
            1)
                bash "${SCRIPTS_PATH}/log_manager.sh" configure
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/log_manager.sh" docker
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/log_manager.sh" journald
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "${SCRIPTS_PATH}/log_manager.sh" nginx
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                bash "${SCRIPTS_PATH}/log_manager.sh" clean
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# UFW management menu
ufw_menu() {
    if ! download_script_if_needed "ufw_manager.sh"; then
        log_error "Failed to load UFW manager script"
        return 1
    fi

    while true; do
        # Clear command cache to ensure accurate status detection
        hash -r 2>/dev/null || true

        echo ""
        log_step "UFW Firewall Management"

        # Show UFW status
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}UFW Firewall Status${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if command -v ufw &> /dev/null; then
            echo -e "${GREEN}Installation Status:${NC}  ${GREEN}Installed ✓${NC}"

            # Check if UFW is active
            if ufw status | grep -q "Status: active"; then
                echo -e "${GREEN}Service Status:${NC}      ${GREEN}Active ✓${NC}"
                echo ""
                echo -e "${GREEN}Current Firewall Rules:${NC}"
                ufw status numbered | tail -n +4
            else
                echo -e "${YELLOW}Service Status:${NC}      ${YELLOW}Inactive${NC}"
            fi
        else
            echo -e "${YELLOW}Installation Status:${NC}  ${YELLOW}Not installed${NC}"
            echo ""
            echo -e "${CYAN}UFW (Uncomplicated Firewall) provides:${NC}"
            echo -e "  ${GREEN}•${NC} Easy-to-use firewall management"
            echo -e "  ${GREEN}•${NC} Protection against unauthorized access"
            echo -e "  ${GREEN}•${NC} Simple port and service configuration"
        fi

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo -e "${CYAN}1.${NC} Install UFW only (no rule configuration)"
        echo -e "${CYAN}2.${NC} Install UFW and open common ports (22, 80, 443)"
        echo -e "${CYAN}3.${NC} Install UFW with custom configuration"
        echo -e "${CYAN}4.${NC} Uninstall UFW"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-4, or press Enter to return]: " ufw_choice

        case $ufw_choice in
            1)
                bash "${SCRIPTS_PATH}/ufw_manager.sh" install-only
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                AUTO_INSTALL=true bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/ufw_manager.sh" install-custom
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "${SCRIPTS_PATH}/ufw_manager.sh" uninstall
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# Docker management menu
docker_menu() {
    if ! download_script_if_needed "docker_manager.sh"; then
        log_error "Failed to load Docker manager script"
        return 1
    fi

    while true; do
        # Clear command cache to ensure accurate status detection
        hash -r 2>/dev/null || true

        echo ""
        log_step "Docker Container Engine Management"

        # Show Docker status
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Docker Status${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if command -v docker &> /dev/null; then
            echo -e "${GREEN}Docker Engine:${NC}       ${GREEN}Installed ✓${NC}"
            docker --version 2>/dev/null | sed 's/^/                       /'

            # Check if Docker service is running
            if systemctl is-active --quiet docker 2>/dev/null; then
                echo -e "${GREEN}Service Status:${NC}      ${GREEN}Running ✓${NC}"
            else
                echo -e "${YELLOW}Service Status:${NC}      ${YELLOW}Stopped${NC}"
            fi
        else
            echo -e "${YELLOW}Docker Engine:${NC}       ${YELLOW}Not installed${NC}"
        fi

        # Check Docker Compose
        if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            echo -e "${GREEN}Docker Compose:${NC}      ${GREEN}Installed ✓${NC}"
            docker compose version 2>/dev/null | sed 's/^/                       /'
        else
            echo -e "${YELLOW}Docker Compose:${NC}      ${YELLOW}Not installed${NC}"
        fi

        if ! command -v docker &> /dev/null; then
            echo ""
            echo -e "${CYAN}Docker provides:${NC}"
            echo -e "  ${GREEN}•${NC} Container isolation and management"
            echo -e "  ${GREEN}•${NC} Lightweight virtualization"
            echo -e "  ${GREEN}•${NC} Easy application deployment"
        fi

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo -e "${CYAN}1.${NC} Install Docker + Docker Compose"
        echo -e "${CYAN}2.${NC} Uninstall Docker"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-2, or press Enter for option 1]: " docker_choice

        # Set default to option 1 if Enter is pressed
        docker_choice=${docker_choice:-1}

        case $docker_choice in
            1)
                bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/docker_manager.sh" uninstall
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0)
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# Nginx management menu
nginx_menu() {
    if ! download_script_if_needed "nginx_manager.sh"; then
        log_error "Failed to load Nginx manager script"
        return 1
    fi

    while true; do
        # Clear command cache to ensure accurate status detection
        hash -r 2>/dev/null || true

        echo ""
        log_step "Nginx + Certbot Management"

        # Show Nginx status
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Nginx Status${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if command -v nginx &> /dev/null; then
            echo -e "${GREEN}Nginx:${NC}               ${GREEN}Installed ✓${NC}"
            nginx -v 2>&1 | sed 's/^/                       /'

            # Check if Nginx service is running
            if systemctl is-active --quiet nginx 2>/dev/null; then
                echo -e "${GREEN}Service Status:${NC}      ${GREEN}Running ✓${NC}"
            else
                echo -e "${YELLOW}Service Status:${NC}      ${YELLOW}Stopped${NC}"
            fi
        else
            echo -e "${YELLOW}Nginx:${NC}               ${YELLOW}Not installed${NC}"
        fi

        # Check Certbot
        if command -v certbot &> /dev/null; then
            echo -e "${GREEN}Certbot:${NC}             ${GREEN}Installed ✓${NC}"
            certbot --version 2>&1 | head -n1 | sed 's/^/                       /'
        else
            echo -e "${YELLOW}Certbot:${NC}             ${YELLOW}Not installed${NC}"
        fi

        if ! command -v nginx &> /dev/null; then
            echo ""
            echo -e "${CYAN}Nginx provides:${NC}"
            echo -e "  ${GREEN}•${NC} High-performance web server"
            echo -e "  ${GREEN}•${NC} Reverse proxy and load balancing"
            echo -e "  ${GREEN}•${NC} SSL/TLS certificate management with Certbot"
        fi

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo -e "${CYAN}1.${NC} Install Nginx"
        echo -e "${CYAN}2.${NC} Install Nginx + Certbot"
        echo -e "${CYAN}3.${NC} Uninstall Nginx + Certbot"
        echo -e "${CYAN}4.${NC} Uninstall Nginx only"
        echo -e "${CYAN}5.${NC} Uninstall Certbot only"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-5, or press Enter to return]: " nginx_choice

        case $nginx_choice in
            1)
                bash "${SCRIPTS_PATH}/nginx_manager.sh" install
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/nginx_manager.sh" uninstall-all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "${SCRIPTS_PATH}/nginx_manager.sh" uninstall
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                bash "${SCRIPTS_PATH}/nginx_manager.sh" uninstall-certbot
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# One-click install all components
install_all() {
    log_step "Starting complete setup (all-in-one)..."

    # Enable auto-install mode (skip all prompts)
    export AUTO_INSTALL=true

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

    while true; do
        # Clear command cache to ensure accurate status detection
        hash -r 2>/dev/null || true

        echo ""
        log_step "Fail2ban Intrusion Prevention Management"

        # Show Fail2ban status
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Fail2ban Status${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        if command -v fail2ban-client &> /dev/null; then
            echo -e "${GREEN}Fail2ban:${NC}            ${GREEN}Installed ✓${NC}"
            fail2ban-client version 2>/dev/null | head -n1 | sed 's/^/                       /'

            # Check if Fail2ban service is running
            if systemctl is-active --quiet fail2ban 2>/dev/null; then
                echo -e "${GREEN}Service Status:${NC}      ${GREEN}Running ✓${NC}"
            else
                echo -e "${YELLOW}Service Status:${NC}      ${YELLOW}Stopped${NC}"
            fi
        else
            echo -e "${YELLOW}Fail2ban:${NC}            ${YELLOW}Not installed${NC}"
        fi

        if ! command -v fail2ban-client &> /dev/null; then
            echo ""
            echo -e "${CYAN}Fail2ban provides:${NC}"
            echo -e "  ${GREEN}•${NC} Prevents SSH brute force attacks"
            echo -e "  ${GREEN}•${NC} Automatically bans malicious IPs"
            echo -e "  ${GREEN}•${NC} Protection for multiple services"
        fi

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo -e "${CYAN}1.${NC} Install and configure Fail2ban"
        echo -e "${CYAN}2.${NC} View Fail2ban status"
        echo -e "${CYAN}3.${NC} View configuration"
        echo -e "${CYAN}4.${NC} View banned IPs"
        echo -e "${CYAN}5.${NC} Unban specific IP"
        echo -e "${CYAN}6.${NC} Uninstall Fail2ban"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-6, or press Enter to return]: " fail2ban_choice

        case $fail2ban_choice in
            1)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" install
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" show-config
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" show-banned
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" unban
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                bash "${SCRIPTS_PATH}/fail2ban_manager.sh" uninstall
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
}

# SSH security configuration menu
ssh_security_menu() {
    if ! download_script_if_needed "ssh_security.sh"; then
        log_error "Failed to load SSH security script"
        return 1
    fi

    while true; do
        echo ""
        log_step "SSH Security Configuration"

        # Show current status
        echo ""
        bash "${SCRIPTS_PATH}/ssh_security.sh" show

        echo ""
        echo -e "${CYAN}1.${NC} Configure SSH key login"
        echo -e "${CYAN}2.${NC} Disable root password login"
        echo -e "${CYAN}3.${NC} Change SSH port"
        echo -e "${CYAN}4.${NC} Configure connection timeout"
        echo -e "${CYAN}5.${NC} Full security configuration (recommended)"
        echo -e "${CYAN}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an action [0-5, or press Enter to return]: " ssh_choice

        case $ssh_choice in
            1)
                bash "${SCRIPTS_PATH}/ssh_security.sh" setup-key
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                bash "${SCRIPTS_PATH}/ssh_security.sh" disable-password
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                bash "${SCRIPTS_PATH}/ssh_security.sh" change-port
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                bash "${SCRIPTS_PATH}/ssh_security.sh" timeout
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                bash "${SCRIPTS_PATH}/ssh_security.sh" full
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|"")
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection"
                sleep 1
                ;;
        esac
    done
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

# Streaming and AI unlock check menu
unlock_check_menu() {
    if download_script_if_needed "unlock_check.sh"; then
        bash "${SCRIPTS_PATH}/unlock_check.sh" menu
    else
        log_error "Failed to load unlock check script"
    fi
}

# Swap management menu
swap_menu() {
    if ! download_script_if_needed "swap_manager.sh"; then
        log_error "Failed to load swap manager script"
        return 1
    fi

    echo ""
    log_step "Swap Memory Management"

    # Launch the swap manager
    bash "${SCRIPTS_PATH}/swap_manager.sh" menu
}

# Traffic reporter management menu
traffic_reporter_menu() {
    echo ""
    log_step "Server Traffic Reporter"
    echo ""

    log_info "Launching Server Traffic Reporter management..."
    log_info "Project: https://github.com/uniquMonte/server-traffic-reporter"
    echo ""

    # Directly call the original project script
    # It will detect if already installed and show the management menu
    if command -v curl &> /dev/null; then
        curl -Ls https://raw.githubusercontent.com/uniquMonte/server-traffic-reporter/main/install.sh | bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/server-traffic-reporter/main/install.sh | bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi
}

# SSH login notifier management menu
ssh_login_notifier_menu() {
    echo ""
    log_step "SSH Login Notifier"
    echo ""

    log_info "Launching SSH Login Notifier management..."
    log_info "Project: https://github.com/uniquMonte/ssh-login-notifier"
    echo ""

    # Directly call the original project script
    # It will detect if already installed and show the management menu
    if command -v curl &> /dev/null; then
        curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi
}

# Backup management menu
backup_manager_menu() {
    echo ""
    log_step "Server Backup Manager"
    echo ""
    log_info "Launching Server Backup..."
    echo ""

    # Directly run the server-backup project's installation script
    # This will use their own menu system
    if command -v curl &> /dev/null; then
        bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-backup/main/install.sh)
    elif command -v wget &> /dev/null; then
        bash <(wget -qO- https://raw.githubusercontent.com/uniquMonte/server-backup/main/install.sh)
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi
}

# DD system reinstallation menu
dd_system_menu() {
    if ! download_script_if_needed "dd_system.sh"; then
        log_error "Failed to load DD system script"
        return 1
    fi

    echo ""
    log_step "System Reinstallation (DD)"

    # Show current system info
    bash "${SCRIPTS_PATH}/dd_system.sh" info

    echo ""
    echo -e "${CYAN}1.${NC} Reinstall operating system"
    echo -e "${CYAN}2.${NC} Return to main menu"
    echo ""
    read -p "Please select an action [1-2, or press Enter to return to main menu]: " dd_choice

    case $dd_choice in
        1)
            bash "${SCRIPTS_PATH}/dd_system.sh" reinstall
            ;;
        2|"")
            return
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

# Lightpath manager menu (Xray Reality Protocol)
# AdGuardHome manager menu
adguardhome_menu() {
    if ! download_script_if_needed "adguardhome_manager.sh"; then
        log_error "Failed to load AdGuardHome manager script"
        return 1
    fi

    # Make script executable
    chmod +x "${SCRIPTS_PATH}/adguardhome_manager.sh"

    # Run the AdGuardHome manager (it has its own menu system)
    bash "${SCRIPTS_PATH}/adguardhome_manager.sh"
}

# Lightpath manager menu (Network acceleration)
lightpath_menu() {
    if ! download_script_if_needed "lightpath_manager.sh"; then
        log_error "Failed to load Lightpath manager script"
        return 1
    fi

    # Make script executable
    chmod +x "${SCRIPTS_PATH}/lightpath_manager.sh"

    # Run the Lightpath manager (it has its own menu system)
    bash "${SCRIPTS_PATH}/lightpath_manager.sh"
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
        echo -e "${GREEN} 1.${NC} System update"
        echo -e "${GREEN} 2.${NC} Install basic tools"
        echo -e "${GREEN} 3.${NC} Complete setup (all-in-one)"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Service Management ─────────────────┐${NC}"
        echo -e "${GREEN} 4.${NC} UFW Firewall management"
        echo -e "${GREEN} 5.${NC} Docker management"
        echo -e "${GREEN} 6.${NC} Nginx management"
        echo -e "${GREEN} 7.${NC} AdGuardHome DNS management"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Security & Optimization ────────────┐${NC}"
        echo -e "${YELLOW} 8.${NC} Fail2ban brute force protection"
        echo -e "${YELLOW} 9.${NC} SSH security configuration"
        echo -e "${YELLOW}10.${NC} SSH login notifier"
        echo -e "${YELLOW}11.${NC} BBR TCP optimization"
        echo -e "${YELLOW}12.${NC} Timezone and NTP sync"
        echo -e "${YELLOW}13.${NC} Hostname modification"
        echo -e "${YELLOW}14.${NC} Log management (system & Docker)"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ System Resources & Monitoring ──────┐${NC}"
        echo -e "${PURPLE}15.${NC} Swap memory management"
        echo -e "${PURPLE}16.${NC} Server traffic reporter"
        echo -e "${PURPLE}17.${NC} VPS backup manager"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ VPS Testing Tools ──────────────────┐${NC}"
        echo -e "${PURPLE}18.${NC} YABS performance test"
        echo -e "${PURPLE}19.${NC} IP quality check"
        echo -e "${PURPLE}20.${NC} Network quality check"
        echo -e "${PURPLE}21.${NC} Streaming & AI unlock check"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Network Tools ──────────────────────┐${NC}"
        echo -e "${GREEN}22.${NC} Lightpath (Network acceleration)"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Advanced Operations ────────────────┐${NC}"
        echo -e "${RED}23.${NC} System reinstallation (DD) ${YELLOW}⚠ Destructive${NC}"
        echo -e "${CYAN}└──────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${RED} 0.${NC} Exit"
        echo ""
        read -p "Please select an action [0-23, or press Enter to exit]: " choice

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
                adguardhome_menu
                ;;
            8)
                fail2ban_menu
                ;;
            9)
                ssh_security_menu
                ;;
            10)
                ssh_login_notifier_menu
                ;;
            11)
                bbr_menu
                ;;
            12)
                timezone_ntp_menu
                ;;
            13)
                hostname_menu
                ;;
            14)
                log_management_menu
                ;;
            15)
                swap_menu
                ;;
            16)
                traffic_reporter_menu
                ;;
            17)
                backup_manager_menu
                ;;
            18)
                yabs_test_menu
                ;;
            19)
                ip_quality_menu
                ;;
            20)
                network_quality_menu
                ;;
            21)
                unlock_check_menu
                ;;
            22)
                lightpath_menu
                ;;
            23)
                dd_system_menu
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
