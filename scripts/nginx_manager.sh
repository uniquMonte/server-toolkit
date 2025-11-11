#!/bin/bash

#######################################
# Nginx and Certbot Management Script
# Supports installation, configuration, and uninstallation of Nginx and SSL certificate tools
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        OS_VERSION=$VERSION_ID
    else
        log_error "Unable to detect operating system"
        exit 1
    fi
}

# Check if Nginx is installed
check_nginx_installed() {
    if command -v nginx &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if Certbot is installed
check_certbot_installed() {
    if command -v certbot &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install Nginx (Ubuntu/Debian)
install_nginx_debian() {
    log_info "Installing Nginx on Ubuntu/Debian..."

    # Update package index
    apt-get update

    # Install Nginx
    apt-get install -y nginx

    # Start and enable on boot
    systemctl start nginx
    systemctl enable nginx
}

# Install Nginx (CentOS/RHEL/Rocky/AlmaLinux)
install_nginx_rhel() {
    log_info "Installing Nginx on CentOS/RHEL/Rocky/AlmaLinux..."

    if command -v dnf &> /dev/null; then
        dnf install -y nginx
    else
        # EPEL repository may be needed
        yum install -y epel-release
        yum install -y nginx
    fi

    # Start and enable on boot
    systemctl start nginx
    systemctl enable nginx
}

# Configure Nginx
configure_nginx() {
    log_info "Configuring Nginx..."

    # Configure firewall
    if [ "$AUTO_INSTALL" = "true" ]; then
        fw_choice=""
        log_info "Auto-install mode: Opening HTTP/HTTPS ports in firewall..."
    else
        read -p "Open HTTP/HTTPS ports in firewall? (Y/n) (press Enter to confirm): " fw_choice
    fi
    if [[ ! $fw_choice =~ ^[Nn]$ ]]; then
        if command -v ufw &> /dev/null; then
            log_info "Configuring UFW firewall..."
            ufw allow 'Nginx Full' 2>/dev/null || {
                ufw allow 80/tcp
                ufw allow 443/tcp
            }
        elif command -v firewall-cmd &> /dev/null; then
            log_info "Configuring firewalld..."
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
        fi
    fi

    log_info "Keeping Nginx default configuration (no optimization applied)"

    # Create default site directory
    log_info "Creating default site directory..."
    mkdir -p /var/www/html

    # Detect and use correct web server user
    if id www-data &>/dev/null; then
        web_user="www-data"
        log_info "Using www-data user for web directory"
    elif id nginx &>/dev/null; then
        web_user="nginx"
        log_info "Using nginx user for web directory"
    elif id apache &>/dev/null; then
        web_user="apache"
        log_info "Using apache user for web directory"
    else
        log_warning "No web server user found, using root (not recommended)"
        web_user="root"
    fi

    chown -R ${web_user}:${web_user} /var/www/html

    # Verify installation
    log_info "Verifying Nginx installation..."
    nginx -t

    if systemctl is-active --quiet nginx; then
        log_success "Nginx is running normally"
        nginx -v
        echo ""
        log_info "Nginx status:"
        systemctl status nginx --no-pager -l
    else
        log_error "Nginx is not running properly"
    fi
}

# Install Nginx
install_nginx() {
    log_info "Starting Nginx installation..."

    if check_nginx_installed; then
        log_warning "Nginx is already installed"
        nginx -v
        return
    fi

    detect_os

    case $OS in
        ubuntu|debian)
            install_nginx_debian
            ;;

        centos|rhel|rocky|almalinux|fedora)
            install_nginx_rhel
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    configure_nginx
    log_success "Nginx installation complete!"
}

# Install Certbot
install_certbot() {
    log_info "Installing Certbot (Let's Encrypt certificate tool)..."

    if check_certbot_installed; then
        log_success "Certbot is already installed"
        certbot --version
        return
    fi

    detect_os

    case $OS in
        ubuntu|debian)
            log_info "Installing Certbot on Ubuntu/Debian..."
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Installing Certbot on CentOS/RHEL/Rocky/AlmaLinux..."
            if command -v dnf &> /dev/null; then
                dnf install -y certbot python3-certbot-nginx
            else
                yum install -y certbot python3-certbot-nginx
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    if check_certbot_installed; then
        log_success "Certbot installed successfully"
        certbot --version

        # Configure automatic renewal
        log_info "Configuring automatic certificate renewal..."
        if systemctl enable certbot-renew.timer 2>/dev/null; then
            log_success "Enabled certbot renewal timer"
        else
            # If no timer, create cron job (check for duplicates first)
            local cron_cmd="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"
            if ! crontab -l 2>/dev/null | grep -qF "certbot renew"; then
                (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
                log_success "Added certbot renewal cron job"
            else
                log_info "Certbot renewal cron job already exists"
            fi
        fi

        echo ""
        log_info "Usage instructions:"
        log_info "Request certificate: certbot --nginx -d your-domain.com"
        log_info "Renew certificate: certbot renew"
        log_info "View certificates: certbot certificates"
    else
        log_error "Certbot installation failed"
    fi
}

# Install Nginx and Certbot
install_nginx_and_certbot() {
    install_nginx
    echo ""
    install_certbot
}

# Uninstall Nginx
uninstall_nginx() {
    log_warning "Starting Nginx uninstallation..."

    if ! check_nginx_installed; then
        log_warning "Nginx is not installed, no need to uninstall"
        return
    fi

    read -p "Are you sure you want to uninstall Nginx? (Y/n) (press Enter to confirm): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Uninstallation cancelled"
        return
    fi

    detect_os

    # Stop Nginx service
    log_info "Stopping Nginx service..."
    systemctl stop nginx
    systemctl disable nginx

    # Uninstall Nginx
    case $OS in
        ubuntu|debian)
            log_info "Uninstalling Nginx using APT..."
            apt-get purge -y nginx nginx-common nginx-core
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "Uninstalling Nginx using YUM/DNF..."
            if command -v dnf &> /dev/null; then
                dnf remove -y nginx
            else
                yum remove -y nginx
            fi
            ;;

        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    # Ask about deleting configuration and data
    read -p "Delete Nginx configuration files and website data? (y/N) (press Enter to skip): " delete_data
    if [[ $delete_data =~ ^[Yy]$ ]]; then
        log_info "Deleting Nginx configuration and data..."
        rm -rf /etc/nginx
        rm -rf /var/www
        rm -rf /var/log/nginx
    fi

    # Uninstall Certbot
    if check_certbot_installed; then
        read -p "Also uninstall Certbot? (y/N) (press Enter to skip): " uninstall_certbot
        if [[ $uninstall_certbot =~ ^[Yy]$ ]]; then
            log_info "Uninstalling Certbot..."

            case $OS in
                ubuntu|debian)
                    apt-get purge -y certbot python3-certbot-nginx
                    apt-get autoremove -y
                    ;;

                centos|rhel|rocky|almalinux|fedora)
                    if command -v dnf &> /dev/null; then
                        dnf remove -y certbot python3-certbot-nginx
                    else
                        yum remove -y certbot python3-certbot-nginx
                    fi
                    ;;
            esac

            # Delete Let's Encrypt data
            read -p "Delete SSL certificate data? (y/N) (press Enter to skip): " delete_ssl
            if [[ $delete_ssl =~ ^[Yy]$ ]]; then
                rm -rf /etc/letsencrypt
                rm -rf /var/lib/letsencrypt
            fi
        fi
    fi

    if check_nginx_installed; then
        log_error "Nginx uninstallation failed"
        exit 1
    else
        log_success "Nginx uninstallation complete!"
    fi
}

# Display help
show_help() {
    echo "Usage: $0 {install|install-certbot|uninstall}"
    echo ""
    echo "Commands:"
    echo "  install          - Install Nginx"
    echo "  install-certbot  - Install Nginx and Certbot"
    echo "  uninstall        - Uninstall Nginx"
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
            install_nginx
            ;;
        install-certbot)
            install_nginx_and_certbot
            ;;
        uninstall)
            uninstall_nginx
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
