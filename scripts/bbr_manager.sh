#!/bin/bash

#######################################
# BBR (TCP Congestion Control) Manager
# Enables Google BBR for improved network performance
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

# Check if BBR is available
check_bbr_availability() {
    local kernel_version=$(uname -r | cut -d'.' -f1,2)
    local major=$(echo $kernel_version | cut -d'.' -f1)
    local minor=$(echo $kernel_version | cut -d'.' -f2)

    # BBR requires kernel 4.9 or higher
    if [ "$major" -lt 4 ] || ([ "$major" -eq 4 ] && [ "$minor" -lt 9 ]); then
        return 1
    fi
    return 0
}

# Check current BBR status
check_bbr_status() {
    local current_congestion=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    local available_congestion=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')

    echo "$current_congestion|$available_congestion"
}

# Enable BBR
enable_bbr() {
    log_info "Starting BBR enablement..."
    echo ""

    # Check kernel version
    local kernel_version=$(uname -r)
    log_info "Current kernel version: $kernel_version"

    if ! check_bbr_availability; then
        log_error "BBR requires Linux kernel 4.9 or higher"
        log_error "Your kernel version is: $kernel_version"
        log_info "Please upgrade your kernel first"
        return 1
    fi

    log_success "Kernel version is compatible with BBR"
    echo ""

    # Check current status
    local status=$(check_bbr_status)
    local current=$(echo $status | cut -d'|' -f1)
    local available=$(echo $status | cut -d'|' -f2)

    log_info "Current TCP congestion control: $current"
    log_info "Available congestion controls: $available"
    echo ""

    # Check if BBR is already enabled
    if [ "$current" = "bbr" ]; then
        log_success "BBR is already enabled!"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Current Configuration:${NC}"
        echo -e "  TCP Congestion Control: ${GREEN}bbr${NC}"
        echo -e "  TCP Queue Discipline  : $(tc qdisc show 2>/dev/null | grep -o 'fq\|pfifo_fast' | head -n1)"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    fi

    # Enable BBR
    log_info "Enabling BBR TCP congestion control..."

    # Create sysctl configuration file
    local sysctl_conf="/etc/sysctl.d/99-bbr.conf"

    cat > "$sysctl_conf" <<EOF
# Google BBR TCP Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Additional optimizations for BBR
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
EOF

    log_success "BBR configuration file created: $sysctl_conf"

    # Apply sysctl settings
    log_info "Applying sysctl settings..."
    if sysctl -p "$sysctl_conf" > /dev/null 2>&1; then
        log_success "Sysctl settings applied successfully"
    else
        log_warning "Failed to apply some settings, trying system-wide reload..."
        sysctl --system > /dev/null 2>&1
    fi

    echo ""

    # Verify BBR is enabled
    local new_status=$(check_bbr_status)
    local new_current=$(echo $new_status | cut -d'|' -f1)

    if [ "$new_current" = "bbr" ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ BBR Successfully Enabled!${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Configuration:${NC}"
        echo -e "  TCP Congestion Control: ${GREEN}bbr${NC}"
        echo -e "  Queue Discipline      : ${GREEN}fq${NC}"
        echo -e "  Configuration File    : ${CYAN}$sysctl_conf${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        log_success "BBR is now active and will persist across reboots"
    else
        log_error "Failed to enable BBR"
        log_info "Current congestion control: $new_current"
        log_warning "You may need to reboot the system for changes to take effect"
        return 1
    fi
}

# Disable BBR
disable_bbr() {
    log_info "Disabling BBR..."
    echo ""

    # Check if BBR is enabled
    local status=$(check_bbr_status)
    local current=$(echo $status | cut -d'|' -f1)

    if [ "$current" != "bbr" ]; then
        log_info "BBR is not currently enabled"
        log_info "Current congestion control: $current"
        return 0
    fi

    # Remove BBR configuration file
    local sysctl_conf="/etc/sysctl.d/99-bbr.conf"
    if [ -f "$sysctl_conf" ]; then
        rm -f "$sysctl_conf"
        log_success "Removed BBR configuration file"
    fi

    # Reset to default (usually cubic)
    sysctl -w net.ipv4.tcp_congestion_control=cubic > /dev/null 2>&1
    sysctl -w net.core.default_qdisc=pfifo_fast > /dev/null 2>&1

    log_success "BBR has been disabled"
    log_info "Reverted to default congestion control: cubic"
}

# Show BBR status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}BBR Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Kernel version
    local kernel_version=$(uname -r)
    echo -e "Kernel Version: ${CYAN}$kernel_version${NC}"

    # Check if kernel supports BBR
    if check_bbr_availability; then
        echo -e "BBR Support   : ${GREEN}✓ Available${NC} (kernel 4.9+)"
    else
        echo -e "BBR Support   : ${RED}✗ Not Available${NC} (requires kernel 4.9+)"
    fi

    # Current status
    local status=$(check_bbr_status)
    local current=$(echo $status | cut -d'|' -f1)
    local available=$(echo $status | cut -d'|' -f2)

    # Get current qdisc
    local current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")

    echo ""
    echo -e "Current Congestion Control: ${GREEN}$current${NC}"
    echo -e "Available Controls        : $available"
    echo -e "Current Queue Discipline  : ${CYAN}$current_qdisc${NC}"

    if [ "$current" = "bbr" ]; then
        echo ""
        if [ "$current_qdisc" = "fq" ]; then
            echo -e "${GREEN}Status: BBR is ENABLED ✓ (with optimal qdisc: fq)${NC}"
        else
            echo -e "${YELLOW}Status: BBR is ENABLED but qdisc is not optimal${NC}"
            echo -e "${YELLOW}Recommended: net.core.default_qdisc = fq${NC}"
        fi
    else
        echo ""
        echo -e "${YELLOW}Status: BBR is NOT enabled${NC}"
    fi

    # Check configuration file
    local sysctl_conf="/etc/sysctl.d/99-bbr.conf"
    if [ -f "$sysctl_conf" ]; then
        echo ""
        echo -e "Configuration File: ${CYAN}$sysctl_conf${NC} (exists)"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "${1:-status}" in
        enable)
            enable_bbr
            ;;
        disable)
            disable_bbr
            ;;
        status)
            show_status
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {enable|disable|status}"
            exit 1
            ;;
    esac
}

main "$@"
