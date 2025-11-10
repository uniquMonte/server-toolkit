#!/bin/bash

#######################################
# Log Management Script
# Intelligently manages system and Docker logs based on available disk space
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

# Get disk space information (in GB)
get_disk_space() {
    local available_kb=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    echo "$available_gb"
}

# Get total disk space (in GB)
get_total_disk_space() {
    local total_kb=$(df / | tail -1 | awk '{print $2}')
    local total_gb=$((total_kb / 1024 / 1024))
    echo "$total_gb"
}

# Get used disk space percentage
get_disk_usage_percent() {
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

# Calculate intelligent log parameters based on available disk space
calculate_log_params() {
    local available_gb=$1
    local mode=""
    local docker_max_size=""
    local docker_max_file=""
    local journald_max_use=""
    local journald_keep_free=""
    local journald_max_file_size=""

    if [ "$available_gb" -lt 5 ]; then
        # Strict mode: < 5GB
        mode="strict"
        docker_max_size="5m"
        docker_max_file="2"
        journald_max_use="100M"
        journald_keep_free="500M"
        journald_max_file_size="10M"
    elif [ "$available_gb" -lt 10 ]; then
        # Normal mode: 5-10GB
        mode="normal"
        docker_max_size="10m"
        docker_max_file="3"
        journald_max_use="200M"
        journald_keep_free="1G"
        journald_max_file_size="20M"
    elif [ "$available_gb" -lt 30 ]; then
        # Relaxed mode: 10-30GB
        mode="relaxed"
        docker_max_size="20m"
        docker_max_file="5"
        journald_max_use="500M"
        journald_keep_free="2G"
        journald_max_file_size="50M"
    else
        # Ample mode: >= 30GB
        mode="ample"
        docker_max_size="50m"
        docker_max_file="10"
        journald_max_use="1G"
        journald_keep_free="3G"
        journald_max_file_size="100M"
    fi

    echo "$mode|$docker_max_size|$docker_max_file|$journald_max_use|$journald_keep_free|$journald_max_file_size"
}

# Show current disk space status
show_disk_status() {
    local available_gb=$(get_disk_space)
    local total_gb=$(get_total_disk_space)
    local used_percent=$(get_disk_usage_percent)
    local used_gb=$((total_gb - available_gb))

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Disk Space Status${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Total Space     : ${CYAN}${total_gb}GB${NC}"
    echo -e "Used Space      : ${YELLOW}${used_gb}GB${NC} (${used_percent}%)"
    echo -e "Available Space : ${GREEN}${available_gb}GB${NC}"

    # Show warning if space is low
    if [ "$available_gb" -lt 5 ]; then
        echo -e "Status          : ${RED}⚠ Critical - Very Low Space${NC}"
    elif [ "$available_gb" -lt 10 ]; then
        echo -e "Status          : ${YELLOW}⚠ Warning - Low Space${NC}"
    elif [ "$available_gb" -lt 30 ]; then
        echo -e "Status          : ${GREEN}✓ Normal${NC}"
    else
        echo -e "Status          : ${GREEN}✓ Ample Space${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show current Docker log configuration
show_docker_log_config() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Docker Log Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker is not installed${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return
    fi

    if [ -f /etc/docker/daemon.json ]; then
        echo -e "Config File: ${GREEN}/etc/docker/daemon.json${NC}"
        echo ""

        # Try to extract log settings
        local max_size=$(grep -o '"max-size"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/docker/daemon.json 2>/dev/null | cut -d'"' -f4)
        local max_file=$(grep -o '"max-file"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/docker/daemon.json 2>/dev/null | cut -d'"' -f4)

        if [ -n "$max_size" ] || [ -n "$max_file" ]; then
            [ -n "$max_size" ] && echo -e "Max Size per File: ${CYAN}$max_size${NC}" || echo -e "Max Size per File: ${YELLOW}Not configured${NC}"
            [ -n "$max_file" ] && echo -e "Max Files        : ${CYAN}$max_file${NC}" || echo -e "Max Files        : ${YELLOW}Not configured${NC}"
        else
            echo -e "${YELLOW}No log rotation configured${NC}"
        fi
    else
        echo -e "Config File: ${YELLOW}Not found${NC}"
        echo -e "${YELLOW}Using Docker default settings (no rotation)${NC}"
    fi

    # Show current Docker log disk usage
    if [ -d /var/lib/docker/containers ]; then
        local docker_log_size=$(du -sh /var/lib/docker/containers 2>/dev/null | cut -f1)
        [ -n "$docker_log_size" ] && echo -e "Current Log Size: ${CYAN}$docker_log_size${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show current journald log configuration
show_journald_config() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}System Journal (journald) Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ -f /etc/systemd/journald.conf ]; then
        local max_use=$(grep "^SystemMaxUse=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)
        local keep_free=$(grep "^SystemKeepFree=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)
        local max_file_size=$(grep "^SystemMaxFileSize=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)

        [ -n "$max_use" ] && echo -e "Max Disk Usage  : ${CYAN}$max_use${NC}" || echo -e "Max Disk Usage  : ${YELLOW}Default (10% of disk)${NC}"
        [ -n "$keep_free" ] && echo -e "Keep Free       : ${CYAN}$keep_free${NC}" || echo -e "Keep Free       : ${YELLOW}Default (15% of disk)${NC}"
        [ -n "$max_file_size" ] && echo -e "Max File Size   : ${CYAN}$max_file_size${NC}" || echo -e "Max File Size   : ${YELLOW}Default${NC}"
    else
        echo -e "${YELLOW}Using system defaults${NC}"
    fi

    # Show current journal disk usage
    if command -v journalctl &> /dev/null; then
        local journal_size=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[MGT]' | head -n1)
        [ -n "$journal_size" ] && echo -e "Current Usage   : ${CYAN}$journal_size${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show recommended configuration
show_recommended_config() {
    local available_gb=$(get_disk_space)
    local params=$(calculate_log_params "$available_gb")

    local mode=$(echo "$params" | cut -d'|' -f1)
    local docker_max_size=$(echo "$params" | cut -d'|' -f2)
    local docker_max_file=$(echo "$params" | cut -d'|' -f3)
    local journald_max_use=$(echo "$params" | cut -d'|' -f4)
    local journald_keep_free=$(echo "$params" | cut -d'|' -f5)
    local journald_max_file_size=$(echo "$params" | cut -d'|' -f6)

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Recommended Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Show mode with description
    case $mode in
        strict)
            echo -e "Mode: ${RED}Strict${NC} (Available: ${available_gb}GB)"
            echo -e "      ${YELLOW}Aggressive log rotation to preserve disk space${NC}"
            ;;
        normal)
            echo -e "Mode: ${YELLOW}Normal${NC} (Available: ${available_gb}GB)"
            echo -e "      ${YELLOW}Balanced log retention${NC}"
            ;;
        relaxed)
            echo -e "Mode: ${GREEN}Relaxed${NC} (Available: ${available_gb}GB)"
            echo -e "      ${GREEN}Keep more logs for debugging${NC}"
            ;;
        ample)
            echo -e "Mode: ${CYAN}Ample${NC} (Available: ${available_gb}GB)"
            echo -e "      ${CYAN}Extended log retention${NC}"
            ;;
    esac

    echo ""
    echo -e "${YELLOW}Docker Log Settings:${NC}"
    echo -e "  Max Size per File: ${CYAN}$docker_max_size${NC}"
    echo -e "  Max Files        : ${CYAN}$docker_max_file${NC}"
    echo -e "  Total per Container: ${CYAN}~$(echo "$docker_max_size" | sed 's/m/*/')$docker_max_file MB${NC}"

    echo ""
    echo -e "${YELLOW}System Journal Settings:${NC}"
    echo -e "  Max Disk Usage  : ${CYAN}$journald_max_use${NC}"
    echo -e "  Keep Free       : ${CYAN}$journald_keep_free${NC}"
    echo -e "  Max File Size   : ${CYAN}$journald_max_file_size${NC}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Configure Docker log rotation
configure_docker_logs() {
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed, skipping Docker log configuration"
        return 0
    fi

    log_info "Configuring Docker log rotation..."
    echo ""

    local available_gb=$(get_disk_space)
    local params=$(calculate_log_params "$available_gb")
    local docker_max_size=$(echo "$params" | cut -d'|' -f2)
    local docker_max_file=$(echo "$params" | cut -d'|' -f3)

    # Create /etc/docker directory if it doesn't exist
    mkdir -p /etc/docker

    # Backup existing config if it exists
    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)
        log_info "Backed up existing Docker configuration"
    fi

    # Create or update daemon.json
    if [ -f /etc/docker/daemon.json ] && [ -s /etc/docker/daemon.json ]; then
        # File exists and is not empty, try to merge settings
        log_info "Updating existing Docker configuration..."

        # Use python or jq if available, otherwise recreate file
        if command -v jq &> /dev/null; then
            local temp_file=$(mktemp)
            jq --arg maxsize "$docker_max_size" --arg maxfile "$docker_max_file" \
                '. + {"log-driver": "json-file", "log-opts": {"max-size": $maxsize, "max-file": $maxfile}}' \
                /etc/docker/daemon.json > "$temp_file" && mv "$temp_file" /etc/docker/daemon.json
        else
            # Simple recreation (may lose other settings)
            log_warning "jq not found, recreating Docker config (existing settings may be lost)"
            cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$docker_max_size",
    "max-file": "$docker_max_file"
  }
}
EOF
        fi
    else
        # Create new file
        cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$docker_max_size",
    "max-file": "$docker_max_file"
  }
}
EOF
    fi

    log_success "Docker log configuration updated"
    echo -e "  Max Size: ${CYAN}$docker_max_size${NC}"
    echo -e "  Max Files: ${CYAN}$docker_max_file${NC}"
    echo ""

    # Restart Docker to apply changes
    log_info "Restarting Docker service..."
    if systemctl restart docker 2>/dev/null; then
        log_success "Docker service restarted successfully"
    else
        log_warning "Failed to restart Docker, please restart manually: systemctl restart docker"
    fi
}

# Configure journald log rotation
configure_journald_logs() {
    log_info "Configuring system journal (journald) log rotation..."
    echo ""

    local available_gb=$(get_disk_space)
    local params=$(calculate_log_params "$available_gb")
    local journald_max_use=$(echo "$params" | cut -d'|' -f4)
    local journald_keep_free=$(echo "$params" | cut -d'|' -f5)
    local journald_max_file_size=$(echo "$params" | cut -d'|' -f6)

    # Backup existing config if it exists
    if [ -f /etc/systemd/journald.conf ]; then
        cp /etc/systemd/journald.conf /etc/systemd/journald.conf.bak.$(date +%Y%m%d_%H%M%S)
        log_info "Backed up existing journald configuration"
    fi

    # Update journald configuration
    local config_file="/etc/systemd/journald.conf"

    # Remove existing settings if present
    sed -i '/^SystemMaxUse=/d' "$config_file" 2>/dev/null
    sed -i '/^SystemKeepFree=/d' "$config_file" 2>/dev/null
    sed -i '/^SystemMaxFileSize=/d' "$config_file" 2>/dev/null

    # Add new settings under [Journal] section
    if grep -q "^\[Journal\]" "$config_file"; then
        sed -i "/^\[Journal\]/a SystemMaxUse=$journald_max_use\nSystemKeepFree=$journald_keep_free\nSystemMaxFileSize=$journald_max_file_size" "$config_file"
    else
        # Add [Journal] section if not exists
        cat >> "$config_file" <<EOF

[Journal]
SystemMaxUse=$journald_max_use
SystemKeepFree=$journald_keep_free
SystemMaxFileSize=$journald_max_file_size
EOF
    fi

    log_success "Journald configuration updated"
    echo -e "  Max Disk Usage: ${CYAN}$journald_max_use${NC}"
    echo -e "  Keep Free: ${CYAN}$journald_keep_free${NC}"
    echo -e "  Max File Size: ${CYAN}$journald_max_file_size${NC}"
    echo ""

    # Restart journald to apply changes
    log_info "Restarting systemd-journald service..."
    if systemctl restart systemd-journald 2>/dev/null; then
        log_success "systemd-journald service restarted successfully"
    else
        log_warning "Failed to restart journald, please restart manually: systemctl restart systemd-journald"
    fi
}

# Clean old logs
clean_old_logs() {
    log_info "Cleaning old logs..."
    echo ""

    local space_before=$(get_disk_space)

    # Clean Docker logs (if Docker is installed)
    if command -v docker &> /dev/null; then
        log_info "Cleaning Docker container logs..."

        # Get Docker log size before cleaning
        if [ -d /var/lib/docker/containers ]; then
            local docker_before=$(du -sm /var/lib/docker/containers 2>/dev/null | cut -f1)

            # Truncate all container logs
            truncate -s 0 /var/lib/docker/containers/*/*-json.log 2>/dev/null

            local docker_after=$(du -sm /var/lib/docker/containers 2>/dev/null | cut -f1)
            local docker_freed=$((docker_before - docker_after))

            if [ "$docker_freed" -gt 0 ]; then
                log_success "Cleaned Docker logs: freed ${docker_freed}MB"
            else
                log_info "Docker logs already clean"
            fi
        fi
    fi

    # Clean journald logs
    if command -v journalctl &> /dev/null; then
        log_info "Cleaning system journal logs..."

        # Vacuum journal to configured size
        journalctl --vacuum-time=7d 2>/dev/null
        journalctl --vacuum-size=500M 2>/dev/null

        log_success "System journal cleaned (kept last 7 days, max 500M)"
    fi

    # Clean old log files in /var/log
    log_info "Cleaning rotated log files in /var/log..."
    find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
    find /var/log -type f -name "*.1" -mtime +7 -delete 2>/dev/null
    log_success "Removed old rotated log files"

    echo ""
    local space_after=$(get_disk_space)
    local space_freed=$((space_after - space_before))

    if [ "$space_freed" -gt 0 ]; then
        log_success "Total space freed: approximately ${space_freed}GB"
    else
        log_info "Log cleanup completed"
    fi
}

# Apply all configurations
configure_all() {
    log_info "Applying intelligent log management configuration..."
    echo ""

    # Show current status
    show_disk_status
    show_recommended_config

    echo ""
    read -p "Apply these configurations? [Y/n, or press Enter to apply]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Configuration cancelled"
        return 0
    fi

    echo ""

    # Configure Docker logs
    configure_docker_logs

    echo ""

    # Configure journald logs
    configure_journald_logs

    echo ""
    log_success "Log management configuration applied successfully!"
    log_info "Logs will now be automatically rotated according to available disk space"
}

# Show status
show_status() {
    show_disk_status
    show_docker_log_config
    show_journald_config
    show_recommended_config
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
        configure)
            configure_all
            ;;
        docker)
            configure_docker_logs
            ;;
        journald)
            configure_journald_logs
            ;;
        clean)
            clean_old_logs
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {status|configure|docker|journald|clean}"
            exit 1
            ;;
    esac
}

main "$@"
