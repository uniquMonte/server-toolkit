#!/bin/bash

#######################################
# Docker 管理脚本
# 支持安装、配置和卸载 Docker 及 Docker Compose
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

# 检查Docker是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查Docker Compose是否已安装
check_compose_installed() {
    if docker compose version &> /dev/null 2>&1; then
        return 0
    elif command -v docker-compose &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 安装Docker (Ubuntu/Debian)
install_docker_debian() {
    log_info "在 Ubuntu/Debian 上安装 Docker..."

    # 卸载旧版本
    log_info "移除旧版本..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # 更新包索引
    log_info "更新软件包索引..."
    apt-get update

    # 安装必要的包
    log_info "安装依赖包..."
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # 添加Docker官方GPG密钥
    log_info "添加 Docker GPG 密钥..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${OS}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # 设置仓库
    log_info "设置 Docker 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 更新包索引
    apt-get update

    # 安装Docker Engine
    log_info "安装 Docker Engine..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# 安装Docker (CentOS/RHEL/Rocky/AlmaLinux)
install_docker_rhel() {
    log_info "在 CentOS/RHEL/Rocky/AlmaLinux 上安装 Docker..."

    # 卸载旧版本
    log_info "移除旧版本..."
    if command -v dnf &> /dev/null; then
        dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    else
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    fi

    # 安装必要的包
    log_info "安装依赖包..."
    if command -v dnf &> /dev/null; then
        dnf install -y yum-utils
    else
        yum install -y yum-utils
    fi

    # 设置仓库
    log_info "设置 Docker 仓库..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    # 安装Docker Engine
    log_info "安装 Docker Engine..."
    if command -v dnf &> /dev/null; then
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
}

# 配置Docker
configure_docker() {
    log_info "配置 Docker..."

    # 启动Docker服务
    log_info "启动 Docker 服务..."
    systemctl start docker
    systemctl enable docker

    # 配置Docker镜像加速（可选）
    read -p "是否配置 Docker 镜像加速? (y/N): " mirror_choice
    if [[ $mirror_choice =~ ^[Yy]$ ]]; then
        log_info "配置 Docker 镜像加速..."

        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

        systemctl daemon-reload
        systemctl restart docker
        log_success "镜像加速配置完成"
    fi

    # 添加当前用户到docker组（如果不是root）
    if [ "$SUDO_USER" ]; then
        log_info "添加用户 $SUDO_USER 到 docker 组..."
        usermod -aG docker $SUDO_USER
        log_info "注意: 需要重新登录才能使非root用户运行docker命令"
    fi

    # 验证安装
    log_info "验证 Docker 安装..."
    docker --version

    if docker run hello-world &> /dev/null; then
        log_success "Docker 安装成功！"
    else
        log_warning "Docker 安装完成，但测试运行失败"
    fi
}

# 安装Docker
install_docker() {
    log_info "开始安装 Docker..."

    if check_docker_installed; then
        log_warning "Docker 已经安装"
        docker --version
        return
    fi

    detect_os

    case $OS in
        ubuntu|debian)
            install_docker_debian
            ;;

        centos|rhel|rocky|almalinux)
            install_docker_rhel
            ;;

        fedora)
            install_docker_rhel
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    configure_docker
}

# 安装Docker Compose
install_compose() {
    if check_compose_installed; then
        log_success "Docker Compose 已经安装"
        docker compose version
        return
    fi

    log_info "Docker Compose 插件应该已经随 Docker 一起安装"
    log_info "如果没有安装，将尝试安装..."

    detect_os

    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y docker-compose-plugin
            ;;

        centos|rhel|rocky|almalinux|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y docker-compose-plugin
            else
                yum install -y docker-compose-plugin
            fi
            ;;
    esac

    if check_compose_installed; then
        log_success "Docker Compose 安装成功"
        docker compose version
    else
        log_error "Docker Compose 安装失败"
    fi
}

# 安装Docker和Docker Compose
install_docker_and_compose() {
    install_docker
    install_compose
}

# 卸载Docker
uninstall_docker() {
    log_warning "开始卸载 Docker..."

    if ! check_docker_installed; then
        log_warning "Docker 未安装，无需卸载"
        return
    fi

    read -p "确定要卸载 Docker 吗? 这将删除所有容器、镜像和数据 (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        return
    fi

    detect_os

    # 停止所有运行的容器
    log_info "停止所有运行的容器..."
    docker stop $(docker ps -aq) 2>/dev/null || true

    # 删除所有容器
    log_info "删除所有容器..."
    docker rm $(docker ps -aq) 2>/dev/null || true

    # 删除所有镜像
    log_info "删除所有镜像..."
    docker rmi $(docker images -q) 2>/dev/null || true

    # 停止Docker服务
    log_info "停止 Docker 服务..."
    systemctl stop docker
    systemctl disable docker

    # 卸载Docker
    case $OS in
        ubuntu|debian)
            log_info "使用 APT 卸载 Docker..."
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            apt-get autoremove -y
            ;;

        centos|rhel|rocky|almalinux|fedora)
            log_info "使用 YUM/DNF 卸载 Docker..."
            if command -v dnf &> /dev/null; then
                dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            else
                yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;

        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    # 删除Docker数据
    read -p "是否删除所有 Docker 数据? (y/N): " delete_data
    if [[ $delete_data =~ ^[Yy]$ ]]; then
        log_info "删除 Docker 数据..."
        rm -rf /var/lib/docker
        rm -rf /var/lib/containerd
        rm -rf /etc/docker
        rm -rf /etc/apt/keyrings/docker.gpg
        rm -rf /etc/apt/sources.list.d/docker.list
    fi

    if check_docker_installed; then
        log_error "Docker 卸载失败"
        exit 1
    else
        log_success "Docker 卸载完成！"
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 {install|install-compose|uninstall}"
    echo ""
    echo "命令:"
    echo "  install          - 安装 Docker"
    echo "  install-compose  - 安装 Docker 和 Docker Compose"
    echo "  uninstall        - 卸载 Docker"
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
            install_docker
            ;;
        install-compose)
            install_docker_and_compose
            ;;
        uninstall)
            uninstall_docker
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
