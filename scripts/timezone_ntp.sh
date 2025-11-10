#!/bin/bash

#######################################
# Timezone and NTP Time Sync Manager
# Sets timezone to Asia/Shanghai and enables NTP synchronization
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

# Get current timezone
get_current_timezone() {
    if command -v timedatectl &> /dev/null; then
        timedatectl show --property=Timezone --value 2>/dev/null
    else
        cat /etc/timezone 2>/dev/null || date +%Z
    fi
}

# Get current time
get_current_time() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

# Check NTP status
check_ntp_status() {
    if command -v timedatectl &> /dev/null; then
        local ntp_status=$(timedatectl show --property=NTP --value 2>/dev/null)
        if [ "$ntp_status" = "yes" ]; then
            echo "yes"
            return
        fi
    fi

    # Check if any NTP service is running
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null || \
       systemctl is-active --quiet chronyd 2>/dev/null || \
       systemctl is-active --quiet chrony 2>/dev/null || \
       systemctl is-active --quiet ntpd 2>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Show current status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Timezone and NTP Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local current_tz=$(get_current_timezone)
    local current_time=$(get_current_time)
    local ntp_status=$(check_ntp_status)

    echo -e "Current Timezone : ${CYAN}$current_tz${NC}"
    echo -e "Current Time     : ${CYAN}$current_time${NC}"

    if [ "$ntp_status" = "yes" ]; then
        echo -e "NTP Sync         : ${GREEN}✓ Enabled${NC}"
    else
        echo -e "NTP Sync         : ${YELLOW}✗ Disabled${NC}"
    fi

    # Show time sync service status
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        echo -e "Time Sync Service: ${GREEN}✓ Active (systemd-timesyncd)${NC}"
    elif systemctl is-active --quiet chronyd 2>/dev/null; then
        echo -e "Time Sync Service: ${GREEN}✓ Active (chronyd)${NC}"
    elif systemctl is-active --quiet ntpd 2>/dev/null; then
        echo -e "Time Sync Service: ${GREEN}✓ Active (ntpd)${NC}"
    else
        echo -e "Time Sync Service: ${YELLOW}✗ Not detected${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Set timezone to Asia/Shanghai
set_timezone() {
    local target_timezone="Asia/Shanghai"
    local current_tz=$(get_current_timezone)

    log_info "Setting timezone to $target_timezone..."
    echo ""

    # Check if already set
    if [ "$current_tz" = "$target_timezone" ]; then
        log_success "Timezone is already set to $target_timezone"
        echo -e "Current time: ${CYAN}$(get_current_time)${NC}"
        return 0
    fi

    log_info "Current timezone: $current_tz"

    # Set timezone using timedatectl if available
    if command -v timedatectl &> /dev/null; then
        if timedatectl set-timezone "$target_timezone" 2>/dev/null; then
            log_success "Timezone set to $target_timezone using timedatectl"
        else
            log_error "Failed to set timezone using timedatectl"
            return 1
        fi
    else
        # Fallback method
        if [ -f "/usr/share/zoneinfo/$target_timezone" ]; then
            ln -sf "/usr/share/zoneinfo/$target_timezone" /etc/localtime
            echo "$target_timezone" > /etc/timezone
            log_success "Timezone set to $target_timezone"
        else
            log_error "Timezone file not found: /usr/share/zoneinfo/$target_timezone"
            return 1
        fi
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Timezone Configuration:${NC}"
    echo -e "  Old Timezone: ${YELLOW}$current_tz${NC}"
    echo -e "  New Timezone: ${GREEN}$target_timezone${NC}"
    echo -e "  Current Time: ${CYAN}$(get_current_time)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Enable NTP time synchronization
enable_ntp() {
    log_info "Enabling NTP time synchronization..."
    echo ""

    detect_os

    # Check if NTP is already enabled
    local ntp_status=$(check_ntp_status)
    if [ "$ntp_status" = "yes" ]; then
        log_success "NTP synchronization is already enabled"

        # Show sync status
        if command -v timedatectl &> /dev/null; then
            echo ""
            timedatectl timesync-status 2>/dev/null || timedatectl status
        fi
        return 0
    fi

    # Try to enable NTP using timedatectl
    if command -v timedatectl &> /dev/null; then
        log_info "Enabling NTP using timedatectl..."
        if timedatectl set-ntp true 2>/dev/null; then
            log_success "NTP enabled successfully"
        else
            log_warning "Failed to enable NTP using timedatectl, trying alternative methods..."
        fi
    fi

    # Install and enable time sync service based on OS
    case $OS in
        ubuntu|debian)
            # Check if systemd-timesyncd is available
            if systemctl list-unit-files | grep -q systemd-timesyncd; then
                log_info "Using systemd-timesyncd..."
                systemctl enable systemd-timesyncd > /dev/null 2>&1
                systemctl start systemd-timesyncd > /dev/null 2>&1

                if systemctl is-active --quiet systemd-timesyncd; then
                    log_success "systemd-timesyncd is now active"
                fi
            else
                log_info "Installing chrony for time synchronization..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y > /dev/null 2>&1
                apt-get install -y chrony > /dev/null 2>&1

                # Configure chrony to use Chinese NTP servers
                if [ -f /etc/chrony/chrony.conf ]; then
                    # Backup original config
                    cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak

                    # Add Chinese NTP servers at the beginning
                    sed -i '1i# Chinese NTP Servers\nserver ntp.aliyun.com iburst\nserver ntp.tencent.com iburst\nserver ntp1.aliyun.com iburst' /etc/chrony/chrony.conf
                fi

                systemctl enable chrony > /dev/null 2>&1
                systemctl restart chrony > /dev/null 2>&1

                if systemctl is-active --quiet chrony; then
                    log_success "chrony is now active"
                fi
            fi
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Installing chrony for time synchronization..."

            # Check if dnf is available
            if command -v dnf &> /dev/null; then
                dnf install -y chrony > /dev/null 2>&1
            else
                yum install -y chrony > /dev/null 2>&1
            fi

            # Configure chrony to use Chinese NTP servers
            if [ -f /etc/chrony.conf ]; then
                # Backup original config
                cp /etc/chrony.conf /etc/chrony.conf.bak

                # Add Chinese NTP servers
                sed -i '1i# Chinese NTP Servers\nserver ntp.aliyun.com iburst\nserver ntp.tencent.com iburst\nserver ntp1.aliyun.com iburst' /etc/chrony.conf
            fi

            systemctl enable chronyd > /dev/null 2>&1
            systemctl restart chronyd > /dev/null 2>&1

            if systemctl is-active --quiet chronyd; then
                log_success "chronyd is now active"
            fi
            ;;

        *)
            log_warning "Unsupported OS for automatic NTP setup: $OS"
            ;;
    esac

    # Wait a moment for sync to start
    sleep 2

    # Display final status
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}NTP Synchronization Status:${NC}"

    local final_ntp_status=$(check_ntp_status)
    if [ "$final_ntp_status" = "yes" ]; then
        echo -e "  Status: ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  Status: ${YELLOW}Partially Enabled${NC}"
    fi

    # Show active service
    if systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then
        echo -e "  Service: ${GREEN}systemd-timesyncd${NC}"
    elif systemctl is-active --quiet chronyd 2>/dev/null; then
        echo -e "  Service: ${GREEN}chronyd${NC}"
        # Show chrony sources
        if command -v chronyc &> /dev/null; then
            echo ""
            echo -e "${CYAN}NTP Sources:${NC}"
            chronyc sources 2>/dev/null | tail -n +3
        fi
    elif systemctl is-active --quiet chrony 2>/dev/null; then
        echo -e "  Service: ${GREEN}chrony${NC}"
    fi

    echo -e "  Current Time: ${CYAN}$(get_current_time)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Configure both timezone and NTP
configure_all() {
    log_info "Configuring timezone and NTP synchronization..."
    echo ""

    # Set timezone
    set_timezone

    echo ""

    # Enable NTP
    enable_ntp

    echo ""
    log_success "Configuration complete!"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "${1:-status}" in
        status)
            show_status
            ;;
        timezone)
            set_timezone
            ;;
        ntp)
            enable_ntp
            ;;
        all)
            configure_all
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|timezone|ntp|all}"
            exit 1
            ;;
    esac
}

main "$@"
