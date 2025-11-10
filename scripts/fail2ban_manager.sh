#!/bin/bash

#######################################
# Fail2ban Management Script
# Prevents SSH brute force attacks and other attacks
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# Check if Fail2ban is installed
check_fail2ban_installed() {
    if command -v fail2ban-client &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Display Fail2ban introduction
show_fail2ban_info() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Fail2ban - Intrusion Prevention System${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  🛡️  Prevents SSH brute force attacks"
    echo -e "  🚫 Automatically bans malicious IP addresses"
    echo -e "  📊 Supports protection for multiple services (SSH, Nginx, Apache, etc.)"
    echo -e "  ⏱️  Configurable ban time and retry attempts"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Install Fail2ban
install_fail2ban() {
    show_fail2ban_info

    if check_fail2ban_installed; then
        log_warning "Fail2ban is already installed"
        fail2ban-client version
        return
    fi

    log_info "Starting Fail2ban installation..."
    detect_os

    case $OS in
        ubuntu|debian)
            log_info "Installing Fail2ban using APT..."
            apt-get update
            apt-get install -y fail2ban
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Installing Fail2ban using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf install -y epel-release
                dnf install -y fail2ban fail2ban-systemd
            else
                yum install -y epel-release
                yum install -y fail2ban fail2ban-systemd
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    if check_fail2ban_installed; then
        log_success "Fail2ban installed successfully"
        configure_fail2ban
    else
        log_error "Fail2ban installation failed"
        exit 1
    fi
}

# Configure Fail2ban
configure_fail2ban() {
    log_info "Configuring Fail2ban..."

    # Create local configuration file
    log_info "Creating local configuration file..."

    # Ask for SSH port
    read -p "Enter SSH port (default: 22) (直接回车使用默认): " ssh_port
    ssh_port=${ssh_port:-22}

    # Ask for ban time
    read -p "Ban time in minutes (default: 60) (直接回车使用默认): " ban_time
    ban_time=${ban_time:-60}
    ban_time=$((ban_time * 60))  # Convert to seconds

    # Ask for find time
    read -p "Find time window in minutes (default: 10) (直接回车使用默认): " find_time
    find_time=${find_time:-10}
    find_time=$((find_time * 60))  # Convert to seconds

    # Ask for max retry
    read -p "Maximum failed attempts (default: 5) (直接回车使用默认): " max_retry
    max_retry=${max_retry:-5}

    # Detect if systemd journal is available
    local use_systemd="auto"
    if command -v journalctl &>/dev/null && systemctl is-active --quiet systemd-journald; then
        use_systemd="systemd"
        log_info "Detected systemd, using journal backend"
    else
        use_systemd="auto"
        log_info "Using traditional log files"
    fi

    # Create jail.local configuration
    if [ "$use_systemd" = "systemd" ]; then
        # Configuration for systemd backend (no logpath needed)
        cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# Ban time (seconds)
bantime = ${ban_time}

# Find time window (seconds)
findtime = ${find_time}

# Maximum attempts
maxretry = ${max_retry}

# Ignored IPs (localhost and private networks)
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# Ban action
banaction = iptables-multiport
banaction_allports = iptables-allports

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
backend = systemd
maxretry = ${max_retry}
EOF
    else
        # Configuration for file-based logs
        local logpath="/var/log/auth.log"
        if [[ "$OS" =~ ^(centos|rhel|rocky|almalinux|fedora)$ ]]; then
            logpath="/var/log/secure"
        fi

        cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# Ban time (seconds)
bantime = ${ban_time}

# Find time window (seconds)
findtime = ${find_time}

# Maximum attempts
maxretry = ${max_retry}

# Ignored IPs (localhost and private networks)
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# Ban action
banaction = iptables-multiport
banaction_allports = iptables-allports

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
logpath = ${logpath}
maxretry = ${max_retry}
EOF
    fi

    log_success "Configuration file created"

    # Start Fail2ban
    log_info "Starting Fail2ban service..."
    systemctl enable fail2ban
    systemctl start fail2ban

    # Wait for service to start
    sleep 2

    # Verify status
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban installation and configuration complete!"
        echo ""
        log_info "Configuration summary:"
        echo -e "  SSH port: ${GREEN}${ssh_port}${NC}"
        echo -e "  Ban time: ${GREEN}$((ban_time / 60)) minutes${NC}"
        echo -e "  Find time: ${GREEN}$((find_time / 60)) minutes${NC}"
        echo -e "  Max attempts: ${GREEN}${max_retry} times${NC}"
        echo ""
        log_info "View status: fail2ban-client status sshd"
        log_info "Unban IP: fail2ban-client set sshd unbanip <IP>"
    else
        log_error "Fail2ban failed to start"
        systemctl status fail2ban
    fi
}

# Display Fail2ban status
show_status() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban is not installed"
        return
    fi

    echo ""
    log_info "Fail2ban service status:"
    systemctl status fail2ban --no-pager -l

    echo ""
    log_info "Fail2ban jail status:"
    fail2ban-client status

    echo ""
    log_info "SSH jail detailed information:"
    fail2ban-client status sshd 2>/dev/null || log_warning "SSH jail is not enabled"
}

# Unban IP
unban_ip() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban is not installed"
        return
    fi

    read -p "Enter IP address to unban: " ip_address

    if [ -z "$ip_address" ]; then
        log_error "IP address cannot be empty"
        return
    fi

    log_info "Unbanning IP: ${ip_address}..."

    if fail2ban-client set sshd unbanip "$ip_address" 2>/dev/null; then
        log_success "IP ${ip_address} has been unbanned"
    else
        log_error "Unban failed, IP may not be banned"
    fi
}

# View banned IPs
show_banned_ips() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban is not installed"
        return
    fi

    echo ""
    log_info "Currently banned IP addresses:"

    # More robust parsing using fail2ban-client
    if ! banned=$(fail2ban-client status sshd 2>/dev/null); then
        log_error "Failed to get fail2ban status (sshd jail may not be enabled)"
        return
    fi

    # Extract banned IPs more reliably
    banned_ips=$(echo "$banned" | grep -oP '(?<=Banned IP list:).*' | xargs)

    if [ -z "$banned_ips" ] || [ "$banned_ips" = "" ]; then
        echo "  No currently banned IPs"
    else
        echo "$banned_ips" | tr ' ' '\n' | grep -v '^$' | while read -r ip; do
            if [ -n "$ip" ]; then
                echo -e "  ${RED}${ip}${NC}"
            fi
        done
    fi
}

# Uninstall Fail2ban
uninstall_fail2ban() {
    log_warning "Starting Fail2ban uninstallation..."

    if ! check_fail2ban_installed; then
        log_warning "Fail2ban is not installed, no need to uninstall"
        return
    fi

    read -p "Are you sure you want to uninstall Fail2ban? (y/N) (直接回车取消): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi

    detect_os

    # Stop service
    log_info "Stopping Fail2ban service..."
    systemctl stop fail2ban
    systemctl disable fail2ban

    # Uninstall
    case $OS in
        ubuntu|debian)
            log_info "Uninstalling Fail2ban using APT..."
            apt-get purge -y fail2ban
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Uninstalling Fail2ban using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf remove -y fail2ban fail2ban-systemd
            else
                yum remove -y fail2ban fail2ban-systemd
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Delete configuration files
    read -p "Delete configuration files? (y/N) (直接回车跳过): " delete_config
    if [[ $delete_config =~ ^[Yy]$ ]]; then
        log_info "Deleting configuration files..."
        rm -rf /etc/fail2ban
    fi

    if check_fail2ban_installed; then
        log_error "Fail2ban uninstallation failed"
    else
        log_success "Fail2ban uninstallation complete!"
    fi
}

# Display help
show_help() {
    echo "Usage: $0 {install|status|unban|show-banned|uninstall}"
    echo ""
    echo "Commands:"
    echo "  install      - Install and configure Fail2ban"
    echo "  status       - View Fail2ban status"
    echo "  unban        - Unban specific IP address"
    echo "  show-banned  - View list of banned IPs"
    echo "  uninstall    - Uninstall Fail2ban"
    echo ""
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "$1" in
        install)
            install_fail2ban
            ;;
        status)
            show_status
            ;;
        unban)
            unban_ip
            ;;
        show-banned)
            show_banned_ips
            ;;
        uninstall)
            uninstall_fail2ban
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
