#!/bin/bash

#######################################
# IP 质量测试脚本
# 基于 IPQuality 项目
# 项目地址: https://github.com/xykt/IPQuality
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

# 显示IP质量测试介绍
show_ip_quality_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          IPQuality - IP 质量检测工具                  ║${NC}"
    echo -e "${CYAN}║          IP Quality Detection Tool                     ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}检测项目:${NC}"
    echo -e "  🌐 ${GREEN}IP 类型${NC}        : 家庭宽带/数据中心/云服务商"
    echo -e "  📍 ${GREEN}地理位置${NC}      : 国家/城市/ISP信息"
    echo -e "  🚫 ${GREEN}滥用检测${NC}      : 垃圾邮件/代理/VPN检测"
    echo -e "  📊 ${GREEN}风险评分${NC}      : IP信誉评分"
    echo -e "  🔍 ${GREEN}黑名单检测${NC}    : 各大黑名单数据库查询"
    echo -e "  🎯 ${GREEN}流媒体解锁${NC}    : Netflix/YouTube等流媒体检测"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  ⚠️  测试需要连接多个检测服务器"
    echo -e "  ⏱️  完整测试大约需要 1-3 分钟"
    echo -e "  📝 测试结果会实时显示"
    echo -e "  🌍 支持 IPv4 和 IPv6 双栈检测"
    echo ""
}

# 双栈检测（默认）
run_dual_stack_test() {
    log_info "开始 IP 质量检测 (IPv4 + IPv6 双栈)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: IPv4 和 IPv6 双栈检测${NC}"
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

    if bash <(curl -Ls https://IP.Check.Place); then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，请检查网络连接"
    fi
}

# 仅 IPv4 检测
run_ipv4_test() {
    log_info "开始 IP 质量检测 (仅 IPv4)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 仅检测 IPv4 地址${NC}"
    echo -e "${PURPLE}预计时间: 30-90 秒${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    echo ""

    if bash <(curl -Ls https://IP.Check.Place) -4; then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，可能服务器不支持IPv4或网络连接异常"
    fi
}

# 仅 IPv6 检测
run_ipv6_test() {
    log_info "开始 IP 质量检测 (仅 IPv6)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 仅检测 IPv6 地址${NC}"
    echo -e "${PURPLE}预计时间: 30-90 秒${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    echo ""

    if bash <(curl -Ls https://IP.Check.Place) -6; then
        echo ""
        log_success "测试完成！"
    else
        echo ""
        log_error "测试失败，可能服务器不支持IPv6或网络连接异常"
    fi
}

# 检查当前IP配置
check_ip_config() {
    log_info "检查当前服务器 IP 配置..."
    echo ""

    # 检查IPv4
    if ipv4=$(curl -s -4 -m 5 https://api.ipify.org 2>/dev/null); then
        if [ -n "$ipv4" ]; then
            echo -e "  IPv4 地址: ${GREEN}${ipv4}${NC} ✓"
        else
            echo -e "  IPv4 地址: ${YELLOW}未配置${NC}"
        fi
    else
        echo -e "  IPv4 地址: ${YELLOW}检测失败${NC}"
    fi

    # 检查IPv6
    if ipv6=$(curl -s -6 -m 5 https://api64.ipify.org 2>/dev/null); then
        if [ -n "$ipv6" ]; then
            echo -e "  IPv6 地址: ${GREEN}${ipv6}${NC} ✓"
        else
            echo -e "  IPv6 地址: ${YELLOW}未配置${NC}"
        fi
    else
        echo -e "  IPv6 地址: ${YELLOW}未配置或检测失败${NC}"
    fi

    echo ""
}

# IP质量测试菜单
test_menu() {
    while true; do
        show_ip_quality_info

        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           IP 质量测试选项                     ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 🌐 双栈检测 (IPv4 + IPv6，推荐)"
        echo -e "${GREEN}2.${NC} 4️⃣  仅 IPv4 检测"
        echo -e "${GREEN}3.${NC} 6️⃣  仅 IPv6 检测"
        echo -e "${GREEN}4.${NC} 🔍 查看当前 IP 配置"
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
                check_ip_config
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
    echo "  check   - 查看当前 IP 配置"
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
            show_ip_quality_info
            run_dual_stack_test
            ;;
        ipv4)
            show_ip_quality_info
            run_ipv4_test
            ;;
        ipv6)
            show_ip_quality_info
            run_ipv6_test
            ;;
        check)
            check_ip_config
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
