#!/bin/bash

#######################################
# 网络质量检测脚本
# 基于 NetQuality 项目
# Network Quality Check Script
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

# 显示网络质量测试介绍
show_network_quality_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          NetQuality - 网络质量检测工具                ║${NC}"
    echo -e "${CYAN}║          Network Quality Check Script                 ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}检测项目:${NC}"
    echo -e "  🌐 ${GREEN}网络连通性${NC}    : 全球多地区网络测试"
    echo -e "  ⚡ ${GREEN}网络延迟${NC}      : Ping 延迟测试"
    echo -e "  📊 ${GREEN}带宽速度${NC}      : 上传/下载速度测试"
    echo -e "  🔍 ${GREEN}路由追踪${NC}      : 网络路径分析"
    echo -e "  📡 ${GREEN}DNS 解析${NC}      : DNS 响应时间测试"
    echo -e "  🌍 ${GREEN}地理位置${NC}      : 网络节点位置信息"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  ⚠️  测试需要连接多个测试节点"
    echo -e "  ⏱️  完整测试大约需要 2-5 分钟"
    echo -e "  📝 测试结果会实时显示"
    echo -e "  🌍 支持 IPv4 和 IPv6 双栈检测"
    echo ""
}

# 双栈检测（默认）
run_dual_stack_test() {
    log_info "开始网络质量检测 (IPv4 + IPv6 双栈)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: IPv4 和 IPv6 双栈网络检测${NC}"
    echo -e "${PURPLE}预计时间: 2-5 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place); then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，请检查网络连接"
    fi
}

# 仅 IPv4 检测
run_ipv4_test() {
    log_info "开始网络质量检测 (仅 IPv4)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 仅检测 IPv4 网络${NC}"
    echo -e "${PURPLE}预计时间: 1-3 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place) -4; then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，可能服务器不支持IPv4或网络连接异常"
    fi
}

# 仅 IPv6 检测
run_ipv6_test() {
    log_info "开始网络质量检测 (仅 IPv6)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 仅检测 IPv6 网络${NC}"
    echo -e "${PURPLE}预计时间: 1-3 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place) -6; then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，可能服务器不支持IPv6或网络连接异常"
    fi
}

# 检查网络连接状态
check_network_status() {
    log_info "检查当前网络连接状态..."
    echo ""

    # 检查IPv4连通性
    echo -e "${BLUE}━━━ IPv4 连通性测试 ━━━${NC}"
    if ping -4 -c 3 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "  IPv4 连接: ${GREEN}正常 ✓${NC}"

        # 获取IPv4地址
        if ipv4=$(curl -s -4 -m 5 https://api.ipify.org 2>/dev/null); then
            if [ -n "$ipv4" ]; then
                echo -e "  IPv4 地址: ${GREEN}${ipv4}${NC}"
            fi
        fi

        # 测试延迟
        if ping_result=$(ping -4 -c 3 8.8.8.8 2>/dev/null | tail -1); then
            echo -e "  延迟 (Google DNS): ${GREEN}${ping_result}${NC}"
        fi
    else
        echo -e "  IPv4 连接: ${YELLOW}不可用${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━ IPv6 连通性测试 ━━━${NC}"
    # 检查IPv6连通性
    if ping -6 -c 3 -W 3 2001:4860:4860::8888 &>/dev/null; then
        echo -e "  IPv6 连接: ${GREEN}正常 ✓${NC}"

        # 获取IPv6地址
        if ipv6=$(curl -s -6 -m 5 https://api64.ipify.org 2>/dev/null); then
            if [ -n "$ipv6" ]; then
                echo -e "  IPv6 地址: ${GREEN}${ipv6}${NC}"
            fi
        fi

        # 测试延迟
        if ping_result=$(ping -6 -c 3 2001:4860:4860::8888 2>/dev/null | tail -1); then
            echo -e "  延迟 (Google DNS): ${GREEN}${ping_result}${NC}"
        fi
    else
        echo -e "  IPv6 连接: ${YELLOW}未配置或不可用${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━ DNS 解析测试 ━━━${NC}"
    # DNS测试
    if nslookup google.com &>/dev/null || host google.com &>/dev/null; then
        echo -e "  DNS 解析: ${GREEN}正常 ✓${NC}"
    else
        echo -e "  DNS 解析: ${RED}失败${NC}"
    fi

    echo ""
}

# 网络质量测试菜单
test_menu() {
    while true; do
        show_network_quality_info

        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           网络质量测试选项                     ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 🌐 双栈检测 (IPv4 + IPv6，推荐)"
        echo -e "${GREEN}2.${NC} 4️⃣  仅 IPv4 检测"
        echo -e "${GREEN}3.${NC} 6️⃣  仅 IPv6 检测"
        echo -e "${GREEN}4.${NC} 🔍 查看网络连接状态"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo ""
        read -p "请选择测试类型 [0-4]: " choice

        case $choice in
            1)
                run_dual_stack_test
                ;;
            2)
                run_ipv4_test
                ;;
            3)
                run_ipv6_test
                ;;
            4)
                check_network_status
                ;;
            0)
                log_info "返回主菜单"
                return
                ;;
            *)
                log_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac

        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "按回车键继续..."
    done
}

# 显示帮助
show_help() {
    echo "用法: $0 {dual|ipv4|ipv6|check|menu}"
    echo ""
    echo "命令:"
    echo "  dual    - 双栈检测 (IPv4 + IPv6)"
    echo "  ipv4    - 仅 IPv4 检测"
    echo "  ipv6    - 仅 IPv6 检测"
    echo "  check   - 查看网络连接状态"
    echo "  menu    - 显示交互式菜单 (默认)"
    echo ""
}

# 主函数
main() {
    # 检查curl
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi

    case "$1" in
        dual)
            show_network_quality_info
            run_dual_stack_test
            ;;
        ipv4)
            show_network_quality_info
            run_ipv4_test
            ;;
        ipv6)
            show_network_quality_info
            run_ipv6_test
            ;;
        check)
            check_network_status
            ;;
        menu|"")
            test_menu
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
