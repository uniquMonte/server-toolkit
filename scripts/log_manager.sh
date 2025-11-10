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

# Get current Docker log configuration
get_current_docker_config() {
    if [ ! -f /etc/docker/daemon.json ]; then
        echo "not_configured|||"
        return
    fi

    local max_size=$(grep -o '"max-size"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/docker/daemon.json 2>/dev/null | cut -d'"' -f4)
    local max_file=$(grep -o '"max-file"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/docker/daemon.json 2>/dev/null | cut -d'"' -f4)

    if [ -z "$max_size" ] && [ -z "$max_file" ]; then
        echo "not_configured|||"
    else
        echo "configured|${max_size:-unlimited}|${max_file:-unlimited}"
    fi
}

# Get current journald configuration
get_current_journald_config() {
    local max_use=$(grep "^SystemMaxUse=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)
    local keep_free=$(grep "^SystemKeepFree=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)
    local max_file_size=$(grep "^SystemMaxFileSize=" /etc/systemd/journald.conf 2>/dev/null | cut -d'=' -f2)

    if [ -z "$max_use" ] && [ -z "$keep_free" ] && [ -z "$max_file_size" ]; then
        echo "not_configured|||"
    else
        echo "configured|${max_use:-default}|${keep_free:-default}|${max_file_size:-default}"
    fi
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

    local docker_config=$(get_current_docker_config)
    local status=$(echo "$docker_config" | cut -d'|' -f1)
    local max_size=$(echo "$docker_config" | cut -d'|' -f2)
    local max_file=$(echo "$docker_config" | cut -d'|' -f3)

    if [ "$status" = "not_configured" ]; then
        echo -e "Status: ${YELLOW}Not Configured${NC}"
        echo -e "        ${YELLOW}Using Docker default (no log rotation)${NC}"
        echo -e "        ${RED}⚠ Logs will grow indefinitely!${NC}"
    else
        echo -e "Status: ${GREEN}Configured${NC}"
        echo -e "Max Size per File: ${CYAN}$max_size${NC}"
        echo -e "Max Files        : ${CYAN}$max_file${NC}"
    fi

    # Show current Docker log disk usage
    if [ -d /var/lib/docker/containers ]; then
        local docker_log_size=$(du -sh /var/lib/docker/containers 2>/dev/null | cut -f1)
        [ -n "$docker_log_size" ] && echo -e "Current Log Size : ${CYAN}$docker_log_size${NC}"
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Show current journald log configuration
show_journald_config() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}System Journal (journald) Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local journald_config=$(get_current_journald_config)
    local status=$(echo "$journald_config" | cut -d'|' -f1)
    local max_use=$(echo "$journald_config" | cut -d'|' -f2)
    local keep_free=$(echo "$journald_config" | cut -d'|' -f3)
    local max_file_size=$(echo "$journald_config" | cut -d'|' -f4)

    if [ "$status" = "not_configured" ]; then
        echo -e "Status: ${YELLOW}Not Configured${NC}"
        echo -e "Max Disk Usage  : ${YELLOW}Default (10% of disk)${NC}"
        echo -e "Keep Free       : ${YELLOW}Default (15% of disk)${NC}"
        echo -e "Max File Size   : ${YELLOW}Default${NC}"
    else
        echo -e "Status: ${GREEN}Configured${NC}"
        echo -e "Max Disk Usage  : ${CYAN}$max_use${NC}"
        echo -e "Keep Free       : ${CYAN}$keep_free${NC}"
        echo -e "Max File Size   : ${CYAN}$max_file_size${NC}"
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

# Show comparison: current vs recommended
show_comparison() {
    local available_gb=$(get_disk_space)
    local total_gb=$(get_total_disk_space)
    local params=$(calculate_log_params "$available_gb")
    local mode=$(echo "$params" | cut -d'|' -f1)

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         ${YELLOW}Current vs Recommended Configuration${NC}           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show recommendation basis
    echo -e "${BLUE}📊 Analysis Basis:${NC}"
    echo -e "   Total Disk Space    : ${CYAN}${total_gb}GB${NC}"
    echo -e "   Available Space     : ${GREEN}${available_gb}GB${NC}"

    # Show mode explanation
    case $mode in
        strict)
            echo -e "   Recommendation Mode : ${RED}Strict${NC}"
            echo -e "   ${YELLOW}⚠ Very low space detected! Aggressive log rotation recommended.${NC}"
            ;;
        normal)
            echo -e "   Recommendation Mode : ${YELLOW}Normal${NC}"
            echo -e "   ${YELLOW}→ Limited space. Balanced log retention recommended.${NC}"
            ;;
        relaxed)
            echo -e "   Recommendation Mode : ${GREEN}Relaxed${NC}"
            echo -e "   ${GREEN}→ Sufficient space. Keep more logs for debugging.${NC}"
            ;;
        ample)
            echo -e "   Recommendation Mode : ${CYAN}Ample${NC}"
            echo -e "   ${CYAN}→ Plenty of space. Extended log retention available.${NC}"
            ;;
    esac

    # Docker comparison
    if command -v docker &> /dev/null; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}🐳 Docker Log Settings${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        local docker_config=$(get_current_docker_config)
        local current_status=$(echo "$docker_config" | cut -d'|' -f1)
        local current_max_size=$(echo "$docker_config" | cut -d'|' -f2)
        local current_max_file=$(echo "$docker_config" | cut -d'|' -f3)

        local rec_max_size=$(echo "$params" | cut -d'|' -f2)
        local rec_max_file=$(echo "$params" | cut -d'|' -f3)

        if [ "$current_status" = "not_configured" ]; then
            echo -e "${YELLOW}Current Configuration:${NC}"
            echo -e "  Status: ${RED}Not configured (logs grow indefinitely!)${NC}"
            echo -e "  Risk  : ${RED}May fill up disk space${NC}"
        else
            echo -e "${YELLOW}Current Configuration:${NC}"
            echo -e "  Max Size per File: ${current_max_size}"
            echo -e "  Max Files        : ${current_max_file}"
            echo -e "  Total per Container: ~$((${current_max_size//[!0-9]/} * ${current_max_file//[!0-9]/}))MB"
        fi

        echo ""
        echo -e "${GREEN}Recommended Configuration:${NC}"
        echo -e "  Max Size per File: ${CYAN}${rec_max_size}${NC}"
        echo -e "  Max Files        : ${CYAN}${rec_max_file}${NC}"
        echo -e "  Total per Container: ${CYAN}~$((${rec_max_size//[!0-9]/} * ${rec_max_file//[!0-9]/}))MB${NC}"
        echo -e "  ${BLUE}→ Each container will keep up to ${rec_max_file} log files${NC}"
    else
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}🐳 Docker Log Settings${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Docker is not installed - will skip Docker configuration${NC}"
    fi

    # Journald comparison
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 System Journal (journald) Settings${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local journald_config=$(get_current_journald_config)
    local current_status=$(echo "$journald_config" | cut -d'|' -f1)
    local current_max_use=$(echo "$journald_config" | cut -d'|' -f2)
    local current_keep_free=$(echo "$journald_config" | cut -d'|' -f3)
    local current_max_file_size=$(echo "$journald_config" | cut -d'|' -f4)

    local rec_max_use=$(echo "$params" | cut -d'|' -f4)
    local rec_keep_free=$(echo "$params" | cut -d'|' -f5)
    local rec_max_file_size=$(echo "$params" | cut -d'|' -f6)

    if [ "$current_status" = "not_configured" ]; then
        echo -e "${YELLOW}Current Configuration:${NC}"
        echo -e "  Status: ${YELLOW}Using system defaults${NC}"
        echo -e "  Max Disk Usage  : ${YELLOW}~10% of disk (~$((total_gb / 10))GB)${NC}"
        echo -e "  Keep Free       : ${YELLOW}~15% of disk (~$((total_gb * 15 / 100))GB)${NC}"
    else
        echo -e "${YELLOW}Current Configuration:${NC}"
        echo -e "  Max Disk Usage  : ${current_max_use}"
        echo -e "  Keep Free       : ${current_keep_free}"
        echo -e "  Max File Size   : ${current_max_file_size}"
    fi

    echo ""
    echo -e "${GREEN}Recommended Configuration:${NC}"
    echo -e "  Max Disk Usage  : ${CYAN}${rec_max_use}${NC}"
    echo -e "  Keep Free       : ${CYAN}${rec_keep_free}${NC}"
    echo -e "  Max File Size   : ${CYAN}${rec_max_file_size}${NC}"
    echo -e "  ${BLUE}→ System logs limited to ${rec_max_use}, ensuring ${rec_keep_free} always free${NC}"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}💡 Why these recommendations?${NC}"
    case $mode in
        strict)
            echo -e "   ${YELLOW}With only ${available_gb}GB available, aggressive rotation prevents disk full.${NC}"
            ;;
        normal)
            echo -e "   ${YELLOW}With ${available_gb}GB available, balanced settings prevent space issues.${NC}"
            ;;
        relaxed)
            echo -e "   ${GREEN}With ${available_gb}GB available, you can keep more logs for debugging.${NC}"
            ;;
        ample)
            echo -e "   ${CYAN}With ${available_gb}GB available, extended retention helps with analysis.${NC}"
            ;;
    esac
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Configure Docker log rotation
configure_docker_logs() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed, skipping Docker log configuration"
        echo ""
        log_info "Install Docker first using menu option 5 (Docker management)"
        return 0
    fi

    log_info "Checking Docker log configuration..."
    echo ""

    # Show current vs recommended
    local available_gb=$(get_disk_space)
    local params=$(calculate_log_params "$available_gb")
    local docker_config=$(get_current_docker_config)
    local current_status=$(echo "$docker_config" | cut -d'|' -f1)
    local current_max_size=$(echo "$docker_config" | cut -d'|' -f2)
    local current_max_file=$(echo "$docker_config" | cut -d'|' -f3)
    local rec_max_size=$(echo "$params" | cut -d'|' -f2)
    local rec_max_file=$(echo "$params" | cut -d'|' -f3)

    echo -e "${CYAN}━━━ Docker Log Configuration ━━━${NC}"
    if [ "$current_status" = "not_configured" ]; then
        echo -e "${YELLOW}Current Status:${NC} Not configured ${RED}(logs will grow indefinitely!)${NC}"
    else
        echo -e "${YELLOW}Current Status:${NC} Configured"
        echo -e "  Max Size: ${CYAN}$current_max_size${NC}, Max Files: ${CYAN}$current_max_file${NC}"
    fi
    echo ""
    echo -e "${GREEN}Recommended:${NC}"
    echo -e "  Max Size: ${CYAN}$rec_max_size${NC}, Max Files: ${CYAN}$rec_max_file${NC}"
    echo -e "  (Based on ${available_gb}GB available space)"
    echo ""

    # Check if already optimally configured
    if [ "$current_max_size" = "$rec_max_size" ] && [ "$current_max_file" = "$rec_max_file" ]; then
        log_success "Docker logs are already optimally configured!"
        return 0
    fi

    # Ask for confirmation
    read -p "Apply recommended Docker log configuration? (Y/n) (press Enter to confirm): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Docker log configuration cancelled"
        return 0
    fi

    echo ""
    log_info "Applying Docker log configuration..."

    # Create /etc/docker directory if it doesn't exist
    mkdir -p /etc/docker

    # Backup existing config if it exists
    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)
        log_info "Backed up existing configuration"
    fi

    # Create or update daemon.json
    if [ -f /etc/docker/daemon.json ] && [ -s /etc/docker/daemon.json ]; then
        # File exists and is not empty, try to merge settings
        if command -v jq &> /dev/null; then
            local temp_file=$(mktemp)
            jq --arg maxsize "$rec_max_size" --arg maxfile "$rec_max_file" \
                '. + {"log-driver": "json-file", "log-opts": {"max-size": $maxsize, "max-file": $maxfile}}' \
                /etc/docker/daemon.json > "$temp_file" && mv "$temp_file" /etc/docker/daemon.json
            log_info "Merged with existing configuration using jq"
        else
            # Simple recreation (may lose other settings)
            log_warning "jq not found, recreating config file"
            cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$rec_max_size",
    "max-file": "$rec_max_file"
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
    "max-size": "$rec_max_size",
    "max-file": "$rec_max_file"
  }
}
EOF
    fi

    log_success "Docker log configuration updated"
    echo ""

    # Restart Docker to apply changes
    log_info "Restarting Docker service to apply changes..."
    if systemctl restart docker 2>/dev/null; then
        log_success "Docker service restarted successfully"
        log_info "New log rotation settings are now active"
    else
        log_warning "Failed to restart Docker automatically"
        log_info "Please restart manually: systemctl restart docker"
    fi
}

# Configure journald log rotation
configure_journald_logs() {
    log_info "Checking system journal configuration..."
    echo ""

    # Show current vs recommended
    local available_gb=$(get_disk_space)
    local params=$(calculate_log_params "$available_gb")
    local journald_config=$(get_current_journald_config)
    local current_status=$(echo "$journald_config" | cut -d'|' -f1)
    local current_max_use=$(echo "$journald_config" | cut -d'|' -f2)
    local current_keep_free=$(echo "$journald_config" | cut -d'|' -f3)
    local current_max_file_size=$(echo "$journald_config" | cut -d'|' -f4)
    local rec_max_use=$(echo "$params" | cut -d'|' -f4)
    local rec_keep_free=$(echo "$params" | cut -d'|' -f5)
    local rec_max_file_size=$(echo "$params" | cut -d'|' -f6)

    echo -e "${CYAN}━━━ System Journal Configuration ━━━${NC}"
    if [ "$current_status" = "not_configured" ]; then
        echo -e "${YELLOW}Current Status:${NC} Using system defaults"
        echo -e "  (Typically 10% of disk for logs)"
    else
        echo -e "${YELLOW}Current Status:${NC} Configured"
        echo -e "  MaxUse: ${CYAN}$current_max_use${NC}, KeepFree: ${CYAN}$current_keep_free${NC}, MaxFileSize: ${CYAN}$current_max_file_size${NC}"
    fi
    echo ""
    echo -e "${GREEN}Recommended:${NC}"
    echo -e "  MaxUse: ${CYAN}$rec_max_use${NC}, KeepFree: ${CYAN}$rec_keep_free${NC}, MaxFileSize: ${CYAN}$rec_max_file_size${NC}"
    echo -e "  (Based on ${available_gb}GB available space)"
    echo ""

    # Check if already optimally configured
    if [ "$current_max_use" = "$rec_max_use" ] && [ "$current_keep_free" = "$rec_keep_free" ] && [ "$current_max_file_size" = "$rec_max_file_size" ]; then
        log_success "System journal is already optimally configured!"
        return 0
    fi

    # Ask for confirmation
    read -p "Apply recommended journal configuration? (Y/n) (press Enter to confirm): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Journal configuration cancelled"
        return 0
    fi

    echo ""
    log_info "Applying system journal configuration..."

    # Backup existing config
    if [ -f /etc/systemd/journald.conf ]; then
        cp /etc/systemd/journald.conf /etc/systemd/journald.conf.bak.$(date +%Y%m%d_%H%M%S)
        log_info "Backed up existing configuration"
    fi

    # Update journald configuration
    local config_file="/etc/systemd/journald.conf"

    # Remove existing settings if present
    sed -i '/^SystemMaxUse=/d' "$config_file" 2>/dev/null
    sed -i '/^SystemKeepFree=/d' "$config_file" 2>/dev/null
    sed -i '/^SystemMaxFileSize=/d' "$config_file" 2>/dev/null

    # Add new settings under [Journal] section
    if grep -q "^\[Journal\]" "$config_file"; then
        sed -i "/^\[Journal\]/a SystemMaxUse=$rec_max_use\nSystemKeepFree=$rec_keep_free\nSystemMaxFileSize=$rec_max_file_size" "$config_file"
    else
        # Add [Journal] section if not exists
        cat >> "$config_file" <<EOF

[Journal]
SystemMaxUse=$rec_max_use
SystemKeepFree=$rec_keep_free
SystemMaxFileSize=$rec_max_file_size
EOF
    fi

    log_success "Journal configuration updated"
    echo ""

    # Restart journald to apply changes
    log_info "Restarting systemd-journald service to apply changes..."
    if systemctl restart systemd-journald 2>/dev/null; then
        log_success "systemd-journald service restarted successfully"
        log_info "New journal settings are now active"
    else
        log_warning "Failed to restart journald automatically"
        log_info "Please restart manually: systemctl restart systemd-journald"
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
    else
        log_info "Docker not installed, skipping Docker log cleanup"
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
    log_info "Intelligent log management configuration"
    echo ""

    # Show current status
    show_disk_status

    # Show comparison
    show_comparison

    echo ""
    log_info "This will configure both Docker and system journal logs"
    read -p "Proceed with configuration? (Y/n) (press Enter to confirm): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Configuration cancelled"
        return 0
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Configure Docker logs (with internal confirmation)
    if command -v docker &> /dev/null; then
        echo ""
        configure_docker_logs
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi

    # Configure journald logs (with internal confirmation)
    echo ""
    configure_journald_logs

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log_success "Log management configuration completed!"
    log_info "Your system logs are now optimized for ${available_gb}GB available space"
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
