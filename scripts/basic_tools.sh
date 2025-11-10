#!/bin/bash

#######################################
# Basic Tools Installation Script
# Detects installed tools and intelligently installs/upgrades
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Install basic tools with smart detection
install_basic_tools() {
    detect_os

    # Define tool lists
    local tools_to_check=("curl" "wget" "git" "vim" "nano" "htop" "unzip" "zip" "tar" "gzip" "bzip2")
    local packages_to_install=()
    local already_installed=()
    local newly_installed=()
    local upgraded=()

    log_info "Checking basic tools installation status..."
    echo ""

    # Check each tool
    for tool in "${tools_to_check[@]}"; do
        if command -v "$tool" &> /dev/null; then
            already_installed+=("$tool")
            echo -e "  ${GREEN}✓${NC} $tool - already installed"
        else
            packages_to_install+=("$tool")
            echo -e "  ${YELLOW}○${NC} $tool - will be installed"
        fi
    done

    # Add system packages that don't have commands
    case $OS in
        ubuntu|debian)
            local system_packages=("net-tools" "ca-certificates" "gnupg" "lsb-release" "software-properties-common" "apt-transport-https")
            ;;
        centos|rhel|rocky|almalinux|fedora)
            local system_packages=("net-tools" "ca-certificates" "gnupg" "yum-utils")
            ;;
    esac

    echo ""

    # If nothing to install
    if [ ${#packages_to_install[@]} -eq 0 ] && [ ${#system_packages[@]} -eq 0 ]; then
        log_success "All basic tools are already installed!"
        echo ""
        echo -e "${CYAN}Already installed:${NC} ${already_installed[*]}"
        return 0
    fi

    # Install packages
    case $OS in
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive

            log_info "Updating package lists..."
            apt-get update -y > /dev/null 2>&1

            if [ ${#packages_to_install[@]} -gt 0 ] || [ ${#system_packages[@]} -gt 0 ]; then
                log_info "Installing and upgrading packages..."

                # Combine all packages
                local all_packages=("${packages_to_install[@]}" "${system_packages[@]}")

                # Install/upgrade packages and capture output
                for pkg in "${all_packages[@]}"; do
                    if apt-get install -y "$pkg" 2>&1 | grep -q "is already the newest version"; then
                        : # Package already up to date
                    elif dpkg -l | grep -q "^ii  $pkg "; then
                        upgraded+=("$pkg")
                    else
                        newly_installed+=("$pkg")
                    fi
                done
            fi
            ;;

        centos|rhel|rocky|almalinux|fedora)
            # Check if dnf is available
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            if [ ${#packages_to_install[@]} -gt 0 ] || [ ${#system_packages[@]} -gt 0 ]; then
                log_info "Installing and upgrading packages..."

                # Combine all packages
                local all_packages=("${packages_to_install[@]}" "${system_packages[@]}")

                for pkg in "${all_packages[@]}"; do
                    if $PKG_MANAGER list installed "$pkg" &> /dev/null; then
                        # Try to upgrade
                        if $PKG_MANAGER upgrade -y "$pkg" 2>&1 | grep -q "Nothing to do"; then
                            : # Package already up to date
                        else
                            upgraded+=("$pkg")
                        fi
                    else
                        $PKG_MANAGER install -y "$pkg" &> /dev/null
                        newly_installed+=("$pkg")
                    fi
                done
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Display summary
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Installation Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ ${#already_installed[@]} -gt 0 ]; then
        echo -e "${GREEN}Already installed:${NC} ${already_installed[*]}"
    fi

    if [ ${#newly_installed[@]} -gt 0 ]; then
        echo -e "${GREEN}Newly installed:${NC} ${newly_installed[*]}"
    fi

    if [ ${#upgraded[@]} -gt 0 ]; then
        echo -e "${YELLOW}Upgraded:${NC} ${upgraded[*]}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    log_success "Basic tools installation complete!"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    install_basic_tools
}

main "$@"
