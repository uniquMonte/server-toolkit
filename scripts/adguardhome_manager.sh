#!/bin/bash

#######################################
# AdGuardHome Management Script
# Supports installation, configuration, and management of AdGuardHome DNS server
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

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
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Check if AdGuardHome is installed
check_adguardhome_installed() {
    if systemctl list-unit-files | grep -q "AdGuardHome.service"; then
        return 0
    else
        return 1
    fi
}

# Check if AdGuardHome is running
check_adguardhome_running() {
    if systemctl is-active --quiet AdGuardHome; then
        return 0
    else
        return 1
    fi
}

# Get AdGuardHome version
get_adguardhome_version() {
    if check_adguardhome_installed; then
        if [ -f /opt/AdGuardHome/AdGuardHome ]; then
            /opt/AdGuardHome/AdGuardHome --version 2>/dev/null | head -1 || echo "Unknown"
        else
            echo "Unknown"
        fi
    else
        echo "Not installed"
    fi
}

# Install AdGuardHome
install_adguardhome() {
    log_step "Installing AdGuardHome..."

    if check_adguardhome_installed; then
        log_warning "AdGuardHome is already installed"
        echo ""
        log_info "Current version: $(get_adguardhome_version)"
        if check_adguardhome_running; then
            log_success "AdGuardHome is running"
        else
            log_warning "AdGuardHome is installed but not running"
        fi
        return 0
    fi

    # Download and run official installation script
    log_info "Downloading AdGuardHome installation script..."
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

    if [ $? -eq 0 ]; then
        log_success "AdGuardHome installed successfully"

        # Enable and start service
        systemctl enable AdGuardHome
        systemctl start AdGuardHome

        if check_adguardhome_running; then
            log_success "AdGuardHome service is running"
            echo ""
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            log_info "AdGuardHome Web Interface Setup:"
            log_info "  URL: http://$(curl -s -4 https://api.ipify.org):3000"
            log_info "  Default DNS Port: 53"
            log_info "  Admin Panel Port: 80 (after initial setup)"
            log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            log_warning "Please complete the initial setup via web interface"
        else
            log_error "AdGuardHome service failed to start"
            return 1
        fi
    else
        log_error "AdGuardHome installation failed"
        return 1
    fi
}

# Uninstall AdGuardHome
uninstall_adguardhome() {
    log_step "Uninstalling AdGuardHome..."

    if ! check_adguardhome_installed; then
        log_warning "AdGuardHome is not installed"
        return 0
    fi

    echo ""
    log_warning "This will remove AdGuardHome and all its configurations"
    read -p "Are you sure you want to continue? [y/N] (press Enter to cancel): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    # Stop service
    log_info "Stopping AdGuardHome service..."
    systemctl stop AdGuardHome 2>/dev/null || true
    systemctl disable AdGuardHome 2>/dev/null || true

    # Remove service file
    if [ -f /etc/systemd/system/AdGuardHome.service ]; then
        rm -f /etc/systemd/system/AdGuardHome.service
    fi

    # Remove installation directory
    if [ -d /opt/AdGuardHome ]; then
        log_info "Removing AdGuardHome files..."
        rm -rf /opt/AdGuardHome
    fi

    # Reload systemd
    systemctl daemon-reload

    log_success "AdGuardHome has been uninstalled"
}

# Start AdGuardHome service
start_adguardhome() {
    log_step "Starting AdGuardHome service..."

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    systemctl start AdGuardHome

    if check_adguardhome_running; then
        log_success "AdGuardHome service started successfully"
        systemctl status AdGuardHome --no-pager
    else
        log_error "Failed to start AdGuardHome service"
        return 1
    fi
}

# Stop AdGuardHome service
stop_adguardhome() {
    log_step "Stopping AdGuardHome service..."

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    systemctl stop AdGuardHome

    if ! check_adguardhome_running; then
        log_success "AdGuardHome service stopped successfully"
    else
        log_error "Failed to stop AdGuardHome service"
        return 1
    fi
}

# Restart AdGuardHome service
restart_adguardhome() {
    log_step "Restarting AdGuardHome service..."

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    systemctl restart AdGuardHome

    if check_adguardhome_running; then
        log_success "AdGuardHome service restarted successfully"
        systemctl status AdGuardHome --no-pager
    else
        log_error "Failed to restart AdGuardHome service"
        return 1
    fi
}

# View service status
view_status() {
    log_step "Checking AdGuardHome status..."
    echo ""

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Version:${NC} $(get_adguardhome_version)"
    echo ""

    systemctl status AdGuardHome --no-pager

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if check_adguardhome_running; then
        echo -e "${CYAN}Web Interface:${NC} http://$(curl -s -4 https://api.ipify.org):80"
        echo -e "${CYAN}DNS Server:${NC} $(curl -s -4 https://api.ipify.org):53"
    fi
    echo -e "${CYAN}Config File:${NC} /opt/AdGuardHome/AdGuardHome.yaml"
    echo -e "${CYAN}Data Directory:${NC} /opt/AdGuardHome/data"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# View logs
view_logs() {
    log_step "Viewing AdGuardHome logs..."
    echo ""

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    log_info "Showing last 50 lines (Press Ctrl+C to exit)"
    echo ""
    journalctl -u AdGuardHome -n 50 --no-pager
}

# Update AdGuardHome
update_adguardhome() {
    log_step "Updating AdGuardHome..."

    if ! check_adguardhome_installed; then
        log_error "AdGuardHome is not installed"
        return 1
    fi

    local current_version=$(get_adguardhome_version)
    log_info "Current version: $current_version"

    # Get latest version from GitHub API
    log_info "Checking for latest version..."
    local latest_version=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_version" ]; then
        log_warning "Could not fetch latest version information"
        log_info "Proceeding with update anyway..."
    else
        log_info "Latest version: AdGuard Home, version $latest_version"
        echo ""

        # Compare versions
        if [[ "$current_version" == *"$latest_version"* ]]; then
            log_success "You are already running the latest version!"
            return 0
        fi
    fi

    echo ""
    # Download and run update script
    log_info "Downloading and installing latest version..."
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v -r

    if [ $? -eq 0 ]; then
        log_success "AdGuardHome updated successfully"
        log_info "New version: $(get_adguardhome_version)"

        # Restart service
        systemctl restart AdGuardHome

        if check_adguardhome_running; then
            log_success "AdGuardHome service restarted successfully"
        fi
    else
        log_error "AdGuardHome update failed"
        return 1
    fi
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}           AdGuardHome DNS Management              ${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Show status
        if check_adguardhome_installed; then
            if check_adguardhome_running; then
                echo -e "${GREEN}Status: AdGuardHome is installed and running${NC}"
                echo -e "${CYAN}Version:${NC} $(get_adguardhome_version)"
            else
                echo -e "${YELLOW}Status: AdGuardHome is installed but not running${NC}"
                echo -e "${CYAN}Version:${NC} $(get_adguardhome_version)"
            fi
        else
            echo -e "${YELLOW}Status: AdGuardHome is not installed${NC}"
        fi
        echo ""

        echo -e "${CYAN}┌─ Installation & Updates ─────────────────────────┐${NC}"
        echo -e "${GREEN} 1.${NC} Install AdGuardHome"
        echo -e "${GREEN} 2.${NC} Update AdGuardHome"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Service Management ─────────────────────────────┐${NC}"
        echo -e "${YELLOW} 3.${NC} Start service"
        echo -e "${YELLOW} 4.${NC} Stop service"
        echo -e "${YELLOW} 5.${NC} Restart service"
        echo -e "${YELLOW} 6.${NC} View status"
        echo -e "${YELLOW} 7.${NC} View logs"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Advanced ───────────────────────────────────────┐${NC}"
        echo -e "${RED} 8.${NC} Uninstall AdGuardHome"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${YELLOW} 0.${NC} Return to Main Menu"
        echo ""

        read -p "Please select an option [0-8, or press Enter to exit]: " choice

        case $choice in
            1)
                install_adguardhome
                ;;
            2)
                update_adguardhome
                ;;
            3)
                start_adguardhome
                ;;
            4)
                stop_adguardhome
                ;;
            5)
                restart_adguardhome
                ;;
            6)
                view_status
                ;;
            7)
                view_logs
                ;;
            8)
                uninstall_adguardhome
                ;;
            0|"")
                log_info "Returning to main menu..."
                break
                ;;
            *)
                log_error "Invalid option. Please select 0-8"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main_menu
