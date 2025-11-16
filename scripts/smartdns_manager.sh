#!/bin/bash

#######################################
# SmartDNS Management Script
# Supports installation, configuration, and management of SmartDNS server
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

# Check if SmartDNS is installed
check_smartdns_installed() {
    if command -v smartdns &> /dev/null || systemctl list-unit-files | grep -q "smartdns.service"; then
        return 0
    else
        return 1
    fi
}

# Check if SmartDNS is running
check_smartdns_running() {
    if systemctl is-active --quiet smartdns; then
        return 0
    else
        return 1
    fi
}

# Get SmartDNS version
get_smartdns_version() {
    if check_smartdns_installed; then
        smartdns -v 2>/dev/null | head -1 || echo "Unknown"
    else
        echo "Not installed"
    fi
}

# Check if dnsutils is installed
check_dnsutils_installed() {
    if command -v dig &> /dev/null && command -v nslookup &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install dnsutils
install_dnsutils() {
    log_step "Checking dnsutils installation..."

    if check_dnsutils_installed; then
        log_info "dnsutils is already installed"
        return 0
    fi

    log_info "Installing dnsutils (dig and nslookup tools)..."
    apt-get update -qq
    apt-get install -y dnsutils

    if check_dnsutils_installed; then
        log_success "dnsutils installed successfully"
        return 0
    else
        log_error "Failed to install dnsutils"
        return 1
    fi
}

# Check and handle DNS services (systemd-resolved or resolvconf)
check_dns_services() {
    log_step "Checking for existing DNS management services..."
    echo ""

    local need_action=false

    # Check systemd-resolved
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log_warning "systemd-resolved is currently managing DNS"
        need_action=true
    fi

    # Check resolvconf
    if systemctl is-active --quiet resolvconf 2>/dev/null || [ -f /etc/systemd/system/resolvconf.service ]; then
        log_warning "resolvconf is installed and may interfere with SmartDNS"
        need_action=true
    fi

    if [ "$need_action" = true ]; then
        echo ""
        log_warning "SmartDNS requires exclusive control of DNS resolution"
        log_info "We need to disable conflicting DNS services"
        echo ""
        read -p "Proceed with disabling conflicting services? [Y/n] (press Enter to proceed): " confirm

        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            disable_dns_services
        else
            log_error "Cannot proceed with SmartDNS installation without disabling conflicting services"
            return 1
        fi
    else
        log_success "No conflicting DNS services detected"
    fi

    return 0
}

# Disable DNS services
disable_dns_services() {
    log_step "Disabling conflicting DNS services..."

    # Disable systemd-resolved
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        log_info "Stopping and disabling systemd-resolved..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        log_success "systemd-resolved disabled"
    fi

    # Disable resolvconf
    if systemctl is-active --quiet resolvconf 2>/dev/null; then
        log_info "Stopping resolvconf service..."
        systemctl stop resolvconf.service 2>/dev/null || true
        systemctl disable resolvconf.service 2>/dev/null || true
    fi

    # Remove resolvconf package if installed
    if dpkg -l | grep -q "^ii.*resolvconf"; then
        log_info "Removing resolvconf package..."
        apt remove --purge resolvconf -y
        log_success "resolvconf removed"
    fi

    # Handle /etc/resolv.conf
    if [ -L /etc/resolv.conf ]; then
        log_info "Removing symbolic link /etc/resolv.conf..."
        rm /etc/resolv.conf
        touch /etc/resolv.conf
        chmod 644 /etc/resolv.conf
        log_success "Created new /etc/resolv.conf"
    fi

    # Add temporary DNS for installation
    log_info "Configuring temporary DNS servers..."
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

    log_success "Temporary DNS configured"
}

# Create SmartDNS configuration
# Parameters:
#   $1 - auto_overwrite: if set to "auto", will automatically overwrite existing config during installation
create_smartdns_config() {
    log_step "Creating SmartDNS configuration..."

    local config_file="/etc/smartdns/smartdns.conf"
    local auto_overwrite="$1"

    if [ -f "$config_file" ]; then
        if [ "$auto_overwrite" = "auto" ]; then
            # During installation, automatically use optimized configuration
            log_info "Detected existing default configuration"
            log_info "Replacing with optimized configuration (cache, logging, upstream DNS)"

            # Backup existing config
            cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "Original config backed up"
        else
            # Manual configuration change, ask for confirmation
            log_warning "Configuration file already exists"
            read -p "Overwrite existing configuration? [y/N] (press Enter to skip): " overwrite

            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                log_info "Keeping existing configuration"
                return 0
            fi

            # Backup existing config
            cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "Existing config backed up"
        fi
    fi

    # Create configuration
    cat > "$config_file" << 'EOF'
# SmartDNS configuration
bind [::]:53

# Upstream DNS servers
server 8.8.8.8
server 8.8.4.4
server 1.1.1.1
server 1.0.0.1
server 9.9.9.9
server 149.112.112.112
server 208.67.222.222
server 208.67.220.220

# Cache settings
cache-size 3333
rr-ttl-min 900
rr-ttl-max 3600
cache-persist yes
cache-file /var/cache/smartdns/smartdns.cache

# Serve expired cache
serve-expired yes
serve-expired-ttl 259200
serve-expired-reply-ttl 3
prefetch-domain yes
serve-expired-prefetch-time 21600

# Cache checkpoint
cache-checkpoint-time 86400

# Logging
log-level info
log-file /var/log/smartdns/smartdns.log
log-size 10M
log-num 2

# Audit logging
audit-enable yes
audit-file /var/log/smartdns/smartdns-audit.log
audit-size 10M
audit-num 2
EOF

    log_success "SmartDNS configuration created at $config_file"
}

# Configure system to use SmartDNS
configure_system_dns() {
    log_step "Configuring system to use SmartDNS..."

    # Update /etc/resolv.conf
    cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
nameserver ::1
EOF

    # Make it immutable to prevent overwriting
    chattr -i /etc/resolv.conf 2>/dev/null || true
    chattr +i /etc/resolv.conf

    log_success "System configured to use SmartDNS (127.0.0.1)"
    log_info "/etc/resolv.conf is now protected (immutable)"
}

# Install SmartDNS
install_smartdns() {
    log_step "Installing SmartDNS..."
    echo ""

    if check_smartdns_installed; then
        log_warning "SmartDNS is already installed"
        echo ""
        log_info "Current version: $(get_smartdns_version)"
        if check_smartdns_running; then
            log_success "SmartDNS is running"
        else
            log_warning "SmartDNS is installed but not running"
        fi
        return 0
    fi

    # Install dnsutils first
    if ! install_dnsutils; then
        log_error "Failed to install required dnsutils package"
        return 1
    fi

    echo ""

    # Check and handle DNS services
    if ! check_dns_services; then
        return 1
    fi

    echo ""

    # Install SmartDNS from official repository
    log_info "Updating package list..."
    apt-get update -qq

    log_info "Installing SmartDNS..."
    if apt-get install -y smartdns; then
        log_success "SmartDNS installed successfully"
    else
        log_error "Failed to install SmartDNS"
        return 1
    fi

    echo ""

    # Create configuration (auto mode - will replace default config without asking)
    create_smartdns_config "auto"

    echo ""

    # Enable and start service
    log_step "Enabling and starting SmartDNS service..."
    systemctl enable smartdns
    systemctl start smartdns

    if check_smartdns_running; then
        log_success "SmartDNS service is running"
    else
        log_error "SmartDNS service failed to start"
        log_info "Check logs with: journalctl -u smartdns -n 50"
        return 1
    fi

    echo ""

    # Configure system DNS
    configure_system_dns

    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "SmartDNS Installation Complete!"
    log_info "Version: $(get_smartdns_version)"
    log_info "Config file: /etc/smartdns/smartdns.conf"
    log_info "Cache file: /var/cache/smartdns/smartdns.cache"
    log_info "Log files:"
    log_info "  - /var/log/smartdns/smartdns.log"
    log_info "  - /var/log/smartdns/smartdns-audit.log"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Testing DNS resolution..."
    if dig example.com @127.0.0.1 +short &>/dev/null; then
        log_success "DNS resolution test successful!"
    else
        log_warning "DNS resolution test failed. Please check configuration."
    fi
}

# Update SmartDNS
update_smartdns() {
    log_step "Updating SmartDNS..."

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    local current_version=$(get_smartdns_version)
    log_info "Current version: $current_version"

    echo ""
    log_info "Checking for updates..."
    apt-get update -qq

    # Check if updates are available
    local update_available=$(apt-cache policy smartdns | grep -A1 "Installed:" | grep "Candidate:" | awk '{print $2}')
    local installed=$(apt-cache policy smartdns | grep "Installed:" | awk '{print $2}')

    if [ "$installed" = "$update_available" ]; then
        log_success "SmartDNS is already up to date!"
        return 0
    fi

    echo ""
    log_info "Update available: $update_available"
    log_info "Installing update..."

    if apt-get upgrade -y smartdns; then
        log_success "SmartDNS updated successfully"

        # Restart service
        systemctl restart smartdns

        if check_smartdns_running; then
            log_success "SmartDNS service restarted successfully"
            log_info "New version: $(get_smartdns_version)"
        else
            log_warning "SmartDNS service failed to restart"
            log_info "Please check: systemctl status smartdns"
        fi
    else
        log_error "SmartDNS update failed"
        return 1
    fi
}

# Uninstall SmartDNS
uninstall_smartdns() {
    log_step "Uninstalling SmartDNS..."

    if ! check_smartdns_installed; then
        log_warning "SmartDNS is not installed"
        return 0
    fi

    echo ""
    log_warning "This will remove SmartDNS and restore DNS configuration"
    read -p "Are you sure you want to continue? [y/N] (press Enter to cancel): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    # Stop and disable service
    log_info "Stopping SmartDNS service..."
    systemctl stop smartdns 2>/dev/null || true
    systemctl disable smartdns 2>/dev/null || true

    # Remove immutable flag from resolv.conf
    log_info "Restoring DNS configuration..."
    chattr -i /etc/resolv.conf 2>/dev/null || true

    # Restore default DNS
    cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

    # Uninstall package
    log_info "Removing SmartDNS package..."
    apt-get remove --purge -y smartdns

    # Clean up cache directory (optional)
    read -p "Remove cache and log files? [y/N] (press Enter to keep): " remove_data

    if [[ "$remove_data" =~ ^[Yy]$ ]]; then
        rm -rf /var/cache/smartdns
        rm -rf /var/log/smartdns
        log_info "Cache and log files removed"
    fi

    log_success "SmartDNS has been uninstalled"
    log_info "DNS configuration restored to use 8.8.8.8 and 1.1.1.1"
}

# Start SmartDNS service
start_smartdns() {
    log_step "Starting SmartDNS service..."

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    systemctl start smartdns

    if check_smartdns_running; then
        log_success "SmartDNS service started successfully"
        systemctl status smartdns --no-pager
    else
        log_error "Failed to start SmartDNS service"
        log_info "Check logs with: journalctl -u smartdns -n 50"
        return 1
    fi
}

# Stop SmartDNS service
stop_smartdns() {
    log_step "Stopping SmartDNS service..."

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    systemctl stop smartdns

    if ! check_smartdns_running; then
        log_success "SmartDNS service stopped successfully"
    else
        log_error "Failed to stop SmartDNS service"
        return 1
    fi
}

# Restart SmartDNS service
restart_smartdns() {
    log_step "Restarting SmartDNS service..."

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    systemctl restart smartdns

    if check_smartdns_running; then
        log_success "SmartDNS service restarted successfully"
        systemctl status smartdns --no-pager
    else
        log_error "Failed to restart SmartDNS service"
        log_info "Check logs with: journalctl -u smartdns -n 50"
        return 1
    fi
}

# View service status
view_status() {
    log_step "Checking SmartDNS status..."
    echo ""

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Version:${NC} $(get_smartdns_version)"
    echo ""

    systemctl status smartdns --no-pager

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Config File:${NC} /etc/smartdns/smartdns.conf"
    echo -e "${CYAN}Cache File:${NC} /var/cache/smartdns/smartdns.cache"
    echo -e "${CYAN}Log Files:${NC}"
    echo -e "  - /var/log/smartdns/smartdns.log"
    echo -e "  - /var/log/smartdns/smartdns-audit.log"
    echo -e "${CYAN}DNS Server:${NC} 127.0.0.1:53"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# View logs
view_logs() {
    log_step "Viewing SmartDNS logs..."
    echo ""

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    echo -e "${CYAN}1.${NC} View service logs (systemd journal)"
    echo -e "${CYAN}2.${NC} View SmartDNS log file"
    echo -e "${CYAN}3.${NC} View audit log file"
    echo ""
    read -p "Select log type [1-3]: " log_choice

    case $log_choice in
        1)
            log_info "Showing last 50 lines of systemd journal (Press Ctrl+C to exit)"
            echo ""
            journalctl -u smartdns -n 50 --no-pager
            ;;
        2)
            if [ -f /var/log/smartdns/smartdns.log ]; then
                log_info "Showing last 50 lines of SmartDNS log"
                echo ""
                tail -n 50 /var/log/smartdns/smartdns.log
            else
                log_warning "Log file not found: /var/log/smartdns/smartdns.log"
            fi
            ;;
        3)
            if [ -f /var/log/smartdns/smartdns-audit.log ]; then
                log_info "Showing last 50 lines of audit log"
                echo ""
                tail -n 50 /var/log/smartdns/smartdns-audit.log
            else
                log_warning "Audit log file not found: /var/log/smartdns/smartdns-audit.log"
            fi
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
}

# View cache statistics
view_cache_stats() {
    log_step "Viewing cache statistics..."
    echo ""

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    if ! check_smartdns_running; then
        log_error "SmartDNS is not running"
        return 1
    fi

    local cache_file="/var/cache/smartdns/smartdns.cache"

    if [ ! -f "$cache_file" ]; then
        log_warning "Cache file not found: $cache_file"
        log_info "SmartDNS may be running but hasn't cached any domains yet"
        return 0
    fi

    log_info "Counting cached domains..."
    local cache_count=$(smartdns --cache-print "$cache_file" 2>/dev/null | wc -l)

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Cache Statistics${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Cached domains:${NC} $cache_count"

    # Show cache file size
    local cache_size=$(du -h "$cache_file" 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN}Cache file size:${NC} $cache_size"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Clear cache
clear_cache() {
    log_step "Clearing SmartDNS cache..."
    echo ""

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    log_warning "This will clear all cached DNS records"
    read -p "Are you sure you want to continue? [y/N] (press Enter to cancel): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Cache clear cancelled"
        return 0
    fi

    local cache_file="/var/cache/smartdns/smartdns.cache"

    # Show current cache count
    if [ -f "$cache_file" ]; then
        local before_count=$(smartdns --cache-print "$cache_file" 2>/dev/null | wc -l)
        log_info "Current cached domains: $before_count"
    fi

    echo ""
    log_info "Stopping SmartDNS service..."
    systemctl stop smartdns

    sleep 1

    if [ -f "$cache_file" ]; then
        log_info "Removing cache file..."
        rm -f "$cache_file"
        log_success "Cache file removed"
    else
        log_info "Cache file not found, nothing to remove"
    fi

    log_info "Starting SmartDNS service..."
    systemctl start smartdns

    sleep 2

    if check_smartdns_running; then
        log_success "SmartDNS service restarted successfully"
        log_success "Cache has been cleared"
        echo ""
        log_info "You can verify by checking cache statistics after using DNS for a while"
    else
        log_error "Failed to restart SmartDNS service"
        log_info "Please check: systemctl status smartdns"
        return 1
    fi
}

# Test DNS resolution
test_dns() {
    log_step "Testing DNS resolution..."
    echo ""

    if ! check_smartdns_installed; then
        log_error "SmartDNS is not installed"
        return 1
    fi

    if ! check_smartdns_running; then
        log_error "SmartDNS is not running"
        return 1
    fi

    local test_domain="example.com"

    log_info "Testing DNS resolution for $test_domain..."
    echo ""

    # First query
    log_info "First query (should be slower):"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    dig @127.0.0.1 $test_domain +stats | grep -E "(Query time|ANSWER SECTION)" | head -10
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo ""
    sleep 1

    # Second query (should be cached)
    log_info "Second query (should be faster, from cache):"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    dig @127.0.0.1 $test_domain +stats | grep -E "(Query time|ANSWER SECTION)" | head -10
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo ""
    log_info "If the second query shows '0 msec' or very low query time, caching is working correctly!"
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}              SmartDNS Management                  ${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Show status
        if check_smartdns_installed; then
            if check_smartdns_running; then
                echo -e "${GREEN}Status: SmartDNS is installed and running${NC}"
                echo -e "${CYAN}Version:${NC} $(get_smartdns_version)"
            else
                echo -e "${YELLOW}Status: SmartDNS is installed but not running${NC}"
                echo -e "${CYAN}Version:${NC} $(get_smartdns_version)"
            fi
            echo ""
            echo -e "${CYAN}Important Paths:${NC}"
            echo -e "  ${CYAN}Config:${NC}  /etc/smartdns/smartdns.conf"
            echo -e "  ${CYAN}Cache:${NC}   /var/cache/smartdns/smartdns.cache"
            echo -e "  ${CYAN}Logs:${NC}    /var/log/smartdns/smartdns.log"
            echo -e "           /var/log/smartdns/smartdns-audit.log"
        else
            echo -e "${YELLOW}Status: SmartDNS is not installed${NC}"
        fi
        echo ""

        echo -e "${CYAN}┌─ Installation & Updates ─────────────────────────┐${NC}"
        echo -e "${GREEN} 1.${NC} Install SmartDNS"
        echo -e "${GREEN} 2.${NC} Update SmartDNS"
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
        echo -e "${CYAN}┌─ Cache Management ───────────────────────────────┐${NC}"
        echo -e "${PURPLE} 8.${NC} View cache statistics"
        echo -e "${PURPLE} 9.${NC} Clear cache"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Testing & Diagnostics ──────────────────────────┐${NC}"
        echo -e "${BLUE}10.${NC} Test DNS resolution"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Advanced ───────────────────────────────────────┐${NC}"
        echo -e "${RED}11.${NC} Uninstall SmartDNS"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${YELLOW} 0.${NC} Return to Main Menu"
        echo ""

        read -p "Please select an option [0-11, or press Enter to exit]: " choice

        case $choice in
            1)
                install_smartdns
                ;;
            2)
                update_smartdns
                ;;
            3)
                start_smartdns
                ;;
            4)
                stop_smartdns
                ;;
            5)
                restart_smartdns
                ;;
            6)
                view_status
                ;;
            7)
                view_logs
                ;;
            8)
                view_cache_stats
                ;;
            9)
                clear_cache
                ;;
            10)
                test_dns
                ;;
            11)
                uninstall_smartdns
                ;;
            0|"")
                log_info "Returning to main menu..."
                break
                ;;
            *)
                log_error "Invalid option. Please select 0-11"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main menu
main_menu
