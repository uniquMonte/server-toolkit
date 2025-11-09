#!/bin/bash

#######################################
# 系统更新脚本
# 支持: Ubuntu, Debian, CentOS, Fedora, Rocky Linux, AlmaLinux
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

# 更新系统
update_system() {
    detect_os

    log_info "开始更新系统..."

    case $OS in
        ubuntu|debian)
            log_info "使用 APT 包管理器更新系统..."
            export DEBIAN_FRONTEND=noninteractive

            log_info "更新软件包列表..."
            apt-get update -y

            log_info "升级已安装的软件包..."
            apt-get upgrade -y

            log_info "执行完整升级..."
            apt-get full-upgrade -y

            log_info "安装常用工具..."
            apt-get install -y \
                curl \
                wget \
                git \
                vim \
                nano \
                htop \
                net-tools \
                ca-certificates \
                gnupg \
                lsb-release \
                software-properties-common \
                apt-transport-https \
                unzip \
                zip \
                tar \
                gzip \
                bzip2

            log_info "清理无用的软件包..."
            apt-get autoremove -y
            apt-get autoclean -y

            log_success "Ubuntu/Debian 系统更新完成"
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 包管理器更新系统..."

            # 检查是否使用dnf
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi

            log_info "更新系统软件包..."
            $PKG_MANAGER update -y

            log_info "安装常用工具..."
            $PKG_MANAGER install -y \
                curl \
                wget \
                git \
                vim \
                nano \
                htop \
                net-tools \
                ca-certificates \
                gnupg \
                yum-utils \
                unzip \
                zip \
                tar \
                gzip \
                bzip2

            log_info "清理缓存..."
            $PKG_MANAGER clean all

            log_success "CentOS/RHEL/Rocky/AlmaLinux/Fedora 系统更新完成"
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    log_success "系统更新完成！"
}

# 安装 rclone
install_rclone() {
    log_info "检查 rclone 安装状态..."

    if command -v rclone &> /dev/null; then
        log_success "rclone 已安装"
        rclone version | head -n 1
        return
    fi

    log_info "开始安装 rclone..."

    # 使用官方安装脚本
    if curl -fsSL https://rclone.org/install.sh | bash; then
        log_success "rclone 安装成功"
        rclone version | head -n 1
    else
        log_error "rclone 安装失败，尝试手动安装..."

        # 手动安装方式
        detect_os
        case $OS in
            ubuntu|debian)
                apt-get install -y rclone 2>/dev/null || log_warning "从仓库安装失败，请访问 https://rclone.org 手动安装"
                ;;
            centos|rhel|rocky|almalinux|fedora)
                if command -v dnf &> /dev/null; then
                    dnf install -y rclone 2>/dev/null || log_warning "从仓库安装失败，请访问 https://rclone.org 手动安装"
                else
                    yum install -y rclone 2>/dev/null || log_warning "从仓库安装失败，请访问 https://rclone.org 手动安装"
                fi
                ;;
        esac
    fi
}

# 主函数
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi

    update_system

    # 安装 rclone
    echo ""
    read -p "是否安装 rclone (云存储同步工具)? (Y/n): " install_rclone_choice
    if [[ ! $install_rclone_choice =~ ^[Nn]$ ]]; then
        install_rclone
    fi

    # 询问是否重启
    echo ""
    log_info "所有更新已完成！"
    log_info "建议重启系统以应用所有更新"

    read -p "是否现在重启系统? (y/N): " restart_choice
    if [[ $restart_choice =~ ^[Yy]$ ]]; then
        log_info "系统将在5秒后重启..."
        sleep 5
        reboot
    fi
}

main "$@"
