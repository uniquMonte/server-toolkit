#!/bin/bash

#######################################
# SSH Login Notifier Management
# Based on: https://github.com/uniquMonte/ssh-login-notifier
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

# Check if SSH login notifier is installed
check_installed() {
    # Check for the actual installation paths used by ssh-login-notifier
    # Primary check: main notification script and config directory
    if [ -f "/usr/local/bin/ssh-login-notify.sh" ] || \
       [ -d "/etc/ssh-login-notifier" ] || \
       [ -f "/etc/ssh-login-notifier/config" ] || \
       [ -f "/usr/local/bin/report-failed-logins.sh" ]; then
        return 0
    fi

    # Legacy/alternative installation locations
    if [ -f "/usr/local/bin/ssh-login-notifier" ] || \
       [ -f "/opt/ssh-login-notifier/notifier.sh" ] || \
       [ -d "/opt/ssh-login-notifier" ] || \
       [ -f "/root/ssh-login-notifier/ssh_login_notifier.sh" ] || \
       [ -d "/root/.ssh-login-notifier" ]; then
        return 0
    fi

    return 1
}

# Get installation path
get_install_path() {
    # Check for the actual installation paths first
    if [ -f "/usr/local/bin/ssh-login-notify.sh" ]; then
        echo "/usr/local/bin/ssh-login-notify.sh"
    elif [ -d "/etc/ssh-login-notifier" ]; then
        echo "/etc/ssh-login-notifier"
    elif [ -f "/usr/local/bin/report-failed-logins.sh" ]; then
        echo "/usr/local/bin (report-failed-logins.sh)"
    # Legacy/alternative paths
    elif [ -f "/usr/local/bin/ssh-login-notifier" ]; then
        echo "/usr/local/bin/ssh-login-notifier"
    elif [ -f "/opt/ssh-login-notifier/notifier.sh" ]; then
        echo "/opt/ssh-login-notifier/notifier.sh"
    elif [ -d "/opt/ssh-login-notifier" ]; then
        echo "/opt/ssh-login-notifier"
    elif [ -f "/root/ssh-login-notifier/ssh_login_notifier.sh" ]; then
        echo "/root/ssh-login-notifier/ssh_login_notifier.sh"
    elif [ -d "/root/.ssh-login-notifier" ]; then
        echo "/root/.ssh-login-notifier"
    else
        echo ""
    fi
}

# Check if PAM hook is configured
check_pam_configured() {
    # Check if PAM exec is configured for SSH login notifications
    if [ -f "/etc/pam.d/sshd" ]; then
        if grep -q "pam_exec.so.*login.*notifier\|ssh.*login.*notify\|ssh.*alert" /etc/pam.d/sshd 2>/dev/null; then
            return 0
        fi
    fi

    # Check if there's a profile.d script
    if [ -f "/etc/profile.d/ssh-login-notifier.sh" ] || \
       [ -f "/etc/profile.d/ssh-notify.sh" ]; then
        return 0
    fi

    return 1
}

# Check recent SSH login attempts
get_recent_logins() {
    local login_count=0
    local failed_count=0

    # Get successful logins from last 24 hours
    if command -v journalctl &> /dev/null; then
        login_count=$(journalctl -u ssh -u sshd --since "24 hours ago" 2>/dev/null | \
                     grep -c "Accepted password\|Accepted publickey" 2>/dev/null || echo 0)
        failed_count=$(journalctl -u ssh -u sshd --since "24 hours ago" 2>/dev/null | \
                      grep -c "Failed password\|authentication failure" 2>/dev/null || echo 0)
    else
        # Fallback to auth.log
        if [ -f "/var/log/auth.log" ]; then
            login_count=$(grep -c "Accepted password\|Accepted publickey" /var/log/auth.log 2>/dev/null || echo 0)
            failed_count=$(grep -c "Failed password\|authentication failure" /var/log/auth.log 2>/dev/null || echo 0)
        fi
    fi

    echo "$login_count|$failed_count"
}

# Show current SSH login notifier status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}SSH Login Notifier Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_installed; then
        local install_path=$(get_install_path)
        echo -e "${GREEN}Installation Status:${NC}  ${GREEN}Installed ✓${NC}"
        echo -e "Installation Path:    ${CYAN}$install_path${NC}"

        # Check if PAM is configured
        if check_pam_configured; then
            echo -e "${GREEN}PAM Hook Status:${NC}      ${GREEN}Configured ✓${NC}"
            echo -e "                      ${CYAN}SSH logins will trigger notifications${NC}"
        else
            echo -e "${YELLOW}PAM Hook Status:${NC}      ${YELLOW}Not configured${NC}"
            echo -e "                      ${YELLOW}Notifications may not be active${NC}"
        fi

        # Show recent activity
        echo ""
        echo -e "${GREEN}Recent SSH Activity (Last 24 Hours):${NC}"
        local activity=$(get_recent_logins)
        local successful=$(echo "$activity" | cut -d'|' -f1)
        local failed=$(echo "$activity" | cut -d'|' -f2)

        echo -e "  Successful Logins:  ${GREEN}$successful${NC}"
        echo -e "  Failed Attempts:    ${RED}$failed${NC}"

        if [ "$failed" -gt 10 ]; then
            echo -e "  ${RED}⚠ High number of failed attempts detected!${NC}"
        fi

    else
        echo -e "${YELLOW}Installation Status:${NC}  ${YELLOW}Not installed${NC}"
        echo ""
        log_info "SSH Login Notifier provides:"
        echo -e "  ${GREEN}•${NC} Real-time alerts for SSH logins"
        echo -e "  ${GREEN}•${NC} Brute-force attack detection"
        echo -e "  ${GREEN}•${NC} Detailed login information (IP, location, ISP)"
        echo -e "  ${GREEN}•${NC} Multi-server management support"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Install SSH login notifier
install_notifier() {
    echo ""
    log_info "Installing SSH Login Notifier..."
    echo ""
    log_info "Download URL: https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh"
    echo ""

    if check_installed; then
        log_warning "SSH Login Notifier appears to be already installed"
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
    # Using pipe mode (recommended for compatibility)
    if command -v curl &> /dev/null; then
        curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi

    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "SSH Login Notifier installation completed"
        echo ""
        log_info "You may need to configure notification settings"
        log_info "Test by logging in via SSH from another session"
    else
        log_error "Installation failed with exit code: $exit_code"
        return 1
    fi

    return $exit_code
}

# Configure SSH login notifier
configure_notifier() {
    if ! check_installed; then
        log_error "SSH Login Notifier is not installed"
        echo ""
        read -p "Do you want to install it now? [Y/n] (press Enter to install): " install
        if [[ ! $install =~ ^[Nn]$ ]]; then
            install_notifier
        fi
        return
    fi

    echo ""
    log_info "Opening SSH Login Notifier configuration..."
    echo ""
    log_info "Re-running installation script to access configuration menu..."
    echo ""

    # The ssh-login-notifier configuration is handled by re-running the install script
    # It will detect the existing installation and show the management menu
    if command -v curl &> /dev/null; then
        curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget to access configuration"
        return 1
    fi
}

# Test notification
test_notifier() {
    if ! check_installed; then
        log_error "SSH Login Notifier is not installed"
        return 1
    fi

    echo ""
    log_info "Testing SSH Login Notifier..."
    echo ""

    local install_path=$(get_install_path)

    # Try to find test script or trigger a test notification
    if [ -f "/opt/ssh-login-notifier/test.sh" ]; then
        bash /opt/ssh-login-notifier/test.sh
    elif [ -f "/root/ssh-login-notifier/test.sh" ]; then
        bash /root/ssh-login-notifier/test.sh
    elif [ -f "/usr/local/bin/ssh-login-notifier" ]; then
        /usr/local/bin/ssh-login-notifier --test 2>/dev/null || {
            log_warning "Test command not available"
            log_info "To test notifications, try logging in via SSH from another session"
        }
    else
        log_info "To test notifications, try logging in via SSH from another session"
        log_info "You should receive a notification with login details"
    fi
}

# Uninstall SSH login notifier
uninstall_notifier() {
    if ! check_installed; then
        log_warning "SSH Login Notifier is not installed"
        return 0
    fi

    echo ""
    log_warning "This will remove SSH Login Notifier from your system"
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    echo ""
    log_info "Removing SSH Login Notifier..."

    # Remove PAM configuration
    if [ -f "/etc/pam.d/sshd.bak" ]; then
        log_info "Restoring original PAM configuration..."
        cp /etc/pam.d/sshd.bak /etc/pam.d/sshd
    else
        # Remove notifier lines from PAM
        if [ -f "/etc/pam.d/sshd" ]; then
            sed -i '/pam_exec.so.*login.*notifier\|ssh.*login.*notify\|ssh.*alert/d' /etc/pam.d/sshd
        fi
    fi

    # Remove profile.d scripts
    rm -f /etc/profile.d/ssh-login-notifier.sh /etc/profile.d/ssh-notify.sh

    # Remove installation files and directories
    local removed=0

    # Remove actual installation files
    for path in "/usr/local/bin/ssh-login-notify.sh" \
                "/usr/local/bin/report-failed-logins.sh" \
                "/usr/local/bin/ssh-login-notifier-uninstall.sh" \
                "/etc/ssh-login-notifier"; do
        if [ -e "$path" ]; then
            rm -rf "$path"
            log_info "Removed: $path"
            removed=1
        fi
    done

    # Remove legacy/alternative installation paths
    for path in "/usr/local/bin/ssh-login-notifier" \
                "/opt/ssh-login-notifier" \
                "/root/ssh-login-notifier" \
                "/root/.ssh-login-notifier"; do
        if [ -e "$path" ]; then
            rm -rf "$path"
            log_info "Removed: $path"
            removed=1
        fi
    done

    if [ $removed -eq 1 ]; then
        log_success "SSH Login Notifier uninstalled successfully"
        log_info "You may need to restart SSH service for changes to take effect"
        echo ""
        read -p "Restart SSH service now? [y/N]: " restart_ssh
        if [[ $restart_ssh =~ ^[Yy]$ ]]; then
            systemctl restart sshd || systemctl restart ssh || service ssh restart
            log_success "SSH service restarted"
        fi
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
            install_notifier
            ;;
        configure|setup|config)
            configure_notifier
            ;;
        test)
            test_notifier
            ;;
        uninstall|remove)
            uninstall_notifier
            ;;
        menu)
            while true; do
                show_status
                echo ""

                if check_installed; then
                    echo -e "${GREEN}Available actions:${NC}"
                    echo -e "  ${CYAN}1.${NC} Configure notification settings"
                    echo -e "  ${CYAN}2.${NC} Test notifications"
                    echo -e "  ${CYAN}3.${NC} View recent SSH activity"
                    echo -e "  ${CYAN}4.${NC} Uninstall SSH Login Notifier"
                    echo -e "  ${CYAN}0.${NC} Return to main menu"
                    echo ""
                    read -p "Select action [0-4, or press Enter to return]: " action

                    case $action in
                        1)
                            configure_notifier
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        2)
                            test_notifier
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        3)
                            # Status will be shown at the start of next loop
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        4)
                            uninstall_notifier
                            if ! check_installed; then
                                # If uninstalled successfully, exit the menu
                                echo ""
                                log_info "Returning to main menu"
                                break
                            fi
                            echo ""
                            read -p "Press Enter to continue..."
                            ;;
                        0|"")
                            log_info "Returning to main menu"
                            break
                            ;;
                        *)
                            log_error "Invalid selection"
                            sleep 1
                            ;;
                    esac
                else
                    echo ""
                    read -p "SSH Login Notifier is not installed. Install now? [Y/n] (press Enter to install): " install
                    if [[ ! $install =~ ^[Nn]$ ]]; then
                        install_notifier
                        echo ""
                        read -p "Press Enter to continue..."
                    else
                        log_info "Returning to main menu"
                        break
                    fi
                fi
            done
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|install|configure|test|uninstall|menu}"
            exit 1
            ;;
    esac
}

main "$@"
