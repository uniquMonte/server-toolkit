#!/bin/bash

#######################################
# Hostname Manager
# Modify system hostname with validation
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

# Get current hostname
get_current_hostname() {
    if command -v hostnamectl &> /dev/null; then
        hostnamectl --static 2>/dev/null || hostname
    else
        hostname
    fi
}

# Show current hostname status
show_status() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Hostname Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local current_hostname=$(get_current_hostname)
    echo -e "Current Hostname: ${CYAN}$current_hostname${NC}"

    # Show FQDN if available
    if command -v hostname &> /dev/null; then
        local fqdn=$(hostname -f 2>/dev/null)
        if [ -n "$fqdn" ] && [ "$fqdn" != "$current_hostname" ]; then
            echo -e "FQDN            : ${CYAN}$fqdn${NC}"
        fi
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Validate hostname format
validate_hostname() {
    local hostname="$1"

    # Check if empty
    if [ -z "$hostname" ]; then
        log_error "Hostname cannot be empty"
        return 1
    fi

    # Check length (max 63 characters)
    if [ ${#hostname} -gt 63 ]; then
        log_error "Hostname too long (max 63 characters)"
        return 1
    fi

    # Check format: alphanumeric and hyphens only, cannot start/end with hyphen
    if ! echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
        log_error "Invalid hostname format"
        log_info "Hostname must:"
        echo "  - Start and end with alphanumeric character"
        echo "  - Contain only letters, numbers, and hyphens"
        echo "  - Not contain spaces or special characters"
        return 1
    fi

    return 0
}

# Set new hostname
set_hostname() {
    local new_hostname="$1"
    local current_hostname=$(get_current_hostname)

    log_info "Setting hostname to: $new_hostname"
    echo ""

    # Check if already set
    if [ "$current_hostname" = "$new_hostname" ]; then
        log_success "Hostname is already set to $new_hostname"
        return 0
    fi

    log_info "Current hostname: $current_hostname"
    log_info "New hostname: $new_hostname"
    echo ""

    # Set hostname using hostnamectl if available
    if command -v hostnamectl &> /dev/null; then
        if hostnamectl set-hostname "$new_hostname" 2>/dev/null; then
            log_success "Hostname set using hostnamectl"
        else
            log_error "Failed to set hostname using hostnamectl"
            return 1
        fi
    else
        # Fallback method
        log_info "Using traditional method to set hostname..."

        # Set hostname immediately
        hostname "$new_hostname" 2>/dev/null

        # Update /etc/hostname
        echo "$new_hostname" > /etc/hostname

        log_success "Hostname set using traditional method"
    fi

    # Update /etc/hosts
    log_info "Updating /etc/hosts..."

    # Backup /etc/hosts
    cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d_%H%M%S)

    # Replace old hostname with new hostname in /etc/hosts
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
    else
        # Add entry if not exists
        echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
    fi

    # Ensure localhost entries exist
    if ! grep -q "127.0.0.1" /etc/hosts; then
        sed -i "1i127.0.0.1\tlocalhost" /etc/hosts
    fi

    log_success "/etc/hosts updated"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Hostname Changed Successfully!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Configuration:${NC}"
    echo -e "  Old Hostname: ${YELLOW}$current_hostname${NC}"
    echo -e "  New Hostname: ${GREEN}$new_hostname${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_success "Hostname change complete!"
    log_info "To see the change in your prompt, please reconnect your SSH session"
}

# Interactive hostname change
change_hostname_interactive() {
    show_status

    echo ""
    log_info "Enter new hostname (or press Ctrl+C to cancel)"
    echo ""

    while true; do
        read -p "New hostname: " new_hostname

        # Validate hostname
        if validate_hostname "$new_hostname"; then
            echo ""
            # Confirm with user
            read -p "Change hostname to '$new_hostname'? [Y/n, or press Enter to confirm]: " confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                set_hostname "$new_hostname"
                return 0
            else
                log_info "Hostname change cancelled"
                return 1
            fi
        else
            echo ""
            log_warning "Please try again with a valid hostname"
            echo ""
        fi
    done
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script with root privileges"
        exit 1
    fi

    case "${1:-interactive}" in
        status)
            show_status
            ;;
        set)
            if [ -z "$2" ]; then
                log_error "Please provide a hostname"
                echo "Usage: $0 set <hostname>"
                exit 1
            fi
            if validate_hostname "$2"; then
                set_hostname "$2"
            else
                exit 1
            fi
            ;;
        interactive)
            change_hostname_interactive
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|set <hostname>|interactive}"
            exit 1
            ;;
    esac
}

main "$@"
