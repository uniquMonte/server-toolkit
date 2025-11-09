#!/bin/bash

#######################################
# YABS 性能测试脚本
# YABS - Yet Another Bench Script
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

# 显示测试说明
show_test_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          YABS - VPS 性能测试工具                      ║${NC}"
    echo -e "${CYAN}║          Yet Another Bench Script                     ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}测试项目说明:${NC}"
    echo -e "  🖥️  ${GREEN}CPU 性能${NC}      : 单核/多核性能测试"
    echo -e "  💾 ${GREEN}磁盘性能${NC}      : 4K/64K/512K/1M读写速度"
    echo -e "  🌐 ${GREEN}网络速度${NC}      : 全球多节点上传/下载测试"
    echo -e "  📊 ${GREEN}GeekBench 5${NC}   : 专业CPU跑分 (需要额外时间)"
    echo ""
    echo -e "${YELLOW}注意事项:${NC}"
    echo -e "  ⚠️  测试过程会消耗一定的CPU和带宽资源"
    echo -e "  ⏱️  完整测试大约需要 10-20 分钟"
    echo -e "  ⏱️  包含GeekBench 5 测试需要额外 5-10 分钟"
    echo -e "  📝 测试结果会保存到当前目录"
    echo ""
}

# YABS 完整测试 (包括 GeekBench 5)
run_full_test() {
    log_info "开始 YABS 完整测试 (包括 GeekBench 5)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: CPU + 磁盘 + 网络 + GeekBench 5${NC}"
    echo -e "${PURPLE}预计时间: 15-30 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 测试 (不包括 GeekBench 5)
run_basic_test() {
    log_info "开始 YABS 基础测试 (不包括 GeekBench 5)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: CPU + 磁盘 + 网络${NC}"
    echo -e "${PURPLE}预计时间: 10-15 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -i; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 仅 GeekBench 5 测试
run_geekbench_only() {
    log_info "开始 GeekBench 5 CPU 跑分测试..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: GeekBench 5 CPU 跑分${NC}"
    echo -e "${PURPLE}预计时间: 5-10 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -fg; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 磁盘+网络测试 (不包括CPU和GB5)
run_disk_network_test() {
    log_info "开始磁盘和网络速度测试..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 磁盘 I/O + 网络速度${NC}"
    echo -e "${PURPLE}预计时间: 5-10 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -ig; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 仅磁盘测试
run_disk_only_test() {
    log_info "开始磁盘 I/O 性能测试..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 磁盘 I/O 性能${NC}"
    echo -e "${PURPLE}测试项目: 4K/64K/512K/1M 读写速度${NC}"
    echo -e "${PURPLE}预计时间: 2-5 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -fign; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 仅网络测试
run_network_only_test() {
    log_info "开始网络速度测试..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 网络上传/下载速度${NC}"
    echo -e "${PURPLE}测试节点: 全球多个测速节点${NC}"
    echo -e "${PURPLE}预计时间: 3-5 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -fdig; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# YABS 快速测试 (仅基础CPU测试)
run_quick_test() {
    log_info "开始快速 CPU 性能测试..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}测试内容: 基础 CPU 性能${NC}"
    echo -e "${PURPLE}预计时间: 1-2 分钟${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "确认开始测试? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "已取消测试"
        return
    fi

    log_info "正在执行测试..."
    if curl -sL yabs.sh | bash -s -- -fgn; then
        log_success "测试完成！"
    else
        log_error "测试失败"
    fi
}

# 测试菜单
test_menu() {
    while true; do
        show_test_info

        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           YABS 测试选项                       ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 🔥 完整测试 (CPU + 磁盘 + 网络 + GeekBench 5)"
        echo -e "${GREEN}2.${NC} ⚡ 基础测试 (CPU + 磁盘 + 网络，不含GB5)"
        echo -e "${GREEN}3.${NC} 💾 磁盘 + 网络测试 (跳过CPU跑分)"
        echo -e "${GREEN}4.${NC} 📊 仅 GeekBench 5 测试"
        echo -e "${GREEN}5.${NC} 💿 仅磁盘 I/O 测试"
        echo -e "${GREEN}6.${NC} 🌐 仅网络速度测试"
        echo -e "${GREEN}7.${NC} ⚡ 快速 CPU 测试"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo ""
        read -p "请选择测试类型 [0-7]: " choice

        case $choice in
            1)
                run_full_test
                ;;
            2)
                run_basic_test
                ;;
            3)
                run_disk_network_test
                ;;
            4)
                run_geekbench_only
                ;;
            5)
                run_disk_only_test
                ;;
            6)
                run_network_only_test
                ;;
            7)
                run_quick_test
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

# 主函数
main() {
    # 检查curl
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装 curl"
        exit 1
    fi

    case "$1" in
        full)
            show_test_info
            run_full_test
            ;;
        basic)
            show_test_info
            run_basic_test
            ;;
        disk-network)
            show_test_info
            run_disk_network_test
            ;;
        geekbench)
            show_test_info
            run_geekbench_only
            ;;
        disk)
            show_test_info
            run_disk_only_test
            ;;
        network)
            show_test_info
            run_network_only_test
            ;;
        quick)
            show_test_info
            run_quick_test
            ;;
        menu|"")
            test_menu
            ;;
        *)
            echo "用法: $0 {full|basic|disk-network|geekbench|disk|network|quick|menu}"
            echo ""
            echo "测试类型:"
            echo "  full         - 完整测试 (包括 GeekBench 5)"
            echo "  basic        - 基础测试 (不包括 GeekBench 5)"
            echo "  disk-network - 磁盘和网络测试"
            echo "  geekbench    - 仅 GeekBench 5 测试"
            echo "  disk         - 仅磁盘测试"
            echo "  network      - 仅网络测试"
            echo "  quick        - 快速CPU测试"
            echo "  menu         - 显示交互式菜单 (默认)"
            echo ""
            exit 1
            ;;
    esac
}

main "$@"
