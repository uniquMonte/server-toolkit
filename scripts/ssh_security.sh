#!/bin/bash

#######################################
# SSH 安全配置脚本
# 配置SSH密钥登录、禁用密码登录等
#######################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# 显示SSH安全介绍
show_ssh_security_info() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}║              SSH 安全配置工具                            ║${NC}"
    echo -e "${CYAN}║              SSH Security Configuration                   ║${NC}"
    echo -e "${CYAN}║                                                           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}安全措施:${NC}"
    echo -e "  🔑 ${GREEN}密钥登录${NC}      : 使用SSH密钥对进行身份验证"
    echo -e "  🚫 ${GREEN}禁用密码${NC}      : 禁止使用密码登录root账户"
    echo -e "  🔢 ${GREEN}修改端口${NC}      : 更改默认SSH端口(22)"
    echo -e "  ⏱️  ${GREEN}超时设置${NC}      : 配置连接超时时间"
    echo ""
    echo -e "${YELLOW}⚠️  重要提示:${NC}"
    echo -e "  1. 配置前请确保已有其他登录方式（如控制台）"
    echo -e "  2. 修改配置前会自动备份原配置文件"
    echo -e "  3. 配置完成后请先测试新连接，确认无误再断开当前连接"
    echo -e "  4. 如果配置错误导致无法登录，可通过VPS控制台恢复"
    echo ""
}

# 备份SSH配置
backup_ssh_config() {
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "备份SSH配置到: ${backup_file}"
    cp /etc/ssh/sshd_config "$backup_file"
    log_success "配置文件已备份"
}

# 配置SSH密钥登录
setup_ssh_key() {
    show_ssh_security_info

    log_info "配置 SSH 密钥登录..."

    # 询问用户名
    read -p "请输入要配置密钥的用户名 (默认: root): " username
    username=${username:-root}

    # 确定用户home目录
    if [ "$username" == "root" ]; then
        user_home="/root"
    else
        user_home="/home/$username"

        # 检查用户是否存在
        if ! id "$username" &>/dev/null; then
            log_error "用户 $username 不存在"
            read -p "是否创建该用户? (y/N): " create_user
            if [[ $create_user =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$username"
                passwd "$username"
                log_success "用户 $username 已创建"
            else
                return
            fi
        fi
    fi

    # 创建.ssh目录
    ssh_dir="${user_home}/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # 检查是否已有authorized_keys
    authorized_keys="${ssh_dir}/authorized_keys"

    if [ -f "$authorized_keys" ] && [ -s "$authorized_keys" ]; then
        log_warning "检测到已存在的SSH密钥"
        cat "$authorized_keys"
        echo ""
        read -p "是否要添加新的密钥? (y/N): " add_new
        if [[ ! $add_new =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    echo ""
    log_info "请选择密钥配置方式:"
    echo "1. 粘贴现有的公钥"
    echo "2. 生成新的密钥对"
    echo "3. 从文件导入公钥"
    read -p "请选择 [1-3]: " key_method

    case $key_method in
        1)
            # 粘贴公钥
            echo ""
            log_info "请粘贴你的SSH公钥（通常在本地的 ~/.ssh/id_rsa.pub 文件中）:"
            read -p "公钥内容: " pub_key

            if [ -z "$pub_key" ]; then
                log_error "公钥不能为空"
                return
            fi

            echo "$pub_key" >> "$authorized_keys"
            log_success "公钥已添加"
            ;;

        2)
            # 生成新密钥对
            log_warning "注意: 这将在服务器上生成密钥对，私钥需要下载到本地"
            read -p "确认生成新密钥对? (y/N): " confirm

            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                return
            fi

            key_file="${ssh_dir}/id_rsa_${username}_$(date +%Y%m%d)"
            ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "${username}@$(hostname)"

            cat "${key_file}.pub" >> "$authorized_keys"

            echo ""
            log_success "密钥对已生成"
            log_warning "私钥位置: ${key_file}"
            log_warning "请立即下载私钥到本地，并删除服务器上的私钥文件！"
            echo ""
            log_info "私钥内容（请复制保存）:"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            cat "$key_file"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            read -p "已保存私钥? (y/N): " saved
            if [[ $saved =~ ^[Yy]$ ]]; then
                rm -f "$key_file"
                log_success "服务器私钥已删除"
            fi
            ;;

        3)
            # 从文件导入
            read -p "请输入公钥文件的完整路径: " key_file_path

            if [ ! -f "$key_file_path" ]; then
                log_error "文件不存在: $key_file_path"
                return
            fi

            cat "$key_file_path" >> "$authorized_keys"
            log_success "公钥已从文件导入"
            ;;

        *)
            log_error "无效选择"
            return
            ;;
    esac

    # 设置正确的权限
    chmod 600 "$authorized_keys"
    chown -R ${username}:${username} "$ssh_dir"

    log_success "SSH密钥配置完成！"
    echo ""
    log_info "下一步:"
    echo "  1. 使用新密钥测试SSH连接"
    echo "  2. 确认可以正常登录后，再禁用密码登录"
}

# 禁用root密码登录
disable_password_login() {
    show_ssh_security_info

    log_warning "准备禁用 root 密码登录..."
    echo ""
    log_warning "⚠️  请确认:"
    echo "  1. 已经配置好SSH密钥登录"
    echo "  2. 已经测试过密钥登录能够正常使用"
    echo "  3. 有其他方式（如VPS控制台）可以访问服务器"
    echo ""
    read -p "确认已满足以上条件? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "取消操作"
        return
    fi

    # 备份配置
    backup_ssh_config

    # 修改配置
    log_info "修改 SSH 配置..."

    # 禁用密码认证
    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    fi

    # 禁用root密码登录（但允许密钥登录）
    if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    else
        echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
    fi

    # 禁用空密码
    if grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config; then
        sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    else
        echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
    fi

    # 启用公钥认证
    if grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    else
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi

    # 测试配置
    log_info "测试 SSH 配置..."
    if sshd -t; then
        log_success "配置文件语法正确"

        # 重启SSH服务
        log_info "重启 SSH 服务..."
        systemctl restart sshd

        log_success "SSH密码登录已禁用！"
        echo ""
        log_warning "重要提示:"
        echo "  1. 当前SSH连接不会断开"
        echo "  2. 请在新终端测试密钥登录"
        echo "  3. 确认可以正常登录后再关闭当前连接"
        echo "  4. 如果无法登录，请通过VPS控制台恢复"
    else
        log_error "配置文件有错误，未应用更改"
        log_info "正在恢复备份..."
        cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
    fi
}

# 修改SSH端口
change_ssh_port() {
    show_ssh_security_info

    current_port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    if [ -z "$current_port" ]; then
        current_port="22"
    fi

    log_info "当前SSH端口: ${current_port}"
    echo ""
    read -p "请输入新的SSH端口 (1024-65535): " new_port

    # 验证端口号
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        log_error "无效的端口号"
        return
    fi

    # 检查端口是否被占用
    if netstat -tuln 2>/dev/null | grep -q ":${new_port} " || ss -tuln 2>/dev/null | grep -q ":${new_port} "; then
        log_error "端口 ${new_port} 已被占用"
        return
    fi

    # 备份配置
    backup_ssh_config

    # 修改端口
    log_info "修改 SSH 端口为: ${new_port}"

    if grep -q "^Port " /etc/ssh/sshd_config; then
        sed -i "s/^Port .*/Port ${new_port}/" /etc/ssh/sshd_config
    else
        sed -i "1i Port ${new_port}" /etc/ssh/sshd_config
    fi

    # 测试配置
    if sshd -t; then
        log_success "配置文件语法正确"

        # 提醒更新防火墙
        log_warning "注意: 需要在防火墙中开放新端口 ${new_port}"

        if command -v ufw &> /dev/null; then
            read -p "是否自动在UFW中开放新端口? (Y/n): " open_port
            if [[ ! $open_port =~ ^[Nn]$ ]]; then
                ufw allow ${new_port}/tcp comment 'SSH'
                log_success "UFW已开放端口 ${new_port}"
            fi
        fi

        # 重启SSH服务
        log_info "重启 SSH 服务..."
        systemctl restart sshd

        log_success "SSH端口已修改为 ${new_port}！"
        echo ""
        log_warning "下次连接请使用:"
        echo "  ssh -p ${new_port} user@server"
    else
        log_error "配置文件有错误，未应用更改"
    fi
}

# 配置SSH超时时间
configure_timeout() {
    log_info "配置 SSH 超时时间..."

    read -p "客户端存活间隔(秒，默认: 60): " client_alive_interval
    client_alive_interval=${client_alive_interval:-60}

    read -p "最大存活次数(默认: 3): " client_alive_count
    client_alive_count=${client_alive_count:-3}

    # 备份配置
    backup_ssh_config

    # 修改配置
    if grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
        sed -i "s/^ClientAliveInterval.*/ClientAliveInterval ${client_alive_interval}/" /etc/ssh/sshd_config
    else
        echo "ClientAliveInterval ${client_alive_interval}" >> /etc/ssh/sshd_config
    fi

    if grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
        sed -i "s/^ClientAliveCountMax.*/ClientAliveCountMax ${client_alive_count}/" /etc/ssh/sshd_config
    else
        echo "ClientAliveCountMax ${client_alive_count}" >> /etc/ssh/sshd_config
    fi

    # 重启SSH
    systemctl restart sshd

    log_success "SSH超时配置已更新"
    log_info "连接将在 $((client_alive_interval * client_alive_count)) 秒无响应后断开"
}

# 完整安全配置
full_security_setup() {
    show_ssh_security_info

    log_info "开始完整SSH安全配置..."
    echo ""

    # 1. 配置SSH密钥
    log_info "步骤 1/4: 配置SSH密钥登录"
    setup_ssh_key

    echo ""
    read -p "按回车继续下一步..."

    # 2. 修改SSH端口
    log_info "步骤 2/4: 修改SSH端口"
    read -p "是否修改SSH端口? (Y/n): " change_port
    if [[ ! $change_port =~ ^[Nn]$ ]]; then
        change_ssh_port
    fi

    echo ""
    read -p "按回车继续下一步..."

    # 3. 配置超时
    log_info "步骤 3/4: 配置连接超时"
    read -p "是否配置SSH超时时间? (Y/n): " config_timeout
    if [[ ! $config_timeout =~ ^[Nn]$ ]]; then
        configure_timeout
    fi

    echo ""
    read -p "按回车继续最后一步..."

    # 4. 禁用密码登录
    log_info "步骤 4/4: 禁用密码登录"
    read -p "是否禁用root密码登录? (y/N): " disable_pwd
    if [[ $disable_pwd =~ ^[Yy]$ ]]; then
        disable_password_login
    fi

    echo ""
    log_success "SSH安全配置完成！"
}

# 显示当前SSH配置
show_current_config() {
    echo ""
    log_info "当前 SSH 配置:"
    echo ""

    port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$port" ] && port="22"
    echo -e "  端口: ${GREEN}${port}${NC}"

    password_auth=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$password_auth" ] && password_auth="yes"
    echo -e "  密码认证: ${GREEN}${password_auth}${NC}"

    pubkey_auth=$(grep "^PubkeyAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$pubkey_auth" ] && pubkey_auth="yes"
    echo -e "  公钥认证: ${GREEN}${pubkey_auth}${NC}"

    root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    [ -z "$root_login" ] && root_login="yes"
    echo -e "  Root登录: ${GREEN}${root_login}${NC}"

    echo ""
}

# 显示帮助
show_help() {
    echo "用法: $0 {setup-key|disable-password|change-port|timeout|full|show}"
    echo ""
    echo "命令:"
    echo "  setup-key         - 配置SSH密钥登录"
    echo "  disable-password  - 禁用root密码登录"
    echo "  change-port       - 修改SSH端口"
    echo "  timeout           - 配置连接超时"
    echo "  full              - 完整安全配置（推荐）"
    echo "  show              - 显示当前配置"
    echo ""
}

# 主函数
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi

    case "$1" in
        setup-key)
            setup_ssh_key
            ;;
        disable-password)
            disable_password_login
            ;;
        change-port)
            change_ssh_port
            ;;
        timeout)
            configure_timeout
            ;;
        full)
            full_security_setup
            ;;
        show)
            show_current_config
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
