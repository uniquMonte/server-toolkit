#!/bin/bash

#######################################
# Fail2ban 管理脚本
# 防止SSH暴力破解和其他攻击
#######################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
    else
        log_error "无法检测操作系统"
        exit 1
    fi
}

# 检查Fail2ban是否已安装
check_fail2ban_installed() {
    if command -v fail2ban-client &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 显示Fail2ban介绍
show_fail2ban_info() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Fail2ban - 入侵防御系统${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  🛡️  防止SSH暴力破解攻击"
    echo -e "  🚫 自动封禁恶意IP地址"
    echo -e "  📊 支持多种服务保护 (SSH, Nginx, Apache等)"
    echo -e "  ⏱️  可配置封禁时间和尝试次数"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 安装Fail2ban
install_fail2ban() {
    show_fail2ban_info

    if check_fail2ban_installed; then
        log_warning "Fail2ban 已经安装"
        fail2ban-client version
        return
    fi

    log_info "开始安装 Fail2ban..."
    detect_os

    case $OS in
        ubuntu|debian)
            log_info "使用 APT 安装 Fail2ban..."
            apt-get update
            apt-get install -y fail2ban
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 安装 Fail2ban..."
            if command -v dnf &> /dev/null; then
                dnf install -y epel-release
                dnf install -y fail2ban fail2ban-systemd
            else
                yum install -y epel-release
                yum install -y fail2ban fail2ban-systemd
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    if check_fail2ban_installed; then
        log_success "Fail2ban 安装成功"
        configure_fail2ban
    else
        log_error "Fail2ban 安装失败"
        exit 1
    fi
}

# 配置Fail2ban
configure_fail2ban() {
    log_info "配置 Fail2ban..."

    # 创建本地配置文件
    log_info "创建本地配置文件..."

    # 询问SSH端口
    read -p "请输入SSH端口 (默认: 22): " ssh_port
    ssh_port=${ssh_port:-22}

    # 询问封禁时间
    read -p "封禁时间(分钟，默认: 60): " ban_time
    ban_time=${ban_time:-60}
    ban_time=$((ban_time * 60))  # 转换为秒

    # 询问查找时间
    read -p "查找时间窗口(分钟，默认: 10): " find_time
    find_time=${find_time:-10}
    find_time=$((find_time * 60))  # 转换为秒

    # 询问最大尝试次数
    read -p "最大失败尝试次数 (默认: 5): " max_retry
    max_retry=${max_retry:-5}

    # 创建jail.local配置
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
# 封禁时间（秒）
bantime = ${ban_time}

# 查找时间窗口（秒）
findtime = ${find_time}

# 最大尝试次数
maxretry = ${max_retry}

# 忽略的IP（本机和内网）
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

# 封禁动作
banaction = iptables-multiport
banaction_allports = iptables-allports

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
logpath = /var/log/auth.log
backend = systemd
maxretry = ${max_retry}
EOF

    # 根据系统调整日志路径
    if [[ "$OS" =~ ^(centos|rhel|rocky|almalinux|fedora)$ ]]; then
        sed -i 's|/var/log/auth.log|/var/log/secure|g' /etc/fail2ban/jail.local
    fi

    log_success "配置文件已创建"

    # 启动Fail2ban
    log_info "启动 Fail2ban 服务..."
    systemctl enable fail2ban
    systemctl start fail2ban

    # 等待服务启动
    sleep 2

    # 验证状态
    if systemctl is-active --quiet fail2ban; then
        log_success "Fail2ban 安装并配置完成！"
        echo ""
        log_info "配置摘要:"
        echo -e "  SSH端口: ${GREEN}${ssh_port}${NC}"
        echo -e "  封禁时间: ${GREEN}$((ban_time / 60)) 分钟${NC}"
        echo -e "  查找时间: ${GREEN}$((find_time / 60)) 分钟${NC}"
        echo -e "  最大尝试: ${GREEN}${max_retry} 次${NC}"
        echo ""
        log_info "查看状态: fail2ban-client status sshd"
        log_info "解封IP: fail2ban-client set sshd unbanip <IP>"
    else
        log_error "Fail2ban 启动失败"
        systemctl status fail2ban
    fi
}

# 显示Fail2ban状态
show_status() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban 未安装"
        return
    fi

    echo ""
    log_info "Fail2ban 服务状态:"
    systemctl status fail2ban --no-pager -l

    echo ""
    log_info "Fail2ban 监狱状态:"
    fail2ban-client status

    echo ""
    log_info "SSH 监狱详细信息:"
    fail2ban-client status sshd 2>/dev/null || log_warning "SSH监狱未启用"
}

# 解封IP
unban_ip() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban 未安装"
        return
    fi

    read -p "请输入要解封的IP地址: " ip_address

    if [ -z "$ip_address" ]; then
        log_error "IP地址不能为空"
        return
    fi

    log_info "正在解封 IP: ${ip_address}..."

    if fail2ban-client set sshd unbanip "$ip_address" 2>/dev/null; then
        log_success "IP ${ip_address} 已解封"
    else
        log_error "解封失败，IP可能未被封禁"
    fi
}

# 查看被封禁的IP
show_banned_ips() {
    if ! check_fail2ban_installed; then
        log_error "Fail2ban 未安装"
        return
    fi

    echo ""
    log_info "当前被封禁的IP地址:"

    banned=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:" | cut -d: -f2)

    if [ -z "$banned" ] || [ "$banned" == " " ]; then
        echo "  暂无被封禁的IP"
    else
        echo "$banned" | tr ' ' '\n' | grep -v '^$' | while read ip; do
            echo -e "  ${RED}${ip}${NC}"
        done
    fi
}

# 卸载Fail2ban
uninstall_fail2ban() {
    log_warning "开始卸载 Fail2ban..."

    if ! check_fail2ban_installed; then
        log_warning "Fail2ban 未安装，无需卸载"
        return
    fi

    read -p "确定要卸载 Fail2ban 吗? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return
    fi

    detect_os

    # 停止服务
    log_info "停止 Fail2ban 服务..."
    systemctl stop fail2ban
    systemctl disable fail2ban

    # 卸载
    case $OS in
        ubuntu|debian)
            log_info "使用 APT 卸载 Fail2ban..."
            apt-get purge -y fail2ban
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 卸载 Fail2ban..."
            if command -v dnf &> /dev/null; then
                dnf remove -y fail2ban fail2ban-systemd
            else
                yum remove -y fail2ban fail2ban-systemd
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    # 删除配置文件
    read -p "是否删除配置文件? (y/N): " delete_config
    if [[ $delete_config =~ ^[Yy]$ ]]; then
        log_info "删除配置文件..."
        rm -rf /etc/fail2ban
    fi

    if check_fail2ban_installed; then
        log_error "Fail2ban 卸载失败"
    else
        log_success "Fail2ban 卸载完成！"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 {install|status|unban|show-banned|uninstall}"
    echo ""
    echo "命令:"
    echo "  install      - 安装并配置 Fail2ban"
    echo "  status       - 查看 Fail2ban 状态"
    echo "  unban        - 解封指定IP地址"
    echo "  show-banned  - 查看被封禁的IP列表"
    echo "  uninstall    - 卸载 Fail2ban"
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
            install_fail2ban
            ;;
        status)
            show_status
            ;;
        unban)
            unban_ip
            ;;
        show-banned)
            show_banned_ips
            ;;
        uninstall)
            uninstall_fail2ban
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
