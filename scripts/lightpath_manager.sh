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
# 要求: 国外网站, 支持 TLSv1.3 与 H2, 非跳转域名, 未被 GFW 封锁
DEST_DOMAINS=(
    "www.office.com"
    "www.apple.com"
    "www.icloud.com"
    "www.cisco.com"
    "www.ebay.com"
    "www.openssl.org"
    "www.nasa.gov"
    "www.kernel.org"
    "arxiv.org"
    "www.php.net"
    "www.python.org"
    "www.postgresql.org"
    "www.debian.org"
    "www.apache.org"
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

# Check if a specific port is allowed in firewall
# Returns: 0 = open, 1 = blocked, 2 = unknown/no firewall
check_firewall_port() {
    local port=$1
    local is_open=false
    local has_firewall=false

    # Check UFW
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        has_firewall=true
        if ufw status 2>/dev/null | grep -E "^${port}(/tcp)?[[:space:]]+" | grep -q "ALLOW"; then
            is_open=true
        fi
    fi

    # Check iptables (only if UFW didn't already determine the status)
    # Note: UFW is a frontend for iptables, so if UFW is active, trust UFW's result
    if [ "$is_open" = false ] && command -v iptables &>/dev/null; then
        # Check if there are any filter rules
        if iptables -L INPUT -n 2>/dev/null | grep -q "^Chain INPUT"; then
            has_firewall=true
            # Check if port is explicitly allowed in iptables
            if iptables -L INPUT -n 2>/dev/null | grep -E "dpt:${port}[[:space:]]" | grep -q "ACCEPT"; then
                is_open=true
            fi
        fi
    fi

    # Check firewalld
    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        has_firewall=true
        if firewall-cmd --list-ports 2>/dev/null | grep -q "${port}/tcp"; then
            is_open=true
        elif firewall-cmd --list-services 2>/dev/null | grep -q "https" && [ "$port" = "443" ]; then
            is_open=true
        fi
    fi

    # If we found a firewall and port is explicitly open
    if [ "$has_firewall" = true ] && [ "$is_open" = true ]; then
        return 0  # Open
    elif [ "$has_firewall" = true ] && [ "$is_open" = false ]; then
        return 1  # Blocked
    else
        return 2  # No firewall detected or unknown
    fi
}

# Get firewall status message for a port
get_firewall_status_message() {
    local port=$1
    check_firewall_port "$port"
    local status=$?

    case $status in
        0)
            echo -e "${GREEN}✓ Port $port is open in firewall${NC}"
            return 0
            ;;
        1)
            echo -e "${RED}✗ Port $port is BLOCKED by firewall${NC}"
            return 1
            ;;
        2)
            echo -e "${YELLOW}? Firewall status unknown (no active firewall detected)${NC}"
            return 2
            ;;
    esac
}

# Check if Nginx has required stream modules for DoH deployment
# Returns: 0 = has required modules, 1 = missing modules, 2 = nginx not installed
check_nginx_stream_support() {
    # Check if nginx is installed
    if ! command -v nginx &> /dev/null; then
        return 2
    fi

    # Check nginx compile-time configuration
    local nginx_config=$(nginx -V 2>&1)

    # Check for stream module (both static and dynamic)
    if ! echo "$nginx_config" | grep -qE -- "--with-stream(=dynamic)?"; then
        return 1
    fi

    # Check for ssl_preread module (required for SNI-based routing)
    if ! echo "$nginx_config" | grep -q -- "--with-stream_ssl_preread_module"; then
        return 1
    fi

    # If stream is dynamic, verify the .so file exists
    if echo "$nginx_config" | grep -q -- "--with-stream=dynamic"; then
        # Check common module paths
        if [ ! -f /usr/lib/nginx/modules/ngx_stream_module.so ] && \
           [ ! -f /usr/share/nginx/modules/ngx_stream_module.so ] && \
           [ ! -f /etc/nginx/modules/ngx_stream_module.so ]; then
            # Dynamic module declared but file doesn't exist
            return 1
        fi
    fi

    return 0
}

# Check if stream module is compiled as dynamic module
is_stream_module_dynamic() {
    if ! command -v nginx &> /dev/null; then
        return 1
    fi

    local nginx_config=$(nginx -V 2>&1)
    if echo "$nginx_config" | grep -q -- "--with-stream=dynamic"; then
        return 0
    else
        return 1
    fi
}

# Get path to stream module .so file if it exists
get_stream_module_path() {
    local paths=(
        "/usr/lib/nginx/modules/ngx_stream_module.so"
        "/usr/share/nginx/modules/ngx_stream_module.so"
        "/etc/nginx/modules/ngx_stream_module.so"
    )

    for path in "${paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Get installed Nginx package variant
get_nginx_package_variant() {
    if dpkg -l 2>/dev/null | grep -q "^ii.*nginx-extras"; then
        echo "nginx-extras"
    elif dpkg -l 2>/dev/null | grep -q "^ii.*nginx-full"; then
        echo "nginx-full"
    elif dpkg -l 2>/dev/null | grep -q "^ii.*nginx-core"; then
        echo "nginx-core"
    elif dpkg -l 2>/dev/null | grep -q "^ii.*nginx-light"; then
        echo "nginx-light"
    else
        echo "unknown"
    fi
}

# Completely remove Nginx and clean up all related files
clean_nginx_completely() {
    log_info "Completely removing Nginx and cleaning up..."

    # Stop nginx service
    systemctl stop nginx 2>/dev/null || true
    killall nginx 2>/dev/null || true

    # Use dpkg to force remove all nginx packages
    local nginx_packages=$(dpkg -l 2>/dev/null | grep nginx | awk '{print $2}' | tr '\n' ' ')
    if [ -n "$nginx_packages" ]; then
        log_info "Removing nginx packages: $nginx_packages"
        dpkg --purge --force-all $nginx_packages 2>/dev/null || true
    fi

    # Clean up dpkg info files
    rm -rf /var/lib/dpkg/info/nginx* 2>/dev/null || true
    rm -rf /var/lib/dpkg/info/libnginx* 2>/dev/null || true

    # Clean package cache
    apt-get clean 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true

    # Fix broken dependencies
    apt-get -f install -y 2>/dev/null || true

    log_success "Nginx cleanup completed"
}

# Add stream block to existing Nginx configuration
add_stream_block_to_nginx() {
    local nginx_conf="$1"
    local dest_domain="$2"

    log_info "Adding stream block to Nginx configuration..."

    # Backup original config
    cp "$nginx_conf" "${nginx_conf}.bak.$(date +%s)"

    # Create temporary file with stream block
    local stream_block=$(cat <<EOF
stream {
    # SNI-based routing for DoH deployment
    map \$ssl_preread_server_name \$sni_backend {
        # doh.example.com        doh;
        ${dest_domain}            reality;
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
        proxy_pass \$sni_backend;
        proxy_protocol on;
        ssl_preread on;
        tcp_nodelay on;
    }
}

EOF
)

    # Create temporary file
    local temp_conf=$(mktemp)

    # Check if http block exists
    if grep -q "^http {" "$nginx_conf"; then
        # Insert stream block before http block
        awk -v stream_block="$stream_block" '
        /^http {/ && !stream_printed {
            print stream_block
            stream_printed=1
        }
        {print}
        ' "$nginx_conf" > "$temp_conf"
    else
        # If no http block, append stream block at the end
        cat "$nginx_conf" > "$temp_conf"
        echo "" >> "$temp_conf"
        echo "$stream_block" >> "$temp_conf"
    fi

    # Replace original config
    mv "$temp_conf" "$nginx_conf"

    log_success "Stream block added with destination: $dest_domain"
}

# Create default Nginx configuration with stream support for DoH
create_default_nginx_config() {
    local nginx_conf="/etc/nginx/nginx.conf"

    log_info "Creating default Nginx configuration with stream support..."

    # Create www-data user if it doesn't exist
    if ! id -u www-data &>/dev/null; then
        log_info "Creating www-data user..."
        useradd -r -s /usr/sbin/nologin www-data 2>/dev/null || true
    fi

    # Create nginx config directory if it doesn't exist
    mkdir -p /etc/nginx/conf.d
    mkdir -p /etc/nginx/sites-enabled
    mkdir -p /etc/nginx/sites-available
    mkdir -p /var/log/nginx
    mkdir -p /var/lib/nginx
    mkdir -p /dev/shm

    # Set ownership for log directory
    chown -R www-data:www-data /var/log/nginx 2>/dev/null || true

    # Create default nginx.conf with stream block for DoH
    # Note: Stream module will be loaded via /etc/nginx/modules-enabled/*.conf
    cat > "$nginx_conf" <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

stream {
    # SNI-based routing for DoH deployment
    # This will be updated during Lightpath deployment
    map $ssl_preread_server_name $sni_backend {
        # doh.example.com        doh;
        # www.example.com        reality;
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

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##
    gzip on;

    ##
    # Virtual Host Configs
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # Create mime.types if it doesn't exist
    if [ ! -f /etc/nginx/mime.types ]; then
        cat > /etc/nginx/mime.types <<'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    application/javascript                js;
    application/json                      json;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    image/png                             png;
    application/x-font-ttf                ttc ttf;
    font/woff                             woff;
    font/woff2                            woff2;
}
EOF
    fi

    # Set proper permissions
    chown -R root:root /etc/nginx
    chmod 644 "$nginx_conf"

    log_success "Default Nginx configuration created"
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

# Test TLS handshake latency for a single domain
# Returns: average latency in seconds (as a decimal), or 999999 if failed
test_domain_latency() {
    local domain=$1
    local test_count=${2:-3}  # Default to 3 tests
    local total_time=0
    local success_count=0

    for i in $(seq 1 $test_count); do
        # Use timeout to prevent hanging
        # Extract 'real' time from output
        local time_output=$(timeout 10 bash -c "time openssl s_client -connect ${domain}:443 -servername ${domain} </dev/null >/dev/null 2>&1" 2>&1)

        if [ $? -eq 0 ]; then
            # Extract the 'real' time value (format: 0m0.XXXs)
            local real_time=$(echo "$time_output" | grep "^real" | awk '{print $2}')

            if [ -n "$real_time" ]; then
                # Convert time format "0m0.XXXs" to seconds
                # Remove 'm' and 's', convert to seconds
                local minutes=$(echo "$real_time" | sed 's/m.*//')
                local seconds=$(echo "$real_time" | sed 's/.*m//' | sed 's/s//')

                # Calculate total seconds using bc if available, otherwise use awk
                if command -v bc &> /dev/null; then
                    local time_in_seconds=$(echo "$minutes * 60 + $seconds" | bc)
                else
                    local time_in_seconds=$(awk "BEGIN {print $minutes * 60 + $seconds}")
                fi

                total_time=$(awk "BEGIN {print $total_time + $time_in_seconds}")
                success_count=$((success_count + 1))
            fi
        fi
    done

    # Return average or failure indicator
    if [ $success_count -gt 0 ]; then
        awk "BEGIN {printf \"%.3f\", $total_time / $success_count}"
    else
        echo "999999"
    fi
}

# Smart selection: test all domains and select the one with lowest latency
# Returns: best domain name
get_best_dest() {
    log_step "Testing TLS handshake latency for all destination domains..." >&2
    log_info "This may take a moment (testing each domain 3 times)..." >&2
    echo "" >&2

    local best_domain=""
    local best_latency=999999
    local test_results=()

    # Test each domain
    for domain in "${DEST_DOMAINS[@]}"; do
        log_info "Testing ${CYAN}${domain}${NC}..." >&2

        local avg_latency=$(test_domain_latency "$domain" 3)

        # Store result for display
        test_results+=("${domain}:${avg_latency}")

        # Check if this is the best so far
        local is_better=$(awk "BEGIN {print ($avg_latency < $best_latency)}")
        if [ "$is_better" = "1" ]; then
            best_latency=$avg_latency
            best_domain=$domain
        fi

        # Display result
        if [ "$avg_latency" = "999999" ]; then
            echo -e "  ${RED}✗${NC} Failed to connect" >&2
        else
            echo -e "  ${GREEN}✓${NC} Average latency: ${YELLOW}${avg_latency}s${NC}" >&2
        fi
    done

    echo "" >&2
    log_success "Best domain selected: ${GREEN}${best_domain}${NC} (${YELLOW}${best_latency}s${NC})" >&2
    echo "" >&2

    # Display summary
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${YELLOW}Latency Test Results (Sorted by Latency - Lower is Better):${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2

    # Sort results by latency (numerical sort)
    # Separate successful and failed tests
    local sorted_results=$(printf '%s\n' "${test_results[@]}" | sort -t':' -k2 -n)

    local rank=1
    while IFS= read -r result; do
        local d=$(echo "$result" | cut -d':' -f1)
        local lat=$(echo "$result" | cut -d':' -f2)

        if [ "$lat" = "999999" ]; then
            echo -e "  ${RED}✗${NC} ${d}: ${RED}Failed${NC}" >&2
        elif [ "$d" = "$best_domain" ]; then
            echo -e "  ${GREEN}★ #${rank}${NC} ${GREEN}${d}${NC}: ${GREEN}${lat}s${NC} ${YELLOW}← Selected as Best Domain${NC}" >&2
        else
            echo -e "  ${BLUE}○ #${rank}${NC} ${d}: ${lat}s" >&2
        fi

        # Only increment rank for successful tests
        if [ "$lat" != "999999" ]; then
            rank=$((rank + 1))
        fi
    done <<< "$sorted_results"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2

    echo "$best_domain"
}

# Interactive destination domain selection
# Shows test results and allows user to choose
select_dest_interactive() {
    # First, get the best domain (this will display test results)
    local recommended_dest=$(get_best_dest)

    echo "" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}Destination Domain Selection${NC}" >&2
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2
    echo -e "${GREEN}Recommended domain:${NC} ${YELLOW}${recommended_dest}${NC} (lowest latency)" >&2
    echo "" >&2
    echo -e "${YELLOW}What would you like to do?${NC}" >&2
    echo -e "  ${GREEN}1.${NC} Use recommended domain (${recommended_dest})" >&2
    echo -e "  ${CYAN}2.${NC} Select from tested domains list" >&2
    echo -e "  ${BLUE}3.${NC} Enter custom domain (will be tested)" >&2
    echo -e "  ${YELLOW}0.${NC} Cancel" >&2
    echo "" >&2

    read -p "Choose option [0-3, or press Enter to use recommended]: " choice

    # Default to option 1 if Enter is pressed
    choice=${choice:-1}

    case $choice in
        1|"")
            echo "" >&2
            log_success "Using recommended domain: ${GREEN}${recommended_dest}${NC}" >&2
            echo "$recommended_dest"
            ;;
        2)
            # Let user select from the list
            echo "" >&2
            echo -e "${CYAN}Available domains (sorted by latency):${NC}" >&2
            echo "" >&2

            local index=1
            local domain_list=()

            # Build the list from DEST_DOMAINS (we should use the test results from get_best_dest)
            for domain in "${DEST_DOMAINS[@]}"; do
                domain_list+=("$domain")
                echo -e "  ${GREEN}${index}.${NC} ${domain}" >&2
                index=$((index + 1))
            done

            echo "" >&2
            read -p "Enter number (1-${#DEST_DOMAINS[@]}): " domain_choice

            if [[ "$domain_choice" =~ ^[0-9]+$ ]] && [ "$domain_choice" -ge 1 ] && [ "$domain_choice" -le "${#DEST_DOMAINS[@]}" ]; then
                local selected_domain="${domain_list[$((domain_choice - 1))]}"
                echo "" >&2
                log_success "Selected domain: ${GREEN}${selected_domain}${NC}" >&2
                echo "$selected_domain"
            else
                log_error "Invalid selection, using recommended domain" >&2
                echo "$recommended_dest"
            fi
            ;;
        3)
            # Let user enter custom domain
            echo "" >&2
            read -p "Enter custom domain (e.g., www.example.com): " custom_domain

            if [ -z "$custom_domain" ]; then
                log_error "No domain entered, using recommended domain" >&2
                echo "$recommended_dest"
            else
                echo "" >&2
                log_step "Testing custom domain: ${custom_domain}..." >&2

                local custom_latency=$(test_domain_latency "$custom_domain" 3)

                if [ "$custom_latency" = "999999" ]; then
                    echo "" >&2
                    log_error "Failed to connect to ${custom_domain}" >&2
                    log_warning "Using recommended domain instead: ${recommended_dest}" >&2
                    echo "$recommended_dest"
                else
                    echo "" >&2
                    log_success "Custom domain test result: ${YELLOW}${custom_latency}s${NC}" >&2
                    echo "" >&2
                    echo -e "${CYAN}Comparison:${NC}" >&2
                    echo -e "  Recommended (${recommended_dest}): from test results above" >&2
                    echo -e "  Custom (${custom_domain}): ${YELLOW}${custom_latency}s${NC}" >&2
                    echo "" >&2

                    read -p "Use custom domain '${custom_domain}'? [Y/n, or press Enter to confirm]: " confirm
                    # Default to yes if Enter is pressed (empty input)
                    confirm=${confirm:-y}
                    if [[ "$confirm" =~ ^[Nn]$ ]]; then
                        log_info "Using recommended domain: ${recommended_dest}" >&2
                        echo "$recommended_dest"
                    else
                        log_success "Using custom domain: ${GREEN}${custom_domain}${NC}" >&2
                        echo "$custom_domain"
                    fi
                fi
            fi
            ;;
        0)
            log_info "Selection cancelled, using recommended domain" >&2
            echo "$recommended_dest"
            ;;
        *)
            log_error "Invalid option, using recommended domain" >&2
            echo "$recommended_dest"
            ;;
    esac
}

# Get random destination domain (fallback method)
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
    local port=${4:-443}  # Default to 443 if not specified

    cat > "$XRAY_CONFIG_PATH" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
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

        # Automatically add stream block to nginx.conf
        add_stream_block_to_nginx "$nginx_conf" "$dest_domain"

        # Test the new configuration
        log_step "Testing Nginx configuration..."
        if nginx -t &>/dev/null; then
            log_success "Nginx configuration test passed"

            # Reload Nginx to apply changes
            log_step "Reloading Nginx service..."
            if systemctl reload nginx &>/dev/null; then
                log_success "Nginx reloaded successfully with stream configuration"
            else
                log_warning "Nginx reload failed, attempting restart..."
                systemctl restart nginx
                if systemctl is-active --quiet nginx; then
                    log_success "Nginx restarted successfully"
                else
                    log_error "Nginx restart failed!"
                    echo ""
                    echo -e "${YELLOW}Service status:${NC}"
                    systemctl status nginx.service --no-pager -l 2>&1 || true
                    echo ""
                    return 1
                fi
            fi
        else
            log_error "Nginx configuration test failed!"
            echo ""
            echo -e "${YELLOW}Configuration test output:${NC}"
            nginx -t 2>&1
            echo ""
            log_warning "Please check the configuration manually at: $nginx_conf"
            log_info "A backup was created before modification"
            return 1
        fi
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

        read -p "Do you want to continue? [Y/n, or press Enter to confirm]: " confirm
        # Default to yes if Enter is pressed (empty input)
        confirm=${confirm:-y}
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
    echo ""
    local dest=$(get_best_dest)

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

        read -p "Do you want to continue? [Y/n, or press Enter to confirm]: " confirm
        # Default to yes if Enter is pressed (empty input)
        confirm=${confirm:-y}
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

    local nginx_needs_upgrade=false
    local current_nginx_variant=""

    if [ $nginx_status -eq 1 ]; then
        log_error "Nginx is not installed!"
        prerequisites_met=false
    elif [ $nginx_status -eq 2 ]; then
        log_error "Nginx is installed but not running!"
        prerequisites_met=false

        # Even if not running, check if it has stream module support
        check_nginx_stream_support
        local stream_status=$?

        if [ $stream_status -eq 1 ]; then
            current_nginx_variant=$(get_nginx_package_variant)
            log_error "Nginx lacks required stream modules!"
            echo -e "  ${YELLOW}Current variant:${NC} ${RED}${current_nginx_variant}${NC}"
            echo -e "  ${YELLOW}Required modules:${NC} stream, stream_ssl_preread"
            echo -e "  ${YELLOW}Recommended:${NC} nginx-extras or nginx-full"
            nginx_needs_upgrade=true
        else
            current_nginx_variant=$(get_nginx_package_variant)
            log_info "Stream module support: OK (${current_nginx_variant})"
        fi
    else
        log_success "Nginx is installed and running"

        # Check if Nginx has stream module support
        check_nginx_stream_support
        local stream_status=$?

        if [ $stream_status -eq 1 ]; then
            current_nginx_variant=$(get_nginx_package_variant)
            log_error "Nginx lacks required stream modules!"
            echo -e "  ${YELLOW}Current variant:${NC} ${RED}${current_nginx_variant}${NC}"
            echo -e "  ${YELLOW}Required modules:${NC} stream, stream_ssl_preread"
            echo -e "  ${YELLOW}Recommended:${NC} nginx-extras or nginx-full"
            nginx_needs_upgrade=true
            prerequisites_met=false
        else
            current_nginx_variant=$(get_nginx_package_variant)
            log_success "Nginx has required stream modules (${current_nginx_variant})"
        fi
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
            if [ "$nginx_needs_upgrade" = true ]; then
                echo -e "  ${RED}✗${NC} Nginx - installed but not running (missing stream modules)"
                echo -e "      ${YELLOW}Current variant:${NC} ${current_nginx_variant}"
                services_needed+=("Nginx (upgrade to nginx-extras)")
            else
                echo -e "  ${YELLOW}○${NC} Nginx - installed but not running"
                services_needed+=("Nginx")
            fi
        elif [ "$nginx_needs_upgrade" = true ]; then
            echo -e "  ${RED}✗${NC} Nginx - missing stream modules (current: ${current_nginx_variant})"
            services_needed+=("Nginx (upgrade to nginx-extras)")
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

                # Install/upgrade/start Nginx if needed
                if [ $nginx_status -ne 0 ] || [ "$nginx_needs_upgrade" = true ]; then
                    # Detect OS first
                    if [ -f /etc/os-release ]; then
                        . /etc/os-release
                        OS=$ID
                    else
                        log_error "Unable to detect operating system"
                        read -p "Press Enter to return to menu..."
                        return 1
                    fi

                    if [ "$nginx_needs_upgrade" = true ]; then
                        log_step "Upgrading Nginx to nginx-extras..."

                        # Backup nginx configuration if exists
                        if [ -d /etc/nginx ]; then
                            log_info "Backing up Nginx configuration..."
                            cp -r /etc/nginx /etc/nginx.backup.$(date +%s) 2>/dev/null || true
                        fi

                        # Completely remove existing Nginx installation
                        clean_nginx_completely

                        case $OS in
                            ubuntu|debian)
                                export DEBIAN_FRONTEND=noninteractive

                                # Update and install nginx-extras
                                log_info "Installing nginx-extras..."
                                apt-get update -y > /dev/null 2>&1
                                apt-get install -y nginx-extras > /dev/null 2>&1
                                ;;
                            centos|rhel|rocky|almalinux|fedora)
                                log_info "Installing Nginx with stream support..."
                                if command -v dnf &> /dev/null; then
                                    dnf install -y nginx nginx-mod-stream > /dev/null 2>&1
                                else
                                    yum install -y nginx nginx-mod-stream > /dev/null 2>&1
                                fi
                                ;;
                            *)
                                log_error "Unsupported operating system: $OS"
                                read -p "Press Enter to return to menu..."
                                return 1
                                ;;
                        esac

                        # Check if nginx.conf exists, create if missing
                        if [ ! -f /etc/nginx/nginx.conf ]; then
                            log_warning "Nginx configuration file not found, creating default config with stream support..."
                            create_default_nginx_config
                        fi

                        # Test configuration before starting
                        if ! nginx -t &>/dev/null; then
                            log_error "Nginx configuration test failed after upgrade!"
                            echo ""
                            echo -e "${YELLOW}Configuration test output:${NC}"
                            nginx -t
                            echo ""
                            log_warning "The upgraded Nginx has configuration errors. Please fix them manually."
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi

                        # Enable and start Nginx
                        systemctl enable nginx > /dev/null 2>&1
                        systemctl start nginx

                        if systemctl is-active --quiet nginx; then
                            log_success "Nginx upgraded to nginx-extras successfully"
                        else
                            log_error "Nginx upgrade completed but service failed to start!"
                            echo ""
                            echo -e "${YELLOW}Checking service status:${NC}"
                            systemctl status nginx.service --no-pager -l 2>&1 || true
                            echo ""
                            echo -e "${YELLOW}Error log:${NC}"
                            tail -20 /var/log/nginx/error.log 2>/dev/null || echo "  (No error log available)"
                            echo ""
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi

                    elif [ $nginx_status -eq 1 ]; then
                        log_step "Installing Nginx (nginx-extras)..."

                        # Install Nginx based on OS
                        case $OS in
                            ubuntu|debian)
                                log_info "Installing nginx-extras on Ubuntu/Debian..."
                                export DEBIAN_FRONTEND=noninteractive
                                apt-get update -y > /dev/null 2>&1
                                apt-get install -y nginx-extras > /dev/null 2>&1
                                ;;
                            centos|rhel|rocky|almalinux|fedora)
                                log_info "Installing Nginx with stream support on CentOS/RHEL/Rocky/AlmaLinux/Fedora..."
                                if command -v dnf &> /dev/null; then
                                    dnf install -y nginx nginx-mod-stream > /dev/null 2>&1
                                else
                                    yum install -y nginx nginx-mod-stream > /dev/null 2>&1
                                fi
                                ;;
                            *)
                                log_error "Unsupported operating system: $OS"
                                read -p "Press Enter to return to menu..."
                                return 1
                                ;;
                        esac

                        # Check if nginx.conf exists, create if missing
                        if [ ! -f /etc/nginx/nginx.conf ]; then
                            log_warning "Nginx configuration file not found, creating default config with stream support..."
                            create_default_nginx_config
                        fi

                        # Test configuration before starting
                        if ! nginx -t &>/dev/null; then
                            log_error "Nginx configuration test failed after installation!"
                            echo ""
                            echo -e "${YELLOW}Configuration test output:${NC}"
                            nginx -t
                            echo ""
                            log_warning "The newly installed Nginx has configuration errors. Please fix them manually."
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi

                        # Enable and start Nginx
                        systemctl enable nginx > /dev/null 2>&1
                        systemctl start nginx

                        if systemctl is-active --quiet nginx; then
                            log_success "Nginx installed and started successfully"
                        else
                            log_error "Nginx installation completed but service failed to start!"
                            echo ""
                            echo -e "${YELLOW}Checking service status:${NC}"
                            systemctl status nginx.service --no-pager -l 2>&1 || true
                            echo ""
                            echo -e "${YELLOW}Error log:${NC}"
                            tail -20 /var/log/nginx/error.log 2>/dev/null || echo "  (No error log available)"
                            echo ""
                            read -p "Press Enter to return to menu..."
                            return 1
                        fi
                    else
                        # Nginx is installed but not running (nginx_status=2)
                        # But we still need to check if it has stream module support
                        if [ "$nginx_needs_upgrade" = true ]; then
                            # Nginx lacks stream modules, need to upgrade
                            log_step "Upgrading Nginx to nginx-extras for stream module support..."

                            # Detect OS first
                            if [ -f /etc/os-release ]; then
                                . /etc/os-release
                                OS=$ID
                            else
                                log_error "Unable to detect operating system"
                                read -p "Press Enter to return to menu..."
                                return 1
                            fi

                            # Backup nginx configuration if exists
                            if [ -d /etc/nginx ]; then
                                log_info "Backing up Nginx configuration..."
                                cp -r /etc/nginx /etc/nginx.backup.$(date +%s) 2>/dev/null || true
                            fi

                            # Completely remove existing Nginx installation
                            clean_nginx_completely

                            case $OS in
                                ubuntu|debian)
                                    export DEBIAN_FRONTEND=noninteractive

                                    # Update and install nginx-extras
                                    log_info "Installing nginx-extras..."
                                    apt-get update -y > /dev/null 2>&1
                                    apt-get install -y nginx-extras > /dev/null 2>&1
                                    ;;
                                centos|rhel|rocky|almalinux|fedora)
                                    log_info "Installing Nginx with stream support..."
                                    if command -v dnf &> /dev/null; then
                                        dnf install -y nginx nginx-mod-stream > /dev/null 2>&1
                                    else
                                        yum install -y nginx nginx-mod-stream > /dev/null 2>&1
                                    fi
                                    ;;
                                *)
                                    log_error "Unsupported operating system: $OS"
                                    read -p "Press Enter to return to menu..."
                                    return 1
                                    ;;
                            esac

                            # Check if nginx.conf exists, create if missing
                            if [ ! -f /etc/nginx/nginx.conf ]; then
                                log_warning "Nginx configuration file not found, creating default config with stream support..."
                                create_default_nginx_config
                            fi

                            # Test configuration before starting
                            if ! nginx -t &>/dev/null; then
                                log_error "Nginx configuration test failed after upgrade!"
                                echo ""
                                echo -e "${YELLOW}Configuration test output:${NC}"
                                nginx -t
                                echo ""
                                log_warning "The upgraded Nginx has configuration errors. Please fix them manually."
                                read -p "Press Enter to return to menu..."
                                return 1
                            fi

                            # Enable and start Nginx
                            systemctl enable nginx > /dev/null 2>&1
                            systemctl start nginx

                            if systemctl is-active --quiet nginx; then
                                log_success "Nginx upgraded to nginx-extras and started successfully"
                            else
                                log_error "Nginx upgrade completed but service failed to start!"
                                echo ""
                                echo -e "${YELLOW}Checking service status:${NC}"
                                systemctl status nginx.service --no-pager -l 2>&1 || true
                                echo ""
                                echo -e "${YELLOW}Error log:${NC}"
                                tail -20 /var/log/nginx/error.log 2>/dev/null || echo "  (No error log available)"
                                echo ""
                                read -p "Press Enter to return to menu..."
                                return 1
                            fi
                        else
                            # Nginx has stream modules, just start it
                            log_step "Starting Nginx service..."

                            # Check if nginx.conf exists, create if missing
                            if [ ! -f /etc/nginx/nginx.conf ]; then
                                log_warning "Nginx configuration file not found, creating default config with stream support..."
                                create_default_nginx_config
                            fi

                            # Test Nginx configuration before starting
                            if ! nginx -t &>/dev/null; then
                                log_error "Nginx configuration test failed!"
                                echo ""
                                echo -e "${YELLOW}Running configuration test:${NC}"
                                nginx -t
                                echo ""
                                echo -e "${YELLOW}Common issues:${NC}"
                                echo -e "  ${CYAN}1.${NC} Missing or incomplete stream block in /etc/nginx/nginx.conf"
                                echo -e "  ${CYAN}2.${NC} Syntax errors in configuration files"
                                echo -e "  ${CYAN}3.${NC} Conflicting server blocks or ports"
                                echo -e "  ${CYAN}4.${NC} Missing SSL certificates referenced in config"
                                echo ""
                                echo -e "${YELLOW}To fix:${NC}"
                                echo -e "  ${GREEN}•${NC} Check the configuration: ${CYAN}nginx -t${NC}"
                                echo -e "  ${GREEN}•${NC} Review error messages above"
                                echo -e "  ${GREEN}•${NC} Fix configuration files in /etc/nginx/"
                                echo -e "  ${GREEN}•${NC} Try again after fixing the issues"
                                echo ""
                                read -p "Press Enter to return to menu..."
                                return 1
                            fi

                            systemctl start nginx

                            if ! systemctl is-active --quiet nginx; then
                                log_error "Nginx failed to start!"
                                echo ""
                                echo -e "${YELLOW}Checking status:${NC}"
                                systemctl status nginx.service --no-pager -l 2>&1 || true
                                echo ""
                                echo -e "${YELLOW}Recent error logs:${NC}"
                                tail -20 /var/log/nginx/error.log 2>/dev/null || echo "  (No error log available)"
                                echo ""
                                echo -e "${YELLOW}To diagnose:${NC}"
                                echo -e "  ${CYAN}•${NC} Check status: ${GREEN}systemctl status nginx${NC}"
                                echo -e "  ${CYAN}•${NC} View logs: ${GREEN}journalctl -xeu nginx${NC}"
                                echo -e "  ${CYAN}•${NC} Error log: ${GREEN}tail /var/log/nginx/error.log${NC}"
                                echo ""
                                read -p "Press Enter to return to menu..."
                                return 1
                            fi
                        fi
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
    echo ""
    local dest=$(get_best_dest)

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
    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        echo "  Port: $PORT"
    fi
    echo ""

    echo -e "${YELLOW}What would you like to modify?${NC}"
    echo "  1. Change destination domain"
    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        echo "  2. Change port (currently: $PORT)"
        echo "  3. Regenerate UUID"
        echo "  4. Regenerate keypair"
        echo "  5. Regenerate all (UUID + destination + keypair)"
    else
        echo "  2. Regenerate UUID"
        echo "  3. Regenerate keypair"
        echo "  4. Regenerate all (UUID + destination + keypair)"
    fi
    echo "  0. Cancel"
    echo ""

    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        read -p "Choose option [0-5, or press Enter to return]: " modify_choice
    else
        read -p "Choose option [0-4, or press Enter to return]: " modify_choice
    fi

    local new_uuid="$UUID"
    local new_dest="$DEST_DOMAIN"
    local new_private_key="$PRIVATE_KEY"
    local new_public_key="$PUBLIC_KEY"
    local new_port="$PORT"

    case $modify_choice in
        1)
            # Option 1: Change destination domain (both deployment types)
            log_step "Selecting new destination domain..."
            echo ""
            new_dest=$(select_dest_interactive)
            ;;
        2)
            # Option 2: Different for no-doh vs with-doh
            if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
                # no-doh: Change port
                log_step "Changing port..."
                echo ""
                echo -e "${CYAN}Current port: ${YELLOW}${PORT}${NC}"
                echo ""
                echo -e "${YELLOW}Common ports:${NC}"
                echo "  443  - HTTPS (default, recommended)"
                echo "  8443 - Alternative HTTPS"
                echo "  2053 - Common proxy port"
                echo "  2083 - Common proxy port"
                echo "  2087 - Common proxy port"
                echo "  2096 - Common proxy port"
                echo ""
                echo -e "${YELLOW}Note:${NC} Port must be between 1-65535"
                echo -e "${YELLOW}Warning:${NC} Using non-standard ports may require additional firewall configuration"
                echo ""

                read -p "Enter new port (or press Enter to cancel): " input_port

                if [ -z "$input_port" ]; then
                    log_info "Port change cancelled"
                    return 0
                fi

                # Validate port number
                if ! [[ "$input_port" =~ ^[0-9]+$ ]] || [ "$input_port" -lt 1 ] || [ "$input_port" -gt 65535 ]; then
                    log_error "Invalid port number. Must be between 1-65535"
                    return 1
                fi

                new_port="$input_port"
                echo ""
                log_info "New port: $new_port"

                # Check if new port is open in firewall
                echo ""
                log_step "Checking firewall status for port $new_port..."
                get_firewall_status_message "$new_port"
                check_firewall_port "$new_port"
                local fw_status=$?

                if [ $fw_status -eq 1 ]; then
                    echo ""
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "${RED}⚠  WARNING: Port $new_port is BLOCKED by firewall${NC}"
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    echo -e "${YELLOW}To open the port, run one of the following commands:${NC}"

                    if command -v ufw &>/dev/null; then
                        echo -e "  ${CYAN}UFW:${NC}       sudo ufw allow ${new_port}/tcp"
                    fi
                    if command -v iptables &>/dev/null; then
                        echo -e "  ${CYAN}iptables:${NC}  sudo iptables -I INPUT -p tcp --dport ${new_port} -j ACCEPT"
                    fi
                    if command -v firewall-cmd &>/dev/null; then
                        echo -e "  ${CYAN}firewalld:${NC} sudo firewall-cmd --permanent --add-port=${new_port}/tcp && sudo firewall-cmd --reload"
                    fi
                    echo ""
                    echo -e "${YELLOW}Also check your cloud provider's security group/firewall settings!${NC}"
                    echo ""

                    read -p "Continue anyway? [Y/n, or press Enter to confirm]: " confirm
                    # Default to yes if Enter is pressed (empty input)
                    confirm=${confirm:-y}
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        log_info "Port change cancelled"
                        return 0
                    fi
                fi
            else
                # with-doh: Regenerate UUID
                log_step "Regenerating UUID..."
                new_uuid=$(generate_uuid)
                log_info "New UUID: $new_uuid"
            fi
            ;;
        3)
            # Option 3: Different for no-doh vs with-doh
            if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
                # no-doh: Regenerate UUID
                log_step "Regenerating UUID..."
                new_uuid=$(generate_uuid)
                log_info "New UUID: $new_uuid"
            else
                # with-doh: Regenerate keypair
                log_step "Regenerating keypair..."
                local keypair_output=$(generate_keypair)
                new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
                new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
                log_info "New private key: $new_private_key"
                log_info "New public key: $new_public_key"
            fi
            ;;
        4)
            # Option 4: Different for no-doh vs with-doh
            if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
                # no-doh: Regenerate keypair
                log_step "Regenerating keypair..."
                local keypair_output=$(generate_keypair)
                new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
                new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
                log_info "New private key: $new_private_key"
                log_info "New public key: $new_public_key"
            else
                # with-doh: Regenerate all
                log_step "Regenerating all parameters..."
                new_uuid=$(generate_uuid)
                echo ""
                new_dest=$(get_best_dest)
                log_info "Generating X25519 keypair..."
                local keypair_output=$(generate_keypair)
                new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
                new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
                log_info "New UUID: $new_uuid"
                log_info "New private key: $new_private_key"
                log_info "New public key: $new_public_key"
            fi
            ;;
        5)
            # Option 5: Only available for no-doh (Regenerate all)
            if [ "$DEPLOYMENT_TYPE" != "no-doh" ]; then
                log_error "Invalid option for DoH deployment"
                return 1
            fi

            # no-doh: Regenerate all
            log_step "Regenerating all parameters..."
            new_uuid=$(generate_uuid)
            echo ""
            new_dest=$(get_best_dest)
            log_info "Generating X25519 keypair..."
            local keypair_output=$(generate_keypair)
            new_private_key=$(echo "$keypair_output" | grep "Private key:" | awk -F': ' '{print $2}')
            new_public_key=$(echo "$keypair_output" | grep "Public key:" | awk -F': ' '{print $2}')
            log_info "New UUID: $new_uuid"
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
        generate_config_no_doh "$new_uuid" "$new_dest" "$new_private_key" "$new_port"
    else
        generate_config_with_doh "$new_uuid" "$new_dest" "$new_private_key"
    fi

    # Save updated deployment info
    local port="$new_port"
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
    # Client port: with-doh always uses 443 (Nginx), no-doh uses configured port
    local port="443"
    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        port="${PORT:-443}"
    fi

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
    # Client port: with-doh always uses 443 (Nginx), no-doh uses configured port
    local port="443"
    if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
        port="${PORT:-443}"
    fi

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
                    echo -e "${CYAN}Deployment Type: ${YELLOW}without DoH${NC} ${PURPLE}(Direct port ${PORT})${NC}"
                fi

                # Show port and firewall status
                if [ "$DEPLOYMENT_TYPE" = "no-doh" ]; then
                    echo -e "${CYAN}Port: ${YELLOW}${PORT}${NC}"
                    echo -n "  "
                    # Don't let firewall check exit the script with set -e
                    set +e
                    get_firewall_status_message "$PORT"
                    check_firewall_port "$PORT"
                    local fw_check_status=$?
                    set -e

                    # Additional warning if port is blocked
                    if [ $fw_check_status -eq 1 ]; then
                        echo -e "  ${YELLOW}⚠  Action needed: Open port $PORT in firewall${NC}"
                    fi
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
