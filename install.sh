#!/bin/bash

#######################################
# VPS一键部署脚本
# 作者: uniquMonte
# 用途: 快速部署新购VPS的常用工具
#######################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

# 日志函数
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 打印横幅
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           VPS 一键部署脚本 v1.0                          ║
║           VPS Quick Setup Script                          ║
║                                                           ║
║           支持的组件:                                     ║
║           - 系统更新 (System Update)                      ║
║           - UFW 防火墙 (Firewall)                        ║
║           - Docker 容器引擎                               ║
║           - Nginx + Certbot 证书工具                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: ${OS} ${OS_VERSION}"

    # 检查是否为支持的操作系统
    case $OS in
        ubuntu|debian|centos|fedora|rhel|rocky|almalinux)
            log_success "操作系统支持"
            ;;
        *)
            log_warning "未经测试的操作系统，可能会出现问题"
            ;;
    esac
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 下载脚本文件（如果通过curl执行）
download_scripts() {
    if [ ! -d "$SCRIPTS_PATH" ]; then
        log_info "检测到通过远程执行，正在下载脚本文件..."

        REPO_URL="https://raw.githubusercontent.com/uniquMonte/vps-setup/main"
        TEMP_DIR="/tmp/vps-setup-$$"
        mkdir -p "$TEMP_DIR/scripts"

        SCRIPT_DIR="$TEMP_DIR"
        SCRIPTS_PATH="${SCRIPT_DIR}/scripts"

        # 下载所有脚本文件
        scripts=("system_update.sh" "ufw_manager.sh" "docker_manager.sh" "nginx_manager.sh")

        for script in "${scripts[@]}"; do
            log_info "下载 ${script}..."
            if ! curl -fsSL "${REPO_URL}/scripts/${script}" -o "${SCRIPTS_PATH}/${script}"; then
                log_error "下载 ${script} 失败"
                exit 1
            fi
            chmod +x "${SCRIPTS_PATH}/${script}"
        done

        log_success "脚本文件下载完成"
    fi
}

# 系统更新
system_update() {
    log_step "执行系统更新..."
    if [ -f "${SCRIPTS_PATH}/system_update.sh" ]; then
        bash "${SCRIPTS_PATH}/system_update.sh"
    else
        log_error "找不到系统更新脚本"
    fi
}

# UFW管理菜单
ufw_menu() {
    echo ""
    log_step "UFW 防火墙管理"
    echo -e "${CYAN}1.${NC} 仅安装 UFW (不配置规则)"
    echo -e "${CYAN}2.${NC} 安装 UFW 并开启常用端口 (22, 80, 443)"
    echo -e "${CYAN}3.${NC} 安装 UFW 并自定义配置"
    echo -e "${CYAN}4.${NC} 卸载 UFW"
    echo -e "${CYAN}5.${NC} 返回主菜单"
    echo ""
    read -p "请选择操作 [1-5]: " ufw_choice

    case $ufw_choice in
        1)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-only
            ;;
        2)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common
            ;;
        3)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" install-custom
            ;;
        4)
            bash "${SCRIPTS_PATH}/ufw_manager.sh" uninstall
            ;;
        5)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# Docker管理菜单
docker_menu() {
    echo ""
    log_step "Docker 容器引擎管理"
    echo -e "${CYAN}1.${NC} 安装 Docker"
    echo -e "${CYAN}2.${NC} 安装 Docker + Docker Compose"
    echo -e "${CYAN}3.${NC} 卸载 Docker"
    echo -e "${CYAN}4.${NC} 返回主菜单"
    echo ""
    read -p "请选择操作 [1-4]: " docker_choice

    case $docker_choice in
        1)
            bash "${SCRIPTS_PATH}/docker_manager.sh" install
            ;;
        2)
            bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose
            ;;
        3)
            bash "${SCRIPTS_PATH}/docker_manager.sh" uninstall
            ;;
        4)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# Nginx管理菜单
nginx_menu() {
    echo ""
    log_step "Nginx + Certbot 管理"
    echo -e "${CYAN}1.${NC} 安装 Nginx"
    echo -e "${CYAN}2.${NC} 安装 Nginx + Certbot"
    echo -e "${CYAN}3.${NC} 卸载 Nginx"
    echo -e "${CYAN}4.${NC} 返回主菜单"
    echo ""
    read -p "请选择操作 [1-4]: " nginx_choice

    case $nginx_choice in
        1)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" install
            ;;
        2)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot
            ;;
        3)
            bash "${SCRIPTS_PATH}/nginx_manager.sh" uninstall
            ;;
        4)
            return
            ;;
        *)
            log_error "无效选择"
            ;;
    esac
}

# 一键安装所有组件
install_all() {
    log_step "开始一键安装所有组件..."

    # 系统更新
    system_update

    # 安装UFW并配置常用端口
    bash "${SCRIPTS_PATH}/ufw_manager.sh" install-common

    # 安装Docker和Docker Compose
    bash "${SCRIPTS_PATH}/docker_manager.sh" install-compose

    # 安装Nginx和Certbot
    bash "${SCRIPTS_PATH}/nginx_manager.sh" install-certbot

    log_success "所有组件安装完成！"
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${CYAN}           主菜单 Main Menu            ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 一键安装所有组件"
        echo -e "${GREEN}2.${NC} 系统更新"
        echo -e "${GREEN}3.${NC} UFW 防火墙管理"
        echo -e "${GREEN}4.${NC} Docker 管理"
        echo -e "${GREEN}5.${NC} Nginx 管理"
        echo -e "${RED}0.${NC} 退出"
        echo -e "${CYAN}═══════════════════════════════════════${NC}"
        echo ""
        read -p "请选择操作 [0-5]: " choice

        case $choice in
            1)
                install_all
                ;;
            2)
                system_update
                ;;
            3)
                ufw_menu
                ;;
            4)
                docker_menu
                ;;
            5)
                nginx_menu
                ;;
            0)
                log_info "感谢使用！"
                exit 0
                ;;
            *)
                log_error "无效选择，请重新输入"
                ;;
        esac
    done
}

# 主函数
main() {
    # 清屏
    clear

    # 打印横幅
    print_banner

    # 检查root权限
    check_root

    # 检测操作系统
    detect_os

    # 下载脚本（如果需要）
    download_scripts

    # 显示主菜单
    main_menu
}

# 执行主函数
main "$@"
