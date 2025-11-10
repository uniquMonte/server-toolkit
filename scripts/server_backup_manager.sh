#!/bin/bash

#######################################
# Server Backup Manager
# Based on: https://github.com/uniquMonte/server-backup
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration file location
BACKUP_ENV="/usr/local/bin/vps-backup.env"
BACKUP_SCRIPT="/usr/local/bin/vps-backup.sh"
RESTORE_SCRIPT="/usr/local/bin/vps-restore.sh"

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

# Check if server backup is installed
check_installed() {
    # Check for common installation locations
    if [ -f "$BACKUP_ENV" ] || \
       [ -f "$BACKUP_SCRIPT" ] || \
       [ -f "/opt/server-backup/backup_restore.sh" ] || \
       [ -d "/opt/server-backup" ]; then
        return 0
    else
        return 1
    fi
}

# Get installation path
get_install_path() {
    if [ -f "$BACKUP_ENV" ]; then
        echo "$BACKUP_ENV"
    elif [ -f "$BACKUP_SCRIPT" ]; then
        echo "$BACKUP_SCRIPT"
    elif [ -d "/opt/server-backup" ]; then
        echo "/opt/server-backup"
    else
        echo ""
    fi
}

# Check if backup is configured
check_configured() {
    if [ -f "$BACKUP_ENV" ]; then
        # Check if the configuration file has actual content
        if grep -q "BACKUP_REMOTE_DIR" "$BACKUP_ENV" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if cron job is configured
check_cron_configured() {
    if crontab -l 2>/dev/null | grep -q "vps-backup\|server-backup"; then
        return 0
    else
        return 1
    fi
}

# Get backup statistics
get_backup_stats() {
    if ! check_configured; then
        return 1
    fi

    # Source configuration
    source "$BACKUP_ENV" 2>/dev/null || return 1

    echo ""
    echo -e "${GREEN}Backup Configuration:${NC}"

    # Show configured directories
    if [ -n "$BACKUP_DIRS" ]; then
        echo -e "  Backup Directories:"
        for dir in $BACKUP_DIRS; do
            if [ -d "$dir" ]; then
                local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                echo -e "    ${CYAN}$dir${NC} (${size})"
            else
                echo -e "    ${YELLOW}$dir${NC} (not found)"
            fi
        done
    fi

    # Show remote configuration
    if [ -n "$BACKUP_REMOTE_DIR" ]; then
        echo -e "  Remote Storage: ${CYAN}${BACKUP_REMOTE_DIR}${NC}"
    fi

    # Show retention policy
    if [ -n "$BACKUP_RETENTION_DAYS" ]; then
        echo -e "  Retention: ${CYAN}${BACKUP_RETENTION_DAYS} days${NC}"
    fi

    # Show VPS identifier if configured
    if [ -n "$VPS_IDENTIFIER" ]; then
        echo -e "  VPS ID: ${CYAN}${VPS_IDENTIFIER}${NC}"
    fi

    # Check if encryption is enabled
    if [ -n "$BACKUP_PASSWORD" ]; then
        echo -e "  Encryption: ${GREEN}Enabled ✓${NC}"
    else
        echo -e "  Encryption: ${YELLOW}Not configured${NC}"
    fi

    # Check if Telegram notifications are configured
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        echo -e "  Telegram Alerts: ${GREEN}Enabled ✓${NC}"
    else
        echo -e "  Telegram Alerts: ${YELLOW}Not configured${NC}"
    fi
}

# Show current backup status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Server Backup Manager Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if check_installed; then
        local install_path=$(get_install_path)
        echo -e "${GREEN}Installation Status:${NC}  ${GREEN}Installed ✓${NC}"
        echo -e "Installation Path:    ${CYAN}$install_path${NC}"

        # Check if configured
        if check_configured; then
            echo -e "${GREEN}Configuration:${NC}       ${GREEN}Configured ✓${NC}"
            get_backup_stats
        else
            echo -e "${YELLOW}Configuration:${NC}       ${YELLOW}Not configured${NC}"
            echo ""
            log_info "Please run configuration to set up backups"
        fi

        # Check if cron is configured
        echo ""
        if check_cron_configured; then
            echo -e "${GREEN}Cron Job Status:${NC}      ${GREEN}Configured ✓${NC}"
            echo ""
            echo -e "${GREEN}Active Cron Jobs:${NC}"
            crontab -l 2>/dev/null | grep -i "vps-backup\|server-backup" | while read -r line; do
                echo -e "  ${CYAN}$line${NC}"
            done
        else
            echo -e "${YELLOW}Cron Job Status:${NC}      ${YELLOW}Not configured${NC}"
            echo ""
            log_info "Automatic backups are not scheduled"
        fi

    else
        echo -e "${YELLOW}Installation Status:${NC}  ${YELLOW}Not installed${NC}"
        echo ""
        log_info "Server Backup Manager provides automated encrypted backups"
        log_info "Features: Cloud storage, AES-256 encryption, Telegram alerts"
        log_info "Supports: Google Drive, Dropbox, OneDrive, and more via rclone"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Install server backup
install_server_backup() {
    echo ""
    log_info "Installing Server Backup Manager..."
    echo ""
    log_info "Download URL: https://raw.githubusercontent.com/uniquMonte/server-backup/main/install.sh"
    echo ""

    if check_installed; then
        log_warning "Server Backup appears to be already installed"
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
        curl -Ls https://raw.githubusercontent.com/uniquMonte/server-backup/main/install.sh | sudo bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/uniquMonte/server-backup/main/install.sh | sudo bash
    else
        log_error "Neither curl nor wget is available"
        log_error "Please install curl or wget first"
        return 1
    fi

    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "Server Backup installation completed"
        echo ""
        log_info "Next steps:"
        log_info "1. Configure backup settings (directories, cloud storage, etc.)"
        log_info "2. Set up encryption password"
        log_info "3. Configure Telegram notifications (optional)"
        log_info "4. Test the backup"
    else
        log_error "Installation failed with exit code: $exit_code"
        return 1
    fi

    return $exit_code
}

# Configure server backup
configure_server_backup() {
    if ! check_installed; then
        log_error "Server Backup is not installed"
        echo ""
        read -p "Do you want to install it now? [Y/n]: " install
        if [[ ! $install =~ ^[Nn]$ ]]; then
            install_server_backup
        fi
        return
    fi

    echo ""
    log_info "Opening Server Backup configuration..."
    echo ""

    # Try to find and run the configuration/setup
    if [ -f "$BACKUP_SCRIPT" ]; then
        # If backup script exists, it might have a config option
        bash "$BACKUP_SCRIPT" --configure 2>/dev/null || {
            log_warning "Direct configuration not available"
            log_info "Please manually edit: $BACKUP_ENV"
            echo ""
            read -p "Do you want to edit the configuration file now? [y/N]: " edit
            if [[ $edit =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} "$BACKUP_ENV"
            fi
        }
    elif [ -f "$BACKUP_ENV" ]; then
        log_info "Configuration file: $BACKUP_ENV"
        echo ""
        read -p "Do you want to edit the configuration file? [Y/n]: " edit
        if [[ ! $edit =~ ^[Nn]$ ]]; then
            ${EDITOR:-nano} "$BACKUP_ENV"
        fi
    else
        log_warning "Configuration file not found"
        log_info "The backup may need to be run once to generate the configuration"
    fi
}

# Run manual backup
run_manual_backup() {
    if ! check_installed; then
        log_error "Server Backup is not installed"
        return 1
    fi

    if ! check_configured; then
        log_error "Server Backup is not configured"
        log_info "Please configure it first"
        return 1
    fi

    echo ""
    log_info "Starting manual backup..."
    echo ""

    if [ -f "$BACKUP_SCRIPT" ]; then
        bash "$BACKUP_SCRIPT"
    else
        log_error "Backup script not found: $BACKUP_SCRIPT"
        return 1
    fi
}

# Restore from backup
restore_backup() {
    if ! check_installed; then
        log_error "Server Backup is not installed"
        return 1
    fi

    if ! check_configured; then
        log_error "Server Backup is not configured"
        log_info "Please configure it first"
        return 1
    fi

    echo ""
    log_info "Starting backup restore..."
    echo ""

    if [ -f "$RESTORE_SCRIPT" ]; then
        bash "$RESTORE_SCRIPT"
    elif [ -f "/opt/server-backup/backup_restore.sh" ]; then
        bash "/opt/server-backup/backup_restore.sh"
    else
        log_error "Restore script not found"
        log_info "Expected locations: $RESTORE_SCRIPT or /opt/server-backup/backup_restore.sh"
        return 1
    fi
}

# View backup logs
view_logs() {
    if ! check_installed; then
        log_error "Server Backup is not installed"
        return 1
    fi

    echo ""
    log_info "Searching for backup logs..."
    echo ""

    # Common log locations
    local log_locations=(
        "/var/log/vps-backup.log"
        "/var/log/server-backup.log"
        "/tmp/vps-backup.log"
        "$HOME/vps-backup.log"
    )

    local found=0
    for log_file in "${log_locations[@]}"; do
        if [ -f "$log_file" ]; then
            echo -e "${GREEN}Found log:${NC} ${CYAN}$log_file${NC}"
            echo ""
            echo -e "${YELLOW}Last 30 lines:${NC}"
            tail -n 30 "$log_file"
            found=1
            break
        fi
    done

    if [ $found -eq 0 ]; then
        log_warning "No backup logs found"
        log_info "Checked locations: ${log_locations[*]}"
    fi
}

# Uninstall server backup
uninstall_server_backup() {
    if ! check_installed; then
        log_warning "Server Backup is not installed"
        return 0
    fi

    echo ""
    log_warning "This will remove Server Backup from your system"
    log_warning "Your backup files in cloud storage will NOT be deleted"
    echo ""
    read -p "Are you sure you want to uninstall? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    echo ""
    log_info "Removing Server Backup..."

    # Remove cron jobs
    if check_cron_configured; then
        log_info "Removing cron jobs..."
        crontab -l 2>/dev/null | grep -v "vps-backup\|server-backup" | crontab -
    fi

    # Remove scripts and configuration
    local removed=0
    for path in "$BACKUP_ENV" \
                "$BACKUP_SCRIPT" \
                "$RESTORE_SCRIPT" \
                "/opt/server-backup" \
                "/usr/local/bin/vps-backup.sh" \
                "/usr/local/bin/vps-restore.sh"; do
        if [ -e "$path" ]; then
            rm -rf "$path"
            log_info "Removed: $path"
            removed=1
        fi
    done

    if [ $removed -eq 1 ]; then
        log_success "Server Backup uninstalled successfully"
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
            install_server_backup
            ;;
        configure|setup|config)
            configure_server_backup
            ;;
        backup|run)
            run_manual_backup
            ;;
        restore)
            restore_backup
            ;;
        logs)
            view_logs
            ;;
        uninstall|remove)
            uninstall_server_backup
            ;;
        menu)
            show_status
            echo ""

            if check_installed; then
                echo -e "${GREEN}Available actions:${NC}"
                if check_configured; then
                    echo -e "  ${CYAN}1.${NC} Run manual backup now"
                    echo -e "  ${CYAN}2.${NC} Restore from backup"
                    echo -e "  ${CYAN}3.${NC} View backup logs"
                    echo -e "  ${CYAN}4.${NC} Configure backup settings"
                    echo -e "  ${CYAN}5.${NC} Uninstall Server Backup"
                    echo -e "  ${CYAN}0.${NC} Exit"
                    echo ""
                    read -p "Select action [0-5]: " action

                    case $action in
                        1)
                            run_manual_backup
                            ;;
                        2)
                            restore_backup
                            ;;
                        3)
                            view_logs
                            ;;
                        4)
                            configure_server_backup
                            ;;
                        5)
                            uninstall_server_backup
                            ;;
                        0)
                            log_info "Exiting"
                            ;;
                        *)
                            log_error "Invalid selection"
                            ;;
                    esac
                else
                    echo -e "  ${CYAN}1.${NC} Configure backup settings"
                    echo -e "  ${CYAN}2.${NC} Uninstall Server Backup"
                    echo -e "  ${CYAN}0.${NC} Exit"
                    echo ""
                    read -p "Select action [0-2]: " action

                    case $action in
                        1)
                            configure_server_backup
                            ;;
                        2)
                            uninstall_server_backup
                            ;;
                        0)
                            log_info "Exiting"
                            ;;
                        *)
                            log_error "Invalid selection"
                            ;;
                    esac
                fi
            else
                echo ""
                read -p "Server Backup is not installed. Install now? [Y/n] (press Enter to install): " install
                if [[ ! $install =~ ^[Nn]$ ]]; then
                    install_server_backup
                fi
            fi
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|install|configure|backup|restore|logs|uninstall|menu}"
            exit 1
            ;;
    esac
}

main "$@"
