#!/bin/bash

#######################################
# DD System Reinstallation Script
# Based on: https://github.com/bin456789/reinstall
# WARNING: This will erase ALL data on the VPS!
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get current system info
get_current_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$NAME $VERSION_ID"
    else
        echo "Unknown Linux"
    fi
}

# Show current system information
show_current_system() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Current System Information${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "OS: ${CYAN}$(get_current_system)${NC}"
    echo -e "Kernel: ${CYAN}$(uname -r)${NC}"
    echo -e "Architecture: ${CYAN}$(uname -m)${NC}"
    if command -v hostnamectl &> /dev/null; then
        echo -e "Hostname: ${CYAN}$(hostnamectl --static 2>/dev/null || hostname)${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show warning
show_warning() {
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                  ⚠️  WARNING  ⚠️                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This operation will:${NC}"
    echo -e "  ${RED}✗${NC} Erase ALL data on this VPS"
    echo -e "  ${RED}✗${NC} Remove all files, databases, configurations"
    echo -e "  ${RED}✗${NC} Terminate all running services"
    echo -e "  ${RED}✗${NC} Reinstall the operating system from scratch"
    echo ""
    echo -e "${YELLOW}You will LOSE:${NC}"
    echo -e "  ${RED}•${NC} All user data"
    echo -e "  ${RED}•${NC} All installed applications"
    echo -e "  ${RED}•${NC} All configurations"
    echo -e "  ${RED}•${NC} SSH keys (you may lose access!)"
    echo ""
    echo -e "${GREEN}Before proceeding:${NC}"
    echo -e "  ${GREEN}✓${NC} Backup all important data"
    echo -e "  ${GREEN}✓${NC} Have your VPS console access ready"
    echo -e "  ${GREEN}✓${NC} Know your root password or have SSH keys backed up"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Download the reinstall script
download_script() {
    local source=$1
    local script_url=""

    if [ "$source" = "domestic" ]; then
        script_url="https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.sh"
        log_info "Using domestic server (China): cnb.cool"
    else
        script_url="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
        log_info "Using international server: GitHub"
    fi

    echo ""
    log_info "Downloading reinstall script..."

    if curl -fsSL -o /tmp/reinstall.sh "$script_url" 2>/dev/null; then
        log_success "Downloaded successfully using curl"
        chmod +x /tmp/reinstall.sh
        return 0
    elif wget -O /tmp/reinstall.sh "$script_url" 2>/dev/null; then
        log_success "Downloaded successfully using wget"
        chmod +x /tmp/reinstall.sh
        return 0
    else
        log_error "Failed to download script"
        return 1
    fi
}

# Show available systems
show_available_systems() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Available Operating Systems               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}Enterprise Linux:${NC}"
    echo -e "  ${YELLOW}1.${NC}  Anolis OS      - 7, 8, 23"
    echo -e "  ${YELLOW}2.${NC}  Rocky Linux    - 8, 9, 10"
    echo -e "  ${YELLOW}3.${NC}  Oracle Linux   - 8, 9, 10"
    echo -e "  ${YELLOW}4.${NC}  AlmaLinux      - 8, 9, 10"
    echo -e "  ${YELLOW}5.${NC}  OpenCloudOS    - 8, 9, 23"
    echo -e "  ${YELLOW}6.${NC}  CentOS Stream  - 9, 10"
    echo -e "  ${YELLOW}7.${NC}  openEuler      - 20.03, 22.03, 24.03, 25.09"
    echo ""

    echo -e "${GREEN}Popular Distributions:${NC}"
    echo -e "  ${YELLOW}8.${NC}  Debian         - 9, 10, 11, 12, 13"
    echo -e "  ${YELLOW}9.${NC}  Ubuntu         - 16.04, 18.04, 20.04, 22.04, 24.04, 25.10"
    echo -e "  ${YELLOW}10.${NC} Fedora         - 42, 43"
    echo ""

    echo -e "${GREEN}Other Distributions:${NC}"
    echo -e "  ${YELLOW}11.${NC} Alpine Linux   - 3.19, 3.20, 3.21, 3.22"
    echo -e "  ${YELLOW}12.${NC} openSUSE       - 15.6, 16.0, tumbleweed"
    echo -e "  ${YELLOW}13.${NC} NixOS          - 25.05"
    echo -e "  ${YELLOW}14.${NC} Arch Linux     - (rolling release)"
    echo -e "  ${YELLOW}15.${NC} Gentoo         - (rolling release)"
    echo -e "  ${YELLOW}16.${NC} Kali Linux     - (latest)"
    echo -e "  ${YELLOW}17.${NC} AOSC OS        - (latest)"
    echo -e "  ${YELLOW}18.${NC} Flipped NOS    - (latest)"
    echo ""

    echo -e "  ${RED}0.${NC}  Cancel and return"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get system choice
select_system() {
    local os_name=""
    local os_version=""
    local extra_params=""

    show_available_systems

    while true; do
        read -p "Select operating system [0-18]: " choice

        case $choice in
            1)
                os_name="anolis"
                read -p "Select version [7/8/23]: " os_version
                if [[ ! "$os_version" =~ ^(7|8|23)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            2)
                os_name="rocky"
                read -p "Select version [8/9/10]: " os_version
                if [[ ! "$os_version" =~ ^(8|9|10)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            3)
                os_name="oracle"
                read -p "Select version [8/9/10]: " os_version
                if [[ ! "$os_version" =~ ^(8|9|10)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            4)
                os_name="almalinux"
                read -p "Select version [8/9/10]: " os_version
                if [[ ! "$os_version" =~ ^(8|9|10)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            5)
                os_name="opencloudos"
                read -p "Select version [8/9/23]: " os_version
                if [[ ! "$os_version" =~ ^(8|9|23)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            6)
                os_name="centos"
                read -p "Select version [9/10]: " os_version
                if [[ ! "$os_version" =~ ^(9|10)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            7)
                os_name="openeuler"
                read -p "Select version [20.03/22.03/24.03/25.09]: " os_version
                if [[ ! "$os_version" =~ ^(20\.03|22\.03|24\.03|25\.09)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            8)
                os_name="debian"
                read -p "Select version [9/10/11/12/13]: " os_version
                if [[ ! "$os_version" =~ ^(9|10|11|12|13)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            9)
                os_name="ubuntu"
                read -p "Select version [16.04/18.04/20.04/22.04/24.04/25.10]: " os_version
                if [[ ! "$os_version" =~ ^(16\.04|18\.04|20\.04|22\.04|24\.04|25\.10)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                read -p "Use minimal installation? [y/N]: " minimal
                if [[ $minimal =~ ^[Yy]$ ]]; then
                    extra_params="--minimal"
                fi
                ;;
            10)
                os_name="fedora"
                read -p "Select version [42/43]: " os_version
                if [[ ! "$os_version" =~ ^(42|43)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            11)
                os_name="alpine"
                read -p "Select version [3.19/3.20/3.21/3.22]: " os_version
                if [[ ! "$os_version" =~ ^(3\.19|3\.20|3\.21|3\.22)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            12)
                os_name="opensuse"
                read -p "Select version [15.6/16.0/tumbleweed]: " os_version
                if [[ ! "$os_version" =~ ^(15\.6|16\.0|tumbleweed)$ ]]; then
                    log_error "Invalid version"
                    continue
                fi
                ;;
            13)
                os_name="nixos"
                os_version="25.05"
                ;;
            14)
                os_name="arch"
                os_version=""
                ;;
            15)
                os_name="gentoo"
                os_version=""
                ;;
            16)
                os_name="kali"
                os_version=""
                ;;
            17)
                os_name="aosc"
                os_version=""
                ;;
            18)
                os_name="fnos"
                os_version=""
                ;;
            0)
                return 1
                ;;
            *)
                log_error "Invalid selection"
                continue
                ;;
        esac

        break
    done

    # Build command
    if [ -z "$os_version" ]; then
        DD_COMMAND="bash /tmp/reinstall.sh $os_name $extra_params"
    else
        DD_COMMAND="bash /tmp/reinstall.sh $os_name-$os_version $extra_params"
    fi

    return 0
}

# Show selected configuration
show_configuration() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            Installation Configuration                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Current System:${NC} $(get_current_system)"
    echo -e "${YELLOW}Target System:${NC}  $1"
    echo -e "${YELLOW}Command:${NC}       $DD_COMMAND"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main DD system function
dd_system_main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        return 1
    fi

    # Show current system
    show_current_system

    # Show warning
    show_warning

    # First confirmation
    echo ""
    read -p "Do you understand the risks and want to continue? [yes/NO]: " confirm1
    if [ "$confirm1" != "yes" ]; then
        log_info "Operation cancelled by user"
        return 0
    fi

    # Select download source
    echo ""
    log_info "Select download source"
    echo -e "  ${CYAN}1.${NC} International (GitHub) - ${GREEN}Recommended for servers outside China${NC}"
    echo -e "  ${CYAN}2.${NC} Domestic (cnb.cool) - ${GREEN}Recommended for servers in China${NC}"
    echo ""
    read -p "Select source [1-2, default: 1]: " source_choice

    local download_source="international"
    if [ "$source_choice" = "2" ]; then
        download_source="domestic"
    fi

    # Download script
    if ! download_script "$download_source"; then
        log_error "Failed to download reinstall script"
        return 1
    fi

    # Select system
    if ! select_system; then
        log_info "Operation cancelled by user"
        return 0
    fi

    # Show configuration
    local target_desc="${os_name}"
    [ -n "$os_version" ] && target_desc="${os_name} ${os_version}"
    show_configuration "$target_desc"

    # Second confirmation
    echo ""
    echo -e "${RED}⚠️  FINAL WARNING ⚠️${NC}"
    echo -e "${YELLOW}This is your last chance to cancel!${NC}"
    echo ""
    echo -e "Type ${RED}'REINSTALL'${NC} (in capital letters) to confirm:"
    read -p "> " confirm2

    if [ "$confirm2" != "REINSTALL" ]; then
        log_info "Operation cancelled - confirmation text does not match"
        return 0
    fi

    # Execute
    echo ""
    log_warning "Starting system reinstallation..."
    log_info "Command: $DD_COMMAND"
    echo ""
    log_info "The system will reboot shortly..."
    log_info "Please monitor the installation via VPS console"
    echo ""

    sleep 3

    # Execute the DD command
    eval "$DD_COMMAND"
}

# Show status/info only
show_info() {
    show_current_system
    echo ""
    log_info "This feature allows you to reinstall your VPS operating system"
    log_info "Based on: https://github.com/bin456789/reinstall"
    echo ""
    log_warning "This is a destructive operation - use with caution!"
}

# Main entry point
main() {
    case "${1:-menu}" in
        menu|reinstall)
            dd_system_main
            ;;
        info|status)
            show_info
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {menu|reinstall|info|status}"
            exit 1
            ;;
    esac
}

main "$@"
