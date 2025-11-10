#!/bin/bash

#######################################
# Swap Management
# Based on: https://github.com/uniquMonte/swap-setup
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

# Check if swap is configured
check_swap_status() {
    if swapon --show 2>/dev/null | grep -q '/'; then
        return 0  # Swap is active
    else
        return 1  # No swap
    fi
}

# Get current swap information
get_swap_info() {
    local swap_total=$(free -h | awk '/^Swap:/ {print $2}')
    local swap_used=$(free -h | awk '/^Swap:/ {print $3}')
    local swap_free=$(free -h | awk '/^Swap:/ {print $4}')

    echo "$swap_total|$swap_used|$swap_free"
}

# Get swappiness value
get_swappiness() {
    sysctl -n vm.swappiness 2>/dev/null || echo "60"
}

# Get cache pressure value
get_cache_pressure() {
    sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo "100"
}

# Show current swap status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Swap Memory Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_swap_status; then
        local swap_info=$(get_swap_info)
        local swap_total=$(echo "$swap_info" | cut -d'|' -f1)
        local swap_used=$(echo "$swap_info" | cut -d'|' -f2)
        local swap_free=$(echo "$swap_info" | cut -d'|' -f3)
        local swappiness=$(get_swappiness)
        local cache_pressure=$(get_cache_pressure)

        echo -e "${GREEN}Swap Status:${NC}       ${GREEN}Enabled ✓${NC}"
        echo -e "Total Swap:        ${CYAN}$swap_total${NC}"
        echo -e "Used:              ${YELLOW}$swap_used${NC}"
        echo -e "Free:              ${GREEN}$swap_free${NC}"
        echo ""
        echo -e "${GREEN}Kernel Parameters:${NC}"
        echo -e "Swappiness:        ${CYAN}$swappiness${NC} (0-100, lower = less swap usage)"
        echo -e "Cache Pressure:    ${CYAN}$cache_pressure${NC} (default: 100)"

        # Show swap files/partitions
        echo ""
        echo -e "${GREEN}Active Swap:${NC}"
        swapon --show 2>/dev/null | tail -n +2 | while read -r line; do
            echo -e "  ${CYAN}$line${NC}"
        done
    else
        echo -e "${YELLOW}Swap Status:${NC}       ${YELLOW}Not configured${NC}"
        echo ""
        log_info "Swap memory can improve system stability when RAM is limited"
        log_info "Recommended swap size: 1-2x of RAM for systems with <2GB RAM"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Launch swap-setup interactive script
launch_swap_setup() {
    echo ""
    log_info "Launching Swap Setup Tool..."
    echo ""
    log_info "Download URL: https://raw.githubusercontent.com/uniquMonte/swap-setup/main/install.sh"
    echo ""

    # Download and execute the swap-setup script
    if command -v curl &> /dev/null; then
        bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/swap-setup/main/install.sh)
    elif command -v wget &> /dev/null; then
        bash <(wget -qO- https://raw.githubusercontent.com/uniquMonte/swap-setup/main/install.sh)
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi

    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "Swap setup completed"
    else
        log_warning "Swap setup exited with code: $exit_code"
    fi

    return $exit_code
}

# Quick add swap with defaults
quick_add_swap() {
    echo ""
    log_info "Quick Swap Setup"
    echo ""

    if check_swap_status; then
        log_warning "Swap is already configured"
        show_status
        echo ""
        read -p "Do you want to modify the existing swap? [y/N]: " modify
        if [[ ! $modify =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            return 0
        fi
    fi

    # Get total RAM
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))

    echo -e "System RAM: ${CYAN}${total_ram_gb}GB${NC}"
    echo ""
    log_info "Recommended swap size:"

    if [ $total_ram_gb -lt 2 ]; then
        echo -e "  ${GREEN}2GB${NC} (2x RAM for systems with <2GB RAM)"
        local recommended="2G"
    elif [ $total_ram_gb -lt 4 ]; then
        echo -e "  ${GREEN}2GB${NC} (Equal to RAM for systems with 2-4GB RAM)"
        local recommended="2G"
    else
        echo -e "  ${GREEN}1GB${NC} (Minimal swap for systems with ≥4GB RAM)"
        local recommended="1G"
    fi

    echo ""
    log_info "Launching full swap setup tool for complete configuration..."
    sleep 2

    launch_swap_setup
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "${1:-menu}" in
        status)
            show_status
            ;;
        setup|configure)
            launch_swap_setup
            ;;
        quick)
            quick_add_swap
            ;;
        menu)
            show_status
            echo ""
            log_info "Use 'setup' to launch the full swap configuration tool"
            echo ""
            read -p "Launch swap setup now? [Y/n]: " launch
            if [[ ! $launch =~ ^[Nn]$ ]]; then
                launch_swap_setup
            fi
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|setup|quick|menu}"
            exit 1
            ;;
    esac
}

main "$@"
