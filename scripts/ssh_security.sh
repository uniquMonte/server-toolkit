#!/bin/bash

#######################################
# SSH Security Configuration Script
# Configure SSH key login, disable password login, etc.
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Display SSH security introduction
show_ssh_security_info() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║              SSH Security Configuration Tool              ║${NC}"
    echo -e "${CYAN}║              SSH Security Configuration                   ║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Security Measures:${NC}"
    echo -e "  🔑 ${GREEN}Key Login${NC}      : Use SSH key pairs for authentication"
    echo -e "  🚫 ${GREEN}Disable Password${NC}: Disable password login for root account"
    echo -e "  🔢 ${GREEN}Change Port${NC}     : Change default SSH port (22)"
    echo -e "  ⏱️  ${GREEN}Timeout Settings${NC}: Configure connection timeout"
    echo ""
    echo -e "${YELLOW}⚠️  Important Notes:${NC}"
    echo -e "  1. Ensure you have alternative login methods (like console) before configuration"
    echo -e "  2. Original configuration files will be automatically backed up"
    echo -e "  3. Test new connection before disconnecting current session"
    echo -e "  4. If configuration errors prevent login, recover via VPS console"
    echo ""
}

# Backup SSH configuration
backup_ssh_config() {
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Backing up SSH configuration to: ${backup_file}"
    cp /etc/ssh/sshd_config "$backup_file"
    log_success "Configuration file backed up"
}

# Configure SSH key login
setup_ssh_key() {
    show_ssh_security_info

    log_info "Configuring SSH key login..."

    # Ask for username
    read -p "Enter username for key configuration (default: root): " username
    username=${username:-root}

    # Determine user home directory
    if [ "$username" == "root" ]; then
        user_home="/root"
    else
        user_home="/home/$username"

        # Check if user exists
        if ! id "$username" &>/dev/null; then
            log_error "User $username does not exist"
            read -p "Create this user? (y/N): " create_user
            if [[ $create_user =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$username"
                passwd "$username"
                log_success "User $username has been created"
            else
                return
            fi
        fi
    fi

    # Create .ssh directory
    ssh_dir="${user_home}/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # Check for existing authorized_keys
    authorized_keys="${ssh_dir}/authorized_keys"

    if [ -f "$authorized_keys" ] && [ -s "$authorized_keys" ]; then
        log_warning "Existing SSH keys detected"
        cat "$authorized_keys"
        echo ""
        read -p "Add new key? (y/N): " add_new
        if [[ ! $add_new =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    echo ""
    log_info "Please select key configuration method:"
    echo "1. Paste existing public key"
    echo "2. Generate new key pair"
    echo "3. Import public key from file"
    read -p "Please select [1-3]: " key_method

    case $key_method in
        1)
            # Paste public key
            echo ""
            log_info "Please paste your SSH public key (usually in local ~/.ssh/id_rsa.pub file):"
            read -p "Public key content: " pub_key

            if [ -z "$pub_key" ]; then
                log_error "Public key cannot be empty"
                return
            fi

            echo "$pub_key" >> "$authorized_keys"
            log_success "Public key added"
            ;;

        2)
            # Generate new key pair
            log_warning "Note: This will generate a key pair on the server, private key needs to be downloaded locally"
            read -p "Confirm to generate new key pair? (y/N): " confirm

            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                return
            fi

            key_file="${ssh_dir}/id_rsa_${username}_$(date +%Y%m%d)"
            ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "${username}@$(hostname)"

            cat "${key_file}.pub" >> "$authorized_keys"

            echo ""
            log_success "Key pair generated"
            log_warning "Private key location: ${key_file}"
            log_warning "Please download the private key locally immediately and delete the server copy!"
            echo ""
            log_info "Private key content (please copy and save):"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            cat "$key_file"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            read -p "Private key saved? (y/N): " saved
            if [[ $saved =~ ^[Yy]$ ]]; then
                rm -f "$key_file"
                log_success "Server private key deleted"
            fi
            ;;

        3)
            # Import from file
            read -p "Enter full path to public key file: " key_file_path

            if [ ! -f "$key_file_path" ]; then
                log_error "File does not exist: $key_file_path"
                return
            fi

            cat "$key_file_path" >> "$authorized_keys"
            log_success "Public key imported from file"
            ;;

        *)
            log_error "Invalid selection"
            return
            ;;
    esac

    # Set correct permissions
    chmod 600 "$authorized_keys"
    chown -R ${username}:${username} "$ssh_dir"

    log_success "SSH key configuration complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Test SSH connection with new key"
    echo "  2. After confirming normal login, disable password login"
}

# Disable root password login
disable_password_login() {
    show_ssh_security_info

    log_warning "Preparing to disable root password login..."
    echo ""
    log_warning "⚠️  Please confirm:"
    echo "  1. SSH key login has been configured"
    echo "  2. Key login has been tested and works normally"
    echo "  3. Alternative access methods (like VPS console) are available"
    echo ""
    read -p "Confirm all conditions above are met? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Operation cancelled"
        return
    fi

    # Backup configuration
    backup_ssh_config

    # Modify configuration
    log_info "Modifying SSH configuration..."

    # Disable password authentication
    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi

    # Disable root password login (but allow key login)
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
    fi

    # Disable empty passwords
    if grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config; then
        sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    else
        echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
    fi

    # Enable public key authentication
    if grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi

    # Test configuration
    log_info "Testing SSH configuration..."
    if sshd -t; then
        log_success "Configuration file syntax correct"

        # Restart SSH service
        log_info "Restarting SSH service..."
        systemctl restart sshd

        log_success "SSH password login disabled!"
        echo ""
        log_warning "Important reminders:"
        echo "  1. Current SSH connection will not be disconnected"
        echo "  2. Test key login in a new terminal"
        echo "  3. Confirm normal login before closing current connection"
        echo "  4. If unable to login, recover via VPS console"
    else
        log_error "Configuration file has errors, changes not applied"
        log_info "Restoring backup..."
        cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
    fi
}

# Change SSH port
change_ssh_port() {
    show_ssh_security_info

    current_port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    if [ -z "$current_port" ]; then
        current_port="22"
    fi

    log_info "Current SSH port: ${current_port}"
    echo ""
    read -p "Enter new SSH port (1024-65535): " new_port

    # Validate port number
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        log_error "Invalid port number"
        return
    fi

    # Check if port is in use
    if netstat -tuln 2>/dev/null | grep -q ":${new_port} " || ss -tuln 2>/dev/null | grep -q ":${new_port} "; then
        log_error "Port ${new_port} is already in use"
        return
    fi

    # Backup configuration
    backup_ssh_config

    # Change port
    log_info "Changing SSH port to: ${new_port}"

    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port ${new_port}/" /etc/ssh/sshd_config
    else
        sed -i "1i Port ${new_port}" /etc/ssh/sshd_config
    fi

    # Test configuration
    if sshd -t; then
        log_success "Configuration file syntax correct"

        # Remind to update firewall
        log_warning "Note: Need to open new port ${new_port} in firewall"

        if command -v ufw &> /dev/null; then
            read -p "Automatically open new port in UFW? (Y/n): " open_port
            if [[ ! $open_port =~ ^[Nn]$ ]]; then
                ufw allow ${new_port}/tcp comment 'SSH'
                log_success "UFW has opened port ${new_port}"
            fi
        fi

        # Restart SSH service
        log_info "Restarting SSH service..."
        systemctl restart sshd

        log_success "SSH port changed to ${new_port}!"
        echo ""
        log_warning "For next connection use:"
        echo "  ssh -p ${new_port} user@server"
    else
        log_error "Configuration file has errors, changes not applied"
    fi
}

# Configure SSH timeout
configure_timeout() {
    log_info "Configuring SSH timeout..."

    read -p "Client alive interval in seconds (default: 60): " client_alive_interval
    client_alive_interval=${client_alive_interval:-60}

    read -p "Maximum alive count (default: 3): " client_alive_count
    client_alive_count=${client_alive_count:-3}

    # Backup configuration
    backup_ssh_config

    # Modify configuration
    if grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
        sed -i "s/^ClientAliveInterval.*/ClientAliveInterval ${client_alive_interval}/" /etc/ssh/sshd_config
    else
        echo "ClientAliveInterval ${client_alive_interval}" >> /etc/ssh/sshd_config
    fi

    if grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
        sed -i "s/^ClientAliveCountMax.*/ClientAliveCountMax ${client_alive_count}/" /etc/ssh/sshd_config
    else
        echo "ClientAliveCountMax ${client_alive_count}" >> /etc/ssh/sshd_config
    fi

    # Restart SSH
    systemctl restart sshd

    log_success "SSH timeout configuration updated"
    log_info "Connection will disconnect after $((client_alive_interval * client_alive_count)) seconds of no response"
}

# Full security configuration
full_security_setup() {
    show_ssh_security_info

    log_info "Starting full SSH security configuration..."
    echo ""

    # 1. Configure SSH key
    log_info "Step 1/4: Configure SSH key login"
    setup_ssh_key

    echo ""
    read -p "Press Enter to continue to next step..."

    # 2. Change SSH port
    log_info "Step 2/4: Change SSH port"
    read -p "Change SSH port? (Y/n): " change_port
    if [[ ! $change_port =~ ^[Nn]$ ]]; then
        change_ssh_port
    fi

    echo ""
    read -p "Press Enter to continue to next step..."

    # 3. Configure timeout
    log_info "Step 3/4: Configure connection timeout"
    read -p "Configure SSH timeout? (Y/n): " config_timeout
    if [[ ! $config_timeout =~ ^[Nn]$ ]]; then
        configure_timeout
    fi

    echo ""
    read -p "Press Enter to continue to final step..."

    # 4. Disable password login
    log_info "Step 4/4: Disable password login"
    read -p "Disable root password login? (y/N): " disable_pwd
    if [[ $disable_pwd =~ ^[Yy]$ ]]; then
        disable_password_login
    fi

    echo ""
    log_success "SSH security configuration complete!"
}

# Display current SSH configuration
show_current_config() {
    echo ""
    log_info "Current SSH configuration:"
    echo ""

    port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$port" ] && port="22"
    echo -e "  Port: ${GREEN}${port}${NC}"

    password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$password_auth" ] && password_auth="yes"
    echo -e "  Password Authentication: ${GREEN}${password_auth}${NC}"

    pubkey_auth=$(grep "^PubkeyAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$pubkey_auth" ] && pubkey_auth="yes"
    echo -e "  Public Key Authentication: ${GREEN}${pubkey_auth}${NC}"

    root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$root_login" ] && root_login="yes"
    echo -e "  Root Login: ${GREEN}${root_login}${NC}"

    echo ""
}

# Display help
show_help() {
    echo "Usage: $0 {setup-key|disable-password|change-port|timeout|full|show}"
    echo ""
    echo "Commands:"
    echo "  setup-key         - Configure SSH key login"
    echo "  disable-password  - Disable root password login"
    echo "  change-port       - Change SSH port"
    echo "  timeout           - Configure connection timeout"
    echo "  full              - Full security configuration (recommended)"
    echo "  show              - Display current configuration"
    echo ""
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "$1" in
        setup-key)
            setup_ssh_key
            ;;
        disable-password)
            disable_password_login
            ;;
        change-port)
            change_ssh_port
            ;;
        timeout)
            configure_timeout
            ;;
        full)
            full_security_setup
            ;;
        show)
            show_current_config
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
