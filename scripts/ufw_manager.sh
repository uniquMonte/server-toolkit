#!/bin/bash

#######################################
# UFW 防火墙管理脚本
# 支持安装、配置和卸载
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
    else
        log_error "无法检测操作系统"
        exit 1
    fi
}

# 检查UFW是否已安装
check_ufw_installed() {
    if command -v ufw &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 仅安装UFW（不配置）
install_ufw_base() {
    log_info "开始安装 UFW 防火墙..."

    detect_os

    if check_ufw_installed; then
        log_warning "UFW 已经安装"
        ufw --version
        return 0
    fi

    case $OS in
        ubuntu|debian)
            log_info "使用 APT 安装 UFW..."
            apt-get update
            apt-get install -y ufw
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 安装 UFW..."
            if command -v dnf &> /dev/null; then
                dnf install -y ufw
            else
                # EPEL仓库可能需要先安装
                yum install -y epel-release
                yum install -y ufw
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    if check_ufw_installed; then
        log_success "UFW 安装成功"
        ufw --version
        return 0
    else
        log_error "UFW 安装失败"
        exit 1
    fi
}

# 仅安装UFW，不配置规则
install_only() {
    install_ufw_base
    log_success "UFW 已安装，但未配置规则"
    log_info "提示: UFW 未启用，你可以稍后手动配置规则"
}

# 安装UFW并配置常用端口（22, 80, 443）
install_common() {
    install_ufw_base

    log_info "配置常用端口..."
    configure_ufw_common
}

# 安装UFW并自定义配置
install_custom() {
    install_ufw_base

    log_info "开始自定义配置..."
    configure_ufw_custom
}

# 配置常用端口（22, 80, 443）
configure_ufw_common() {
    log_info "配置 UFW 防火墙规则 (常用端口)..."

    # 重置UFW规则
    log_info "重置现有规则..."
    ufw --force reset

    # 设置默认策略
    log_info "设置默认策略..."
    ufw default deny incoming
    ufw default allow outgoing

    # 询问SSH端口
    read -p "请输入SSH端口 (默认: 22): " ssh_port
    ssh_port=${ssh_port:-22}

    log_info "允许 SSH 端口 ${ssh_port}..."
    ufw allow ${ssh_port}/tcp comment 'SSH'

    # 自动开放 HTTP 和 HTTPS
    log_info "允许 HTTP 端口 80..."
    ufw allow 80/tcp comment 'HTTP'

    log_info "允许 HTTPS 端口 443..."
    ufw allow 443/tcp comment 'HTTPS'

    # 启用UFW
    log_info "启用 UFW 防火墙..."
    ufw --force enable

    # 显示状态
    log_success "UFW 配置完成！当前状态："
    ufw status verbose

    # 设置开机自启
    log_info "设置开机自启..."
    systemctl enable ufw

    log_success "UFW 防火墙配置完成！已开放端口: ${ssh_port}(SSH), 80(HTTP), 443(HTTPS)"
}

# 自定义配置UFW
configure_ufw_custom() {
    log_info "配置 UFW 防火墙规则 (自定义模式)..."

    # 重置UFW规则
    log_info "重置现有规则..."
    ufw --force reset

    # 设置默认策略
    log_info "设置默认策略..."
    ufw default deny incoming
    ufw default allow outgoing

    # 询问SSH端口
    read -p "请输入SSH端口 (默认: 22): " ssh_port
    ssh_port=${ssh_port:-22}

    log_info "允许 SSH 端口 ${ssh_port}..."
    ufw allow ${ssh_port}/tcp comment 'SSH'

    # 询问是否开放HTTP/HTTPS
    read -p "是否开放 HTTP (80) 端口? (Y/n): " http_choice
    if [[ ! $http_choice =~ ^[Nn]$ ]]; then
        log_info "允许 HTTP 端口 80..."
        ufw allow 80/tcp comment 'HTTP'
    fi

    read -p "是否开放 HTTPS (443) 端口? (Y/n): " https_choice
    if [[ ! $https_choice =~ ^[Nn]$ ]]; then
        log_info "允许 HTTPS 端口 443..."
        ufw allow 443/tcp comment 'HTTPS'
    fi

    # 询问是否添加自定义端口
    while true; do
        read -p "是否需要开放其他端口? (y/N): " custom_choice
        if [[ $custom_choice =~ ^[Yy]$ ]]; then
            read -p "请输入端口号: " custom_port
            read -p "协议 (tcp/udp/both, 默认tcp): " protocol
            protocol=${protocol:-tcp}

            if [ "$protocol" == "both" ]; then
                ufw allow ${custom_port} comment 'Custom'
            else
                ufw allow ${custom_port}/${protocol} comment 'Custom'
            fi
            log_success "端口 ${custom_port} (${protocol}) 已开放"
        else
            break
        fi
    done

    # 启用UFW
    log_info "启用 UFW 防火墙..."
    ufw --force enable

    # 显示状态
    log_success "UFW 配置完成！当前状态："
    ufw status verbose

    # 设置开机自启
    log_info "设置开机自启..."
    systemctl enable ufw

    log_success "UFW 防火墙安装并配置完成！"
}

# 卸载UFW
uninstall_ufw() {
    log_warning "开始卸载 UFW 防火墙..."

    if ! check_ufw_installed; then
        log_warning "UFW 未安装，无需卸载"
        return
    fi

    read -p "确定要卸载 UFW 吗? 这将移除所有防火墙规则 (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return
    fi

    detect_os

    # 停止并禁用UFW
    log_info "停止 UFW 服务..."
    ufw --force disable
    systemctl stop ufw
    systemctl disable ufw

    # 卸载UFW
    case $OS in
        ubuntu|debian)
            log_info "使用 APT 卸载 UFW..."
            apt-get purge -y ufw
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 卸载 UFW..."
            if command -v dnf &> /dev/null; then
                dnf remove -y ufw
            else
                yum remove -y ufw
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    # 删除配置文件
    log_info "删除配置文件..."
    rm -rf /etc/ufw
    rm -f /etc/default/ufw

    if check_ufw_installed; then
        log_error "UFW 卸载失败"
        exit 1
    else
        log_success "UFW 卸载完成！"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 {install-only|install-common|install-custom|uninstall}"
    echo ""
    echo "命令:"
    echo "  install-only    - 仅安装 UFW，不配置规则"
    echo "  install-common  - 安装 UFW 并开启常用端口 (22, 80, 443)"
    echo "  install-custom  - 安装 UFW 并自定义配置"
    echo "  uninstall       - 卸载 UFW"
    echo ""
}

# 主函数
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi

    case "$1" in
        install-only)
            install_only
            ;;
        install-common)
            install_common
            ;;
        install-custom)
            install_custom
            ;;
        uninstall)
            uninstall_ufw
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
