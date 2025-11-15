#!/bin/bash

#######################################
# Lightpath Manager - Xray Reality Protocol Deployment
#
# This script helps deploy and manage Xray with Reality protocol
# Supports both DoH and non-DoH deployment scenarios
#
# Author: Server Toolkit
# Supported: Ubuntu, Debian, CentOS, Rocky Linux, AlmaLinux, Fedora
#######################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration paths
XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json"
LIGHTPATH_CONFIG_DIR="/etc/lightpath"
LIGHTPATH_INFO_FILE="${LIGHTPATH_CONFIG_DIR}/deployment.conf"
CLIENT_CONFIG_DIR="${LIGHTPATH_CONFIG_DIR}/client_configs"

# Destination domain pool (符合 Reality 协议要求的域名)
# 要求: 国外网站, 支持 TLSv1.3 与 H2, 非跳转域名
DEST_DOMAINS=(
    "www.ebay.com"
    "music.apple.com"
    "www.amazon.com"
    "www.microsoft.com"
    "www.apple.com"
    "www.bing.com"
    "www.tesla.com"
    "addons.mozilla.org"
    "www.lovelive-anime.jp"
    "www.swift.org"
    "www.cisco.com"
    "www.amd.com"
)

# Check root permission
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Check if Xray is installed
check_xray_installed() {
    if command -v xray &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if Nginx is installed and running
check_nginx_installed() {
    # Check if nginx command exists
    if ! command -v nginx &> /dev/null; then
        return 1
    fi

    # Check if nginx service is running
    if ! systemctl is-active --quiet nginx; then
        return 2  # Installed but not running
    fi

    return 0  # Installed and running
}

# Check if AdGuardHome is installed and running
check_adguardhome_installed() {
    # Check if AdGuardHome service exists
    if ! systemctl list-unit-files | grep -q "AdGuardHome.service"; then
        return 1
    fi

    # Check if AdGuardHome service is running
    if ! systemctl is-active --quiet AdGuardHome; then
        return 2  # Installed but not running
    fi

    return 0  # Installed and running
}

# Get server public IP
get_server_ip() {
    local ip
    # Try multiple methods to get public IP
    ip=$(curl -s -4 https://api.ipify.org 2>/dev/null) || \
    ip=$(curl -s -4 https://icanhazip.com 2>/dev/null) || \
    ip=$(curl -s -4 https://ifconfig.me 2>/dev/null) || \
    ip=$(hostname -I | awk '{print $1}')

    echo "$ip"
}

# Install Xray
install_xray() {
    log_step "Installing Xray..."

    if check_xray_installed; then
        log_warning "Xray is already installed"
        xray version
        return 0
    fi

    log_info "Downloading and installing Xray from official source..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    if check_xray_installed; then
        log_success "Xray installed successfully"
        xray version

        # Enable and start Xray service
        systemctl enable xray
        log_success "Xray service enabled"
    else
        log_error "Xray installation failed"
        return 1
    fi
}

# Generate UUID
generate_uuid() {
    if check_xray_installed; then
        xray uuid
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

# Generate X25519 key pair
generate_keypair() {
    if check_xray_installed; then
        # Generate keypair using xray x25519
        # Output format:
        #   PrivateKey: xxx (server-side privateKey)
        #   Password: xxx   (client-side publicKey)
        #   Hash32: xxx
        local output=$(xray x25519)
        local private_key=$(echo "$output" | grep "PrivateKey" | awk -F': ' '{print $2}' | tr -d ' \n')
        local public_key=$(echo "$output" | grep "Password" | awk -F': ' '{print $2}' | tr -d ' \n')

        # Output in a consistent format
        echo "Private key: $private_key"
        echo "Public key: $public_key"
    else
        log_error "Xray is not installed, cannot generate keypair"
        return 1
    fi
}

# Get random destination domain
get_random_dest() {
    local random_index=$((RANDOM % ${#DEST_DOMAINS[@]}))
    echo "${DEST_DOMAINS[$random_index]}"
}

# Create configuration directories
create_config_dirs() {
    mkdir -p "$LIGHTPATH_CONFIG_DIR"
    chmod 700 "$LIGHTPATH_CONFIG_DIR"
}

# Save deployment information
save_deployment_info() {
    local deployment_type=$1
    local uuid=$2
    local dest=$3
    local private_key=$4
    local public_key=$5
    local server_ip=$6
    local port=$7

    cat > "$LIGHTPATH_INFO_FILE" <<EOF
# Lightpath Deployment Information
# Generated: $(date)

DEPLOYMENT_TYPE="$deployment_type"
UUID="$uuid"
DEST_DOMAIN="$dest"
PRIVATE_KEY="$private_key"
PUBLIC_KEY="$public_key"
SERVER_IP="$server_ip"
PORT="$port"
EOF

    chmod 600 "$LIGHTPATH_INFO_FILE"
    log_success "Deployment information saved to $LIGHTPATH_INFO_FILE"
}

# Load deployment information
load_deployment_info() {
    if [ -f "$LIGHTPATH_INFO_FILE" ]; then
        source "$LIGHTPATH_INFO_FILE"
        return 0
    else
        return 1
    fi
}

# Generate Xray config for non-DoH deployment
generate_config_no_doh() {
    local uuid=$1
    local dest=$2
    local private_key=$3

    cat > "$XRAY_CONFIG_PATH" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 443,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$dest:443",
                    "serverNames": [
                        "$dest"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": [
                        "",
                        "0123456789abcdef"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF

    log_success "Xray configuration (non-DoH) generated at $XRAY_CONFIG_PATH"
}

# Generate Xray config for DoH deployment
generate_config_with_doh() {
    local uuid=$1
    local dest=$2
    local private_key=$3

    cat > "$XRAY_CONFIG_PATH" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "/dev/shm/reality.sock,0660",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$dest:443",
                    "serverNames": [
                        "$dest"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": [
                        "",
                        "0123456789abcdef"
                    ]
                },
                "sockopt": {
                    "acceptProxyProtocol": true
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ],
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "geoip:cn"
                ],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": [
                    "geoip:private"
                ],
                "outboundTag": "block"
            }
        ]
    }
}
EOF

    log_success "Xray configuration (with DoH) generated at $XRAY_CONFIG_PATH"
}

# Set up permissions for DoH deployment
setup_doh_permissions() {
    log_step "Setting up permissions for DoH deployment..."

    # Add www-data to nogroup (只在首次部署时需要)
    if id "www-data" &>/dev/null; then
        usermod -a -G nogroup www-data
        log_success "Added www-data to nogroup"
    else
        log_warning "User www-data not found, skipping permission setup"
        log_warning "If you're using a web server, you may need to set this up manually"
    fi
}

# Update Nginx configuration for DoH deployment
update_nginx_reality_sni() {
    local dest_domain=$1
    local nginx_conf="/etc/nginx/nginx.conf"

    # Check if Nginx config exists
    if [ ! -f "$nginx_conf" ]; then
        log_warning "Nginx configuration not found at $nginx_conf"
        log_info "Skipping Nginx SNI configuration update"
        return 0
    fi

    log_step "Checking Nginx configuration..."

    # Check if Nginx has stream block
    if ! grep -q "^stream {" "$nginx_conf"; then
        log_warning "Nginx configuration does not contain 'stream' block for SNI routing"
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}⚠️  NGINX CONFIGURATION REQUIRED${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}DoH deployment requires Nginx stream module for SNI routing.${NC}"
        echo -e "${YELLOW}Your current Nginx configuration is missing the stream block.${NC}"
        echo ""
        echo -e "${CYAN}Configuration file:${NC} ${YELLOW}${nginx_conf}${NC}"
        echo ""
        echo -e "${YELLOW}You need to manually add the following configuration:${NC}"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        cat <<'EOF'
stream {
    map $ssl_preread_server_name $sni_backend {
        doh.example.com        doh;
        DEST_DOMAIN            reality;
        default                 web;
    }

    upstream web {
        server unix:/dev/shm/web.sock;
    }

    upstream doh {
        server unix:/dev/shm/doh.sock;
    }

    upstream reality {
        server unix:/dev/shm/reality.sock;
    }

    server {
        listen 443 reuseport;
        listen [::]:443 reuseport;
        proxy_pass $sni_backend;
        proxy_protocol on;
        ssl_preread on;
        tcp_nodelay on;
    }
}
EOF
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}Replace 'DEST_DOMAIN' with:${NC} ${GREEN}${dest_domain}${NC}"
        echo -e "${YELLOW}Replace 'doh.example.com' with your DoH domain${NC}"
        echo ""
        echo -e "${CYAN}Steps:${NC}"
        echo -e "  ${GREEN}1.${NC} Edit Nginx config: ${CYAN}nano $nginx_conf${NC}"
        echo -e "  ${GREEN}2.${NC} Add the stream block BEFORE the http block"
        echo -e "  ${GREEN}3.${NC} Test configuration: ${CYAN}nginx -t${NC}"
        echo -e "  ${GREEN}4.${NC} Reload Nginx: ${CYAN}systemctl reload nginx${NC}"
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 2  # Return code 2 = needs manual configuration
    fi

    log_step "Updating Nginx SNI routing for Reality..."

    # Backup original config
    cp "$nginx_conf" "${nginx_conf}.bak.$(date +%s)"

    # Check if reality entry exists
    if grep -q "reality;" "$nginx_conf"; then
        # Update existing reality line
        sed -i "/reality;/s/^[[:space:]]*[^[:space:]]*[[:space:]]*reality;/        ${dest_domain}            reality;/" "$nginx_conf"
        log_success "Updated existing reality SNI: $dest_domain"
    else
        # Add reality line after finding the map block
        # Look for the line with "default" and add reality line before it
        if grep -q "default.*web;" "$nginx_conf"; then
            sed -i "/default.*web;/i\        ${dest_domain}            reality;" "$nginx_conf"
            log_success "Added new reality SNI: $dest_domain"
        else
            log_warning "Could not find appropriate location to add reality SNI"
            log_info "Please manually add to nginx.conf: ${dest_domain}            reality;"
            return 0
        fi
    fi

    # Test Nginx configuration
    if nginx -t &>/dev/null; then
        log_success "Nginx configuration test passed"

        # Reload Nginx
        log_step "Reloading Nginx..."
        systemctl reload nginx
        log_success "Nginx reloaded successfully"
        return 0  # Return code 0 = success
    else
        log_error "Nginx configuration test failed"
        log_warning "Restoring original configuration..."
        cp "${nginx_conf}.bak."* "$nginx_conf" 2>/dev/null || true
        log_info "Please check Nginx configuration manually"
        return 1  # Return code 1 = failed
    fi
}

# Deploy with no DoH
deploy_no_doh() {
    log_step "Starting deployment (without DoH)..."

    # Track if switching from with-DoH for post-deployment notice
    local was_with_doh=false

    # Check if there's an existing deployment
    if load_deployment_info 2>/dev/null; then
        echo ""
        log_warning "Existing deployment detected!"
        echo ""
        echo -e "${CYAN}Current Deployment:${NC}"
        echo -e "  Type: ${YELLOW}${DEPLOYMENT_TYPE}${NC}"
        echo -e "  UUID: ${UUID}"
        echo -e "  Destination: ${DEST_DOMAIN}"
        echo ""

        # Check if switching deployment type
        if [ "$DEPLOYMENT_TYPE" = "with-doh" ]; then
            was_with_doh=true
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}⚠️  DEPLOYMENT TYPE CHANGE DETECTED${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${YELLOW}You are switching from:${NC}"
            echo -e "  ${CYAN}with DoH${NC} (Unix socket + Nginx) ${RED}→${NC} ${CYAN}without DoH${NC} (Direct port 443)"
            echo ""
            echo -e "${YELLOW}This will:${NC}"
            echo -e "  ${RED}✗${NC} Regenerate all configuration (UUID, keys, destination)"
            echo -e "  ${RED}✗${NC} Change listening from Unix socket to port 443"
            echo -e "  ${RED}✗${NC} Invalidate all existing client configurations"
            echo -e "  ${RED}✗${NC} Require clients to update their configurations"
            echo ""
        else
            echo -e "${YELLOW}⚠️  This will regenerate the configuration:${NC}"
            echo -e "  ${RED}✗${NC} New UUID, keypair, and destination domain"
            echo -e "  ${RED}✗${NC} Existing client configurations will stop working"
            echo ""
        fi

        read -p "Do you want to continue? [y/N, or press Enter to cancel]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            read -p "Press Enter to return to menu..."
            return 1
        fi
        echo ""
    fi

    # Install Xray
    install_xray || return 1

    # Generate configuration parameters
    log_step "Generating configuration parameters..."
    local uuid=$(generate_uuid)
    local dest=$(get_random_dest)

    log_info "Generating X25519 keypair..."
    local keypair_output=$(generate_keypair)
    local private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
    local public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')

    log_info "UUID: $uuid"
    log_info "Destination: $dest"
    log_info "Private Key: $private_key"
    log_info "Public Key: $public_key"

    # Generate Xray configuration
    generate_config_no_doh "$uuid" "$dest" "$private_key"

    # Save deployment info
    create_config_dirs
    local server_ip=$(get_server_ip)
    save_deployment_info "no-doh" "$uuid" "$dest" "$private_key" "$public_key" "$server_ip" "443"

    # Restart Xray service
    log_step "Restarting Xray service..."
    systemctl restart xray
    systemctl status xray --no-pager

    log_success "Deployment completed successfully!"
    echo ""

    # Auto-generate client configurations
    log_step "Generating client configurations..."
    echo ""
    generate_all_client_configs

    # Show notice if switched from with-DoH
    if [ "$was_with_doh" = true ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}ℹ️  Deployment Type Switched: with-DoH → no-DoH${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}You have switched from DoH to non-DoH deployment.${NC}"
        echo ""
        echo -e "${CYAN}Changes:${NC}"
        echo -e "  ${GREEN}✓${NC} Xray now listens directly on port 443"
        echo -e "  ${GREEN}✓${NC} No longer uses Unix socket"
        echo ""
        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo -e "${YELLOW}Note: Nginx is still running and may be using port 443.${NC}"
            echo -e "${YELLOW}You may want to:${NC}"
            echo -e "  ${CYAN}1.${NC} Stop Nginx if no longer needed: ${PURPLE}systemctl stop nginx${NC}"
            echo -e "  ${CYAN}2.${NC} Or adjust Nginx configuration: ${PURPLE}nano /etc/nginx/nginx.conf${NC}"
            echo -e "  ${CYAN}3.${NC} Remove stream block if not needed"
            echo ""
        fi
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# Deploy with DoH
deploy_with_doh() {
    log_step "Starting deployment (with DoH)..."

    # Check if there's an existing deployment
    if load_deployment_info 2>/dev/null; then
        echo ""
        log_warning "Existing deployment detected!"
        echo ""
        echo -e "${CYAN}Current Deployment:${NC}"
        echo -e "  Type: ${YELLOW}${DEPLOYMENT_TYPE}${NC}"
        echo -e "  UUID: ${UUID}"
        echo -e "  Destination: ${DEST_DOMAIN}"
        echo ""

        # Check if switching deployment type
        if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}⚠️  DEPLOYMENT TYPE CHANGE DETECTED${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${YELLOW}You are switching from:${NC}"
            echo -e "  ${CYAN}without DoH${NC} (Direct port 443) ${RED}→${NC} ${CYAN}with DoH${NC} (Unix socket + Nginx)"
            echo ""
            echo -e "${YELLOW}This will:${NC}"
            echo -e "  ${RED}✗${NC} Regenerate all configuration (UUID, keys, destination)"
            echo -e "  ${RED}✗${NC} Change listening from port 443 to Unix socket"
            echo -e "  ${RED}✗${NC} Update Nginx SNI routing configuration"
            echo -e "  ${RED}✗${NC} Invalidate all existing client configurations"
            echo -e "  ${RED}✗${NC} Require clients to update their configurations"
            echo ""
        else
            echo -e "${YELLOW}⚠️  This will regenerate the configuration:${NC}"
            echo -e "  ${RED}✗${NC} New UUID, keypair, and destination domain"
            echo -e "  ${RED}✗${NC} Existing client configurations will stop working"
            echo ""
        fi

        read -p "Do you want to continue? [y/N, or press Enter to cancel]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Deployment cancelled"
            read -p "Press Enter to return to menu..."
            return 1
        fi
        echo ""
    fi

    # Check prerequisites for DoH deployment
    log_step "Checking prerequisites..."

    local nginx_status=0
    local adguard_status=0
    local prerequisites_met=true

    # Check Nginx
    check_nginx_installed
    nginx_status=$?

    if [ $nginx_status -eq 1 ]; then
        log_error "Nginx is not installed!"
        prerequisites_met=false
    elif [ $nginx_status -eq 2 ]; then
        log_error "Nginx is installed but not running!"
        prerequisites_met=false
    else
        log_success "Nginx is installed and running"
    fi

    # Check AdGuardHome
    check_adguardhome_installed
    adguard_status=$?

    if [ $adguard_status -eq 1 ]; then
        log_error "AdGuardHome is not installed!"
        prerequisites_met=false
    elif [ $adguard_status -eq 2 ]; then
        log_error "AdGuardHome is installed but not running!"
        prerequisites_met=false
    else
        log_success "AdGuardHome is installed and running"
    fi

    # If prerequisites are not met, offer to install them automatically
    if [ "$prerequisites_met" = false ]; then
        echo ""
        log_error "Prerequisites not met for DoH deployment!"
        echo ""
        echo -e "${YELLOW}The following services are required but not available:${NC}"

        local services_needed=()
        if [ $nginx_status -eq 1 ]; then
            echo -e "  ${RED}✗${NC} Nginx - not installed"
            services_needed+=("Nginx")
        elif [ $nginx_status -eq 2 ]; then
            echo -e "  ${YELLOW}○${NC} Nginx - installed but not running"
            services_needed+=("Nginx")
        fi

        if [ $adguard_status -eq 1 ]; then
            echo -e "  ${RED}✗${NC} AdGuardHome - not installed"
            services_needed+=("AdGuardHome")
        elif [ $adguard_status -eq 2 ]; then
            echo -e "  ${YELLOW}○${NC} AdGuardHome - installed but not running"
            services_needed+=("AdGuardHome")
        fi

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}What would you like to do?${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} Automatically install and configure missing services"
        echo -e "${YELLOW}2.${NC} Cancel and return to menu"
        echo ""
        read -p "Choose option [1-2, or press Enter to cancel]: " install_choice

        # Default to option 2 (cancel) if Enter is pressed
        install_choice=${install_choice:-2}

        case $install_choice in
            1)
                echo ""
                log_step "Installing required services automatically..."
                echo ""

                # Install/start Nginx if needed
                if [ $nginx_status -ne 0 ]; then
                    if [ $nginx_status -eq 1 ]; then
                        log_step "Installing Nginx..."

                        # Detect OS
                        if [ -f /etc/os-release ]; then
                            . /etc/os-release
                            OS=$ID
                        else
                            log_error "Unable to detect operating system"
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi

                        # Install Nginx based on OS
                        case $OS in
                            ubuntu|debian)
                                log_info "Installing Nginx on Ubuntu/Debian..."
                                export DEBIAN_FRONTEND=noninteractive
                                apt-get update -y > /dev/null 2>&1
                                apt-get install -y nginx > /dev/null 2>&1
                                ;;
                            centos|rhel|rocky|almalinux|fedora)
                                log_info "Installing Nginx on CentOS/RHEL/Rocky/AlmaLinux/Fedora..."
                                if command -v dnf &> /dev/null; then
                                    dnf install -y nginx > /dev/null 2>&1
                                else
                                    yum install -y nginx > /dev/null 2>&1
                                fi
                                ;;
                            *)
                                log_error "Unsupported operating system: $OS"
                                read -p "Press Enter to return to menu..."
                                return 1
                                ;;
                        esac

                        # Enable and start Nginx
                        systemctl enable nginx > /dev/null 2>&1
                        systemctl start nginx

                        if systemctl is-active --quiet nginx; then
                            log_success "Nginx installed and started successfully"
                        else
                            log_error "Nginx installation completed but service failed to start"
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi
                    else
                        log_step "Starting Nginx service..."
                        systemctl start nginx
                    fi
                fi

                # Install/start AdGuardHome if needed
                if [ $adguard_status -ne 0 ]; then
                    if [ $adguard_status -eq 1 ]; then
                        log_step "Installing AdGuardHome..."
                        # Use official installation script
                        curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
                        if [ $? -eq 0 ]; then
                            systemctl enable AdGuardHome
                            systemctl start AdGuardHome
                            log_success "AdGuardHome installed successfully"
                        else
                            log_error "Failed to install AdGuardHome"
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi
                    else
                        log_step "Starting AdGuardHome service..."
                        systemctl start AdGuardHome
                    fi
                fi

                # Verify installation
                echo ""
                log_step "Verifying installation..."
                sleep 2

                check_nginx_installed
                nginx_status=$?
                check_adguardhome_installed
                adguard_status=$?

                if [ $nginx_status -eq 0 ] && [ $adguard_status -eq 0 ]; then
                    echo ""
                    log_success "All prerequisites installed successfully!"
                    echo ""
                    log_info "Continuing with DoH deployment..."
                    echo ""
                    sleep 2
                    # Continue with deployment (don't return, let the function continue)
                else
                    echo ""
                    log_error "Installation verification failed"
                    if [ $nginx_status -ne 0 ]; then
                        log_error "Nginx is not running properly"
                    fi
                    if [ $adguard_status -ne 0 ]; then
                        log_error "AdGuardHome is not running properly"
                    fi
                    read -p "Press Enter to return to menu..."
                    return 1
                fi
                ;;
            2|"")
                log_info "Installation cancelled"
                read -p "Press Enter to return to menu..."
                return 1
                ;;
            *)
                log_error "Invalid option"
                read -p "Press Enter to return to menu..."
                return 1
                ;;
        esac
    fi

    echo ""

    # Check if this is first time deployment
    local is_first_deploy=false
    if ! check_xray_installed; then
        is_first_deploy=true
    fi

    # Install Xray
    install_xray || return 1

    # Generate configuration parameters
    log_step "Generating configuration parameters..."
    local uuid=$(generate_uuid)
    local dest=$(get_random_dest)

    log_info "Generating X25519 keypair..."
    local keypair_output=$(generate_keypair)
    local private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
    local public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')

    log_info "UUID: $uuid"
    log_info "Destination: $dest"
    log_info "Private Key: $private_key"
    log_info "Public Key: $public_key"

    # Generate Xray configuration
    generate_config_with_doh "$uuid" "$dest" "$private_key"

    # Set up permissions if first deployment
    if [ "$is_first_deploy" = true ]; then
        setup_doh_permissions
    fi

    # Save deployment info
    create_config_dirs
    local server_ip=$(get_server_ip)
    save_deployment_info "with-doh" "$uuid" "$dest" "$private_key" "$public_key" "$server_ip" "unix_socket"

    # Update Nginx SNI routing configuration
    echo ""
    update_nginx_reality_sni "$dest"
    local nginx_config_status=$?

    # Restart Xray service
    echo ""
    log_step "Restarting Xray service..."
    systemctl restart xray
    systemctl status xray --no-pager

    log_success "Deployment completed successfully!"
    echo ""

    # Auto-generate client configurations
    log_step "Generating client configurations..."
    echo ""
    generate_all_client_configs

    # Show post-deployment notice if Nginx needs manual configuration
    if [ $nginx_config_status -eq 2 ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}⚠️  IMPORTANT: Nginx Configuration Required${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}Xray has been deployed successfully, but you need to configure Nginx${NC}"
        echo -e "${YELLOW}stream module for SNI routing. Please refer to the instructions above.${NC}"
        echo ""
        echo -e "${CYAN}Configuration file:${NC} ${YELLOW}/etc/nginx/nginx.conf${NC}"
        echo -e "${CYAN}Your destination domain:${NC} ${GREEN}${dest}${NC}"
        echo ""
        echo -e "${YELLOW}After configuring Nginx, your DoH deployment will be fully functional.${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

# Modify existing configuration
modify_configuration() {
    log_step "Modifying existing configuration..."

    if ! check_xray_installed; then
        log_error "Xray is not installed. Please deploy first."
        return 1
    fi

    if ! load_deployment_info; then
        log_error "No deployment information found. Please deploy first."
        return 1
    fi

    echo ""
    echo -e "${CYAN}Current Configuration:${NC}"
    echo "  Deployment Type: $DEPLOYMENT_TYPE"
    echo "  UUID: $UUID"
    echo "  Destination: $DEST_DOMAIN"
    echo "  Public Key: $PUBLIC_KEY"
    echo ""

    echo -e "${YELLOW}What would you like to modify?${NC}"
    echo "  1. Regenerate UUID"
    echo "  2. Change destination domain"
    echo "  3. Regenerate keypair"
    echo "  4. Regenerate all (UUID + destination + keypair)"
    echo "  0. Cancel"
    echo ""

    read -p "Choose option [0-4, or press Enter to return]: " modify_choice

    local new_uuid="$UUID"
    local new_dest="$DEST_DOMAIN"
    local new_private_key="$PRIVATE_KEY"
    local new_public_key="$PUBLIC_KEY"

    case $modify_choice in
        1)
            log_step "Regenerating UUID..."
            new_uuid=$(generate_uuid)
            log_info "New UUID: $new_uuid"
            ;;
        2)
            log_step "Selecting new destination domain..."
            new_dest=$(get_random_dest)
            log_info "New destination: $new_dest"
            ;;
        3)
            log_step "Regenerating keypair..."
            local keypair_output=$(generate_keypair)
            new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
            new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
            log_info "New private key: $new_private_key"
            log_info "New public key: $new_public_key"
            ;;
        4)
            log_step "Regenerating all parameters..."
            new_uuid=$(generate_uuid)
            new_dest=$(get_random_dest)
            local keypair_output=$(generate_keypair)
            new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
            new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
            log_info "New UUID: $new_uuid"
            log_info "New destination: $new_dest"
            log_info "New private key: $new_private_key"
            log_info "New public key: $new_public_key"
            ;;
        0|"")
            log_info "Modification cancelled"
            return 0
            ;;
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac

    # Generate new configuration based on deployment type
    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        generate_config_no_doh "$new_uuid" "$new_dest" "$new_private_key"
    else
        generate_config_with_doh "$new_uuid" "$new_dest" "$new_private_key"
    fi

    # Save updated deployment info
    local port="443"
    if [ "$DEPLOYMENT_TYPE" = "with-doh" ]; then
        port="unix_socket"
    fi
    save_deployment_info "$DEPLOYMENT_TYPE" "$new_uuid" "$new_dest" "$new_private_key" "$new_public_key" "$SERVER_IP" "$port"

    # Update Nginx SNI routing if DoH deployment
    if [ "$DEPLOYMENT_TYPE" = "with-doh" ]; then
        update_nginx_reality_sni "$new_dest"
    fi

    # Restart Xray service
    log_step "Restarting Xray service..."
    systemctl restart xray

    log_success "Configuration updated successfully!"
    echo ""

    # Auto-generate client configurations
    log_step "Generating updated client configurations..."
    echo ""
    generate_all_client_configs
}

# Generate client configuration for Mihomo (Clash Meta)
generate_mihomo_config() {
    if ! load_deployment_info; then
        log_error "No deployment information found. Please deploy first."
        return 1
    fi

    local server_ip="$SERVER_IP"
    local port="443"

    # Get system hostname for node name
    local hostname=$(hostname)
    local node_name="${hostname}-Reality"

    log_success "Mihomo (Clash Meta) Configuration:"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat <<EOF
# Mihomo (Clash Meta) Configuration
# Generated: $(date)
# Deployment Type: $DEPLOYMENT_TYPE

proxies:
  - name: $node_name
    type: vless
    server: $server_ip
    port: $port
    uuid: $UUID
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    packet-encoding: xudp
    servername: $DEST_DOMAIN
    alpn:
      - h2
      - http/1.1
    reality-opts:
      public-key: $PUBLIC_KEY
    client-fingerprint: random
    skip-cert-verify: false
EOF
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Generate client configuration for Shadowrocket
generate_shadowrocket_config() {
    if ! load_deployment_info; then
        log_error "No deployment information found. Please deploy first."
        return 1
    fi

    local server_ip="$SERVER_IP"
    local port="443"

    # Get system hostname for node name
    local hostname=$(hostname)
    local node_name="${hostname}-Reality"

    # Build Shadowrocket URI
    # Format: vless://uuid@server:port?encryption=none&security=reality&sni=dest&fp=random&pbk=public_key&flow=xtls-rprx-vision&type=tcp#name
    local uri="vless://${UUID}@${server_ip}:${port}?encryption=none&security=reality&sni=${DEST_DOMAIN}&fp=random&pbk=${PUBLIC_KEY}&flow=xtls-rprx-vision&type=tcp&headerType=none#${node_name}"

    log_success "Shadowrocket Configuration:"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Shadowrocket URI:${NC}"
    echo "$uri"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Generate QR code
    generate_qr_code "$uri"
}

# Generate QR code for Shadowrocket
generate_qr_code() {
    local uri=$1

    # Check if qrencode is installed
    if ! command -v qrencode &> /dev/null; then
        log_info "Installing qrencode for QR code generation..."

        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y qrencode
        elif command -v yum &> /dev/null; then
            yum install -y qrencode
        elif command -v dnf &> /dev/null; then
            dnf install -y qrencode
        else
            log_warning "Could not install qrencode automatically"
            log_info "Please install it manually: apt-get install qrencode (Debian/Ubuntu) or yum install qrencode (CentOS/RHEL)"
            return 1
        fi
    fi

    log_info "Generating QR code..."
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Scan this QR code with Shadowrocket:${NC}"
    echo ""
    qrencode -t ANSIUTF8 "$uri"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Generate all client configurations
generate_all_client_configs() {
    log_step "Generating all client configurations..."
    echo ""

    generate_mihomo_config
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    generate_shadowrocket_config

    log_success "All client configurations generated!"
}

# View current configuration
view_configuration() {
    if ! check_xray_installed; then
        log_error "Xray is not installed"
        return 1
    fi

    if ! load_deployment_info; then
        log_error "No deployment information found"
        return 1
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Current Lightpath Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Deployment Type:${NC} $DEPLOYMENT_TYPE"
    echo -e "${YELLOW}Server IP:${NC} $SERVER_IP"
    echo -e "${YELLOW}Port:${NC} $PORT"
    echo -e "${YELLOW}UUID:${NC} $UUID"
    echo -e "${YELLOW}Destination Domain:${NC} $DEST_DOMAIN"
    echo -e "${YELLOW}Private Key:${NC} $PRIVATE_KEY"
    echo -e "${YELLOW}Public Key:${NC} $PUBLIC_KEY"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Show Xray service status
    log_step "Xray Service Status:"
    systemctl status xray --no-pager
}

# Uninstall Xray and remove configurations
uninstall() {
    log_warning "This will remove Xray and all Lightpath configurations"
    read -p "Are you sure? (yes/no, or press Enter to confirm): " confirm

    if [ "$confirm" != "yes" ] && [ -n "$confirm" ]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    log_step "Stopping Xray service..."
    systemctl stop xray || true
    systemctl disable xray || true

    log_step "Removing Xray..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge

    log_step "Removing Lightpath configurations..."
    rm -rf "$LIGHTPATH_CONFIG_DIR"

    log_success "Uninstallation completed"
}

# Test Xray configuration
test_configuration() {
    log_step "Testing Xray configuration..."

    if ! check_xray_installed; then
        log_error "Xray is not installed"
        return 1
    fi

    if ! [ -f "$XRAY_CONFIG_PATH" ]; then
        log_error "Configuration file not found: $XRAY_CONFIG_PATH"
        return 1
    fi

    if xray -test -config "$XRAY_CONFIG_PATH"; then
        log_success "Configuration is valid"
    else
        log_error "Configuration validation failed"
        return 1
    fi
}

# Main menu
show_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}           Lightpath Manager (Xray Reality)         ${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Show current status
        if check_xray_installed; then
            local status=$(systemctl is-active xray 2>/dev/null || echo "inactive")
            if [ "$status" = "active" ]; then
                echo -e "${GREEN}Status: Xray is running${NC}"
            else
                echo -e "${RED}Status: Xray is installed but not running${NC}"
            fi
            echo ""

            # Load deployment info to show deployment type
            if load_deployment_info 2>/dev/null; then
                if [ "$DEPLOYMENT_TYPE" = "with-doh" ]; then
                    echo -e "${CYAN}Deployment Type: ${YELLOW}with DoH${NC} ${PURPLE}(Nginx SNI routing enabled)${NC}"
                else
                    echo -e "${CYAN}Deployment Type: ${YELLOW}without DoH${NC} ${PURPLE}(Direct port 443)${NC}"
                fi
                echo ""
            fi

            echo -e "${CYAN}Configuration Files:${NC}"
            echo -e "  Server: ${YELLOW}$XRAY_CONFIG_PATH${NC}"
            echo -e "  Deploy: ${YELLOW}$LIGHTPATH_INFO_FILE${NC}"

            # Show Nginx config path for DoH deployment
            if [ "${DEPLOYMENT_TYPE:-}" = "with-doh" ]; then
                echo -e "  Nginx:  ${YELLOW}/etc/nginx/nginx.conf${NC} ${PURPLE}(auto-updates reality SNI)${NC}"
            fi
        else
            echo -e "${YELLOW}Status: Xray is not installed${NC}"
        fi
        echo ""

        echo -e "${CYAN}┌─ Deployment ─────────────────────────────────────┐${NC}"
        echo -e "${GREEN} 1.${NC} Deploy (without DoH)"
        echo -e "${GREEN} 2.${NC} Deploy (with DoH)"
        echo -e "${GREEN} 3.${NC} Modify Configuration"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Client Configuration ───────────────────────────┐${NC}"
        echo -e "${GREEN} 4.${NC} Generate All Client Configs"
        echo -e "${GREEN} 5.${NC} Generate Mihomo Config"
        echo -e "${GREEN} 6.${NC} Generate Shadowrocket Config + QR Code"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${CYAN}┌─ Management ─────────────────────────────────────┐${NC}"
        echo -e "${GREEN} 7.${NC} View Current Configuration"
        echo -e "${GREEN} 8.${NC} Test Configuration"
        echo -e "${GREEN} 9.${NC} Restart Xray Service"
        echo -e "${RED}10.${NC} Uninstall"
        echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
        echo ""
        echo -e "${YELLOW} 0.${NC} Return to Main Menu"
        echo ""

        read -p "Choose option [0-10, or press Enter to return]: " choice

        # Track if we need to pause after the operation
        local need_pause=true

        case $choice in
            1)
                deploy_no_doh || need_pause=false
                ;;
            2)
                deploy_with_doh || need_pause=false
                ;;
            3)
                modify_configuration || need_pause=false
                ;;
            4)
                generate_all_client_configs
                ;;
            5)
                generate_mihomo_config
                ;;
            6)
                generate_shadowrocket_config
                ;;
            7)
                view_configuration
                ;;
            8)
                test_configuration
                ;;
            9)
                log_step "Restarting Xray service..."
                systemctl restart xray
                systemctl status xray --no-pager
                ;;
            10)
                uninstall
                ;;
            0|"")
                log_info "Returning to main menu..."
                break
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac

        # Only show "Press Enter" if the function didn't handle it internally
        if [ "$need_pause" = true ]; then
            echo ""
            read -p "Press Enter to continue..."
        fi
    done
}

# Main function
main() {
    check_root

    if [ $# -eq 0 ]; then
        show_menu
    else
        # Support command line arguments
        case $1 in
            deploy-no-doh)
                deploy_no_doh
                ;;
            deploy-with-doh)
                deploy_with_doh
                ;;
            modify)
                modify_configuration
                ;;
            generate-client)
                generate_all_client_configs
                ;;
            view)
                view_configuration
                ;;
            test)
                test_configuration
                ;;
            uninstall)
                uninstall
                ;;
            *)
                echo "Usage: $0 {deploy-no-doh|deploy-with-doh|modify|generate-client|view|test|uninstall}"
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
