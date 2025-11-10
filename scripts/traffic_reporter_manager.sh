#!/bin/bash

#######################################
# Server Traffic Reporter Management
# Based on: https://github.com/uniquMonte/server-traffic-reporter
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

# Check if traffic reporter is installed
check_installed() {
    # Check for common installation locations
    if [ -f "/usr/local/bin/traffic-reporter" ] || \
       [ -f "/opt/traffic-reporter/traffic-reporter.sh" ] || \
       [ -d "/opt/server-traffic-reporter" ] || \
       [ -f "/root/server-traffic-reporter/traffic_reporter.sh" ]; then
        return 0
    else
        return 1
    fi
}

# Get installation path
get_install_path() {
    if [ -f "/usr/local/bin/traffic-reporter" ]; then
        echo "/usr/local/bin/traffic-reporter"
    elif [ -f "/opt/traffic-reporter/traffic-reporter.sh" ]; then
        echo "/opt/traffic-reporter/traffic-reporter.sh"
    elif [ -d "/opt/server-traffic-reporter" ]; then
        echo "/opt/server-traffic-reporter"
    elif [ -f "/root/server-traffic-reporter/traffic_reporter.sh" ]; then
        echo "/root/server-traffic-reporter/traffic_reporter.sh"
    else
        echo ""
    fi
}

# Check if cron job is configured
check_cron_configured() {
    if crontab -l 2>/dev/null | grep -q "traffic.*reporter\|bandwidth.*monitor"; then
        return 0
    else
        return 1
    fi
}

# Get network interface statistics
get_network_stats() {
    echo ""
    echo -e "${GREEN}Current Network Interfaces:${NC}"

    # Get all active network interfaces
    local interfaces=$(ip -br link | awk '$2 == "UP" {print $1}')

    if [ -z "$interfaces" ]; then
        echo -e "  ${YELLOW}No active interfaces found${NC}"
        return
    fi

    for iface in $interfaces; do
        # Skip loopback
        if [ "$iface" = "lo" ]; then
            continue
        fi

        local rx_bytes=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)

        # Convert to human-readable format
        local rx_gb=$(echo "scale=2; $rx_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")
        local tx_gb=$(echo "scale=2; $tx_bytes / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "0")

        echo -e "  ${CYAN}$iface${NC}"
        echo -e "    RX (Received): ${GREEN}${rx_gb} GB${NC}"
        echo -e "    TX (Sent):     ${GREEN}${tx_gb} GB${NC}"
    done
}

# Show current traffic reporter status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Server Traffic Reporter Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_installed; then
        local install_path=$(get_install_path)
        echo -e "${GREEN}Installation Status:${NC}  ${GREEN}Installed ✓${NC}"
        echo -e "Installation Path:    ${CYAN}$install_path${NC}"

        # Check if cron is configured
        if check_cron_configured; then
            echo -e "${GREEN}Cron Job Status:${NC}      ${GREEN}Configured ✓${NC}"
            echo ""
            echo -e "${GREEN}Active Cron Jobs:${NC}"
            crontab -l 2>/dev/null | grep -i "traffic\|bandwidth" | while read -r line; do
                echo -e "  ${CYAN}$line${NC}"
            done
        else
            echo -e "${YELLOW}Cron Job Status:${NC}      ${YELLOW}Not configured${NC}"
            echo ""
            log_info "Automatic reporting is not scheduled"
        fi

        # Show network statistics
        get_network_stats

    else
        echo -e "${YELLOW}Installation Status:${NC}  ${YELLOW}Not installed${NC}"
        echo ""
        log_info "Server Traffic Reporter monitors daily bandwidth usage"
        log_info "It can send traffic reports via email or other notification methods"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Install traffic reporter
install_traffic_reporter() {
    echo ""
    log_info "Installing Server Traffic Reporter..."
    echo ""
    log_info "Download URL: https://raw.githubusercontent.com/uniquMonte/server-traffic-reporter/main/install.sh"
    echo ""

    if check_installed; then
        log_warning "Traffic Reporter appears to be already installed"
        local install_path=$(get_install_path)
        echo -e "Current installation: ${CYAN}$install_path${NC}"
        echo ""
        read -p "Do you want to reinstall? [y/N]: " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            return 0
        fi
    fi

    # Download and execute the installation script
    if command -v curl &> /dev/null; then
        curl -Ls https://raw.githubusercontent.com/uniquMonte/server-traffic-reporter/main/install.sh | sudo bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/server-traffic-reporter/main/install.sh | sudo bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi

    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "Traffic Reporter installation completed"
        echo ""
        log_info "You may need to configure notification settings"
    else
        log_error "Installation failed with exit code: $exit_code"
        return 1
    fi

    return $exit_code
}

# Configure traffic reporter
configure_traffic_reporter() {
    if ! check_installed; then
        log_error "Traffic Reporter is not installed"
        echo ""
        read -p "Do you want to install it now? [Y/n]: " install
        if [[ ! $install =~ ^[Nn]$ ]]; then
            install_traffic_reporter
        fi
        return
    fi

    echo ""
    log_info "Opening Traffic Reporter configuration..."

    local install_path=$(get_install_path)

    # Try to find setup script
    if [ -f "/opt/server-traffic-reporter/setup.sh" ]; then
        bash /opt/server-traffic-reporter/setup.sh
    elif [ -f "/root/server-traffic-reporter/setup.sh" ]; then
        bash /root/server-traffic-reporter/setup.sh
    else
        log_warning "Setup script not found"
        log_info "Installation path: $install_path"
        log_info "Please check the documentation for configuration instructions"
    fi
}

# Uninstall traffic reporter
uninstall_traffic_reporter() {
    if ! check_installed; then
        log_warning "Traffic Reporter is not installed"
        return 0
    fi

    echo ""
    log_warning "This will remove the Traffic Reporter from your system"
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    echo ""
    log_info "Removing Traffic Reporter..."

    # Remove cron jobs
    if check_cron_configured; then
        log_info "Removing cron jobs..."
        crontab -l 2>/dev/null | grep -v "traffic.*reporter\|bandwidth.*monitor" | crontab -
    fi

    # Remove installation directories
    local removed=0
    for path in "/usr/local/bin/traffic-reporter" \
                "/opt/traffic-reporter" \
                "/opt/server-traffic-reporter" \
                "/root/server-traffic-reporter"; do
        if [ -e "$path" ]; then
            rm -rf "$path"
            log_info "Removed: $path"
            removed=1
        fi
    done

    if [ $removed -eq 1 ]; then
        log_success "Traffic Reporter uninstalled successfully"
    else
        log_warning "No installation files found to remove"
    fi
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
        install)
            install_traffic_reporter
            ;;
        configure|setup|config)
            configure_traffic_reporter
            ;;
        uninstall|remove)
            uninstall_traffic_reporter
            ;;
        menu)
            show_status
            echo ""

            if check_installed; then
                echo -e "${GREEN}Available actions:${NC}"
                echo -e "  ${CYAN}1.${NC} Configure notification settings"
                echo -e "  ${CYAN}2.${NC} View detailed statistics"
                echo -e "  ${CYAN}3.${NC} Uninstall Traffic Reporter"
                echo -e "  ${CYAN}0.${NC} Exit"
                echo ""
                read -p "Select action [0-3]: " action

                case $action in
                    1)
                        configure_traffic_reporter
                        ;;
                    2)
                        get_network_stats
                        ;;
                    3)
                        uninstall_traffic_reporter
                        ;;
                    0)
                        log_info "Exiting"
                        ;;
                    *)
                        log_error "Invalid selection"
                        ;;
                esac
            else
                echo ""
                read -p "Traffic Reporter is not installed. Install now? [Y/n]: " install
                if [[ ! $install =~ ^[Nn]$ ]]; then
                    install_traffic_reporter
                fi
            fi
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|install|configure|uninstall|menu}"
            exit 1
            ;;
    esac
}

main "$@"
