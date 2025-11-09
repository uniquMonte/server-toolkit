#!/bin/bash

#######################################
# Nginx 和 Certbot 管理脚本
# 支持安装、配置和卸载 Nginx 及 SSL 证书工具
#######################################

# 颜色定义
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

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
}

# 检查Nginx是否已安装
check_nginx_installed() {
    if command -v nginx &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查Certbot是否已安装
check_certbot_installed() {
    if command -v certbot &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装Nginx (Ubuntu/Debian)
install_nginx_debian() {
    log_info "在 Ubuntu/Debian 上安装 Nginx..."

    # 更新包索引
    apt-get update

    # 安装Nginx
    apt-get install -y nginx

    # 启动并设置开机自启
    systemctl start nginx
    systemctl enable nginx
}

# 安装Nginx (CentOS/RHEL/Rocky/AlmaLinux)
install_nginx_rhel() {
    log_info "在 CentOS/RHEL/Rocky/AlmaLinux 上安装 Nginx..."

    if command -v dnf &> /dev/null; then
        dnf install -y nginx
    else
        # 可能需要EPEL仓库
        yum install -y epel-release
        yum install -y nginx
    fi

    # 启动并设置开机自启
    systemctl start nginx
    systemctl enable nginx
}

# 配置Nginx
configure_nginx() {
    log_info "配置 Nginx..."

    # 配置防火墙
    read -p "是否在防火墙中开放 HTTP/HTTPS 端口? (Y/n): " fw_choice
    if [[ ! $fw_choice =~ ^[Nn]$ ]]; then
        if command -v ufw &> /dev/null; then
            log_info "配置 UFW 防火墙..."
            ufw allow 'Nginx Full' 2>/dev/null || {
                ufw allow 80/tcp
                ufw allow 443/tcp
            }
        elif command -v firewall-cmd &> /dev/null; then
            log_info "配置 firewalld..."
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
        fi
    fi

    # 优化Nginx配置
    read -p "是否应用推荐的 Nginx 配置优化? (Y/n): " optimize_choice
    if [[ ! $optimize_choice =~ ^[Nn]$ ]]; then
        log_info "优化 Nginx 配置..."

        # 备份原配置
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

        # 创建优化配置
        cat > /etc/nginx/conf.d/optimization.conf <<'EOF'
# 性能优化
client_max_body_size 100M;
client_body_buffer_size 128k;
client_header_buffer_size 1k;
large_client_header_buffers 4 16k;

# Gzip压缩
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
gzip_disable "msie6";

# 安全headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;

# 隐藏Nginx版本
server_tokens off;
EOF

        systemctl reload nginx
        log_success "Nginx 配置优化完成"
    fi

    # 创建默认站点目录
    log_info "创建默认站点目录..."
    mkdir -p /var/www/html
    chown -R www-data:www-data /var/www/html 2>/dev/null || chown -R nginx:nginx /var/www/html

    # 验证安装
    log_info "验证 Nginx 安装..."
    nginx -t

    if systemctl is-active --quiet nginx; then
        log_success "Nginx 运行正常"
        nginx -v
        echo ""
        log_info "Nginx 状态:"
        systemctl status nginx --no-pager -l
    else
        log_error "Nginx 未正常运行"
    fi
}

# 安装Nginx
install_nginx() {
    log_info "开始安装 Nginx..."

    if check_nginx_installed; then
        log_warning "Nginx 已经安装"
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
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    configure_nginx
    log_success "Nginx 安装完成！"
}

# 安装Certbot
install_certbot() {
    log_info "安装 Certbot (Let's Encrypt 证书工具)..."

    if check_certbot_installed; then
        log_success "Certbot 已经安装"
        certbot --version
        return
    fi

    detect_os

    case $OS in
        ubuntu|debian)
            log_info "在 Ubuntu/Debian 上安装 Certbot..."
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "在 CentOS/RHEL/Rocky/AlmaLinux 上安装 Certbot..."
            if command -v dnf &> /dev/null; then
                dnf install -y certbot python3-certbot-nginx
            else
                yum install -y certbot python3-certbot-nginx
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    if check_certbot_installed; then
        log_success "Certbot 安装成功"
        certbot --version

        # 配置自动续期
        log_info "配置证书自动续期..."
        systemctl enable certbot-renew.timer 2>/dev/null || {
            # 如果没有timer，创建cron任务
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        }

        echo ""
        log_info "使用说明:"
        log_info "申请证书: certbot --nginx -d your-domain.com"
        log_info "续期证书: certbot renew"
        log_info "查看证书: certbot certificates"
    else
        log_error "Certbot 安装失败"
    fi
}

# 安装Nginx和Certbot
install_nginx_and_certbot() {
    install_nginx
    echo ""
    install_certbot
}

# 卸载Nginx
uninstall_nginx() {
    log_warning "开始卸载 Nginx..."

    if ! check_nginx_installed; then
        log_warning "Nginx 未安装，无需卸载"
        return
    fi

    read -p "确定要卸载 Nginx 吗? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return
    fi

    detect_os

    # 停止Nginx服务
    log_info "停止 Nginx 服务..."
    systemctl stop nginx
    systemctl disable nginx

    # 卸载Nginx
    case $OS in
        ubuntu|debian)
            log_info "使用 APT 卸载 Nginx..."
            apt-get purge -y nginx nginx-common nginx-core
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 卸载 Nginx..."
            if command -v dnf &> /dev/null; then
                dnf remove -y nginx
            else
                yum remove -y nginx
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    # 询问是否删除配置和数据
    read -p "是否删除 Nginx 配置文件和网站数据? (y/N): " delete_data
    if [[ $delete_data =~ ^[Yy]$ ]]; then
        log_info "删除 Nginx 配置和数据..."
        rm -rf /etc/nginx
        rm -rf /var/www
        rm -rf /var/log/nginx
    fi

    # 卸载Certbot
    if check_certbot_installed; then
        read -p "是否同时卸载 Certbot? (y/N): " uninstall_certbot
        if [[ $uninstall_certbot =~ ^[Yy]$ ]]; then
            log_info "卸载 Certbot..."

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

            # 删除Let's Encrypt数据
            read -p "是否删除 SSL 证书数据? (y/N): " delete_ssl
            if [[ $delete_ssl =~ ^[Yy]$ ]]; then
                rm -rf /etc/letsencrypt
                rm -rf /var/lib/letsencrypt
            fi
        fi
    fi

    if check_nginx_installed; then
        log_error "Nginx 卸载失败"
        exit 1
    else
        log_success "Nginx 卸载完成！"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 {install|install-certbot|uninstall}"
    echo ""
    echo "命令:"
    echo "  install          - 安装 Nginx"
    echo "  install-certbot  - 安装 Nginx 和 Certbot"
    echo "  uninstall        - 卸载 Nginx"
    echo ""
}

# 主函数
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
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
