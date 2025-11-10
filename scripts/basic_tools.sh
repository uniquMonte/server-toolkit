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

    # If nothing to install, still check system packages
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        log_info "All command-line tools are already installed"
        log_info "Checking system packages..."
        echo ""
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

                # Install/upgrade packages with proper detection
                for pkg in "${all_packages[@]}"; do
                    # Check if package is already installed
                    if dpkg -l | grep -q "^ii  $pkg "; then
                        # Package is installed, try to upgrade
                        local before_version=$(dpkg -l | grep "^ii  $pkg " | awk '{print $3}')
                        apt-get install -y "$pkg" > /dev/null 2>&1
                        local after_version=$(dpkg -l | grep "^ii  $pkg " | awk '{print $3}')

                        if [ "$before_version" != "$after_version" ]; then
                            upgraded+=("$pkg")
                        fi
                        # If versions are same, it's already latest (don't add to any list)
                    else
                        # Package not installed, install it
                        if apt-get install -y "$pkg" > /dev/null 2>&1; then
                            newly_installed+=("$pkg")
                        fi
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
                        # Package is installed, check for updates
                        local update_info=$($PKG_MANAGER check-update "$pkg" 2>&1)
                        if echo "$update_info" | grep -q "$pkg"; then
                            # Update available, upgrade it
                            $PKG_MANAGER upgrade -y "$pkg" > /dev/null 2>&1
                            upgraded+=("$pkg")
                        fi
                        # If no update, it's already latest (don't add to any list)
                    else
                        # Package not installed, install it
                        if $PKG_MANAGER install -y "$pkg" > /dev/null 2>&1; then
                            newly_installed+=("$pkg")
                        fi
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
