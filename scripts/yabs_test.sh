#!/bin/bash

#######################################
# YABS Performance Test Script
# YABS - Yet Another Bench Script
#######################################

# Color definitions
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

# Helper function to safely download and run YABS with parameters
run_yabs_safely() {
    local params="$1"
    local script_file="/tmp/yabs-$$.sh"

    log_info "Downloading test script..."
    if ! curl -fsSL --proto '=https' --tlsv1.2 https://yabs.sh -o "$script_file"; then
        log_error "Failed to download test script"
        rm -f "$script_file"
        return 1
    fi

    log_info "Running test..."
    if [ -n "$params" ]; then
        bash "$script_file" $params
    else
        bash "$script_file"
    fi
    local result=$?

    rm -f "$script_file"
    return $result
}

# Display test information
show_test_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          YABS - VPS Performance Test Tool             ║${NC}"
    echo -e "${CYAN}║          Yet Another Bench Script                     ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Test Categories:${NC}"
    echo -e "  🖥️  ${GREEN}CPU Performance${NC}    : Single/multi-core performance test"
    echo -e "  💾 ${GREEN}Disk Performance${NC}   : 4K/64K/512K/1M read/write speed"
    echo -e "  🌐 ${GREEN}Network Speed${NC}      : Global multi-node upload/download test"
    echo -e "  📊 ${GREEN}GeekBench 5${NC}        : Professional CPU benchmark (requires extra time)"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo -e "  ⚠️  Testing will consume CPU and bandwidth resources"
    echo -e "  ⏱️  Full test takes approximately 10-20 minutes"
    echo -e "  ⏱️  Including GeekBench 5 test requires an additional 5-10 minutes"
    echo -e "  📝 Test results will be saved to the current directory"
    echo ""
}

# YABS full test (including GeekBench 5)
run_full_test() {
    log_info "Starting YABS full test (including GeekBench 5)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: CPU + Disk + Network + GeekBench 5${NC}"
    echo -e "${PURPLE}Estimated time: 15-30 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_warning "⚠️  This test will download and execute external scripts"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely ""; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS test (without GeekBench 5)
run_basic_test() {
    log_info "Starting YABS basic test (without GeekBench 5)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: CPU + Disk + Network${NC}"
    echo -e "${PURPLE}Estimated time: 10-15 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_warning "⚠️  This test will download and execute external scripts"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-i"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS GeekBench 5 only test
run_geekbench_only() {
    log_info "Starting GeekBench 5 CPU benchmark test..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: GeekBench 5 CPU benchmark${NC}"
    echo -e "${PURPLE}Estimated time: 5-10 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-fg"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS disk+network test (without CPU and GB5)
run_disk_network_test() {
    log_info "Starting disk and network speed test..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: Disk I/O + Network speed${NC}"
    echo -e "${PURPLE}Estimated time: 5-10 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-ig"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS disk only test
run_disk_only_test() {
    log_info "Starting disk I/O performance test..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: Disk I/O performance${NC}"
    echo -e "${PURPLE}Test items: 4K/64K/512K/1M read/write speed${NC}"
    echo -e "${PURPLE}Estimated time: 2-5 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-fign"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS network only test
run_network_only_test() {
    log_info "Starting network speed test..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: Network upload/download speed${NC}"
    echo -e "${PURPLE}Test nodes: Multiple global speed test nodes${NC}"
    echo -e "${PURPLE}Estimated time: 3-5 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-fdig"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# YABS quick test (basic CPU test only)
run_quick_test() {
    log_info "Starting quick CPU performance test..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: Basic CPU performance${NC}"
    echo -e "${PURPLE}Estimated time: 1-2 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N) (press Enter to cancel): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    if run_yabs_safely "-fgn"; then
        log_success "Test complete!"
    else
        log_error "Test failed"
    fi
}

# Test menu
test_menu() {
    while true; do
        show_test_info

        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           YABS Test Options                   ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 🔥 Full test (CPU + Disk + Network + GeekBench 5)"
        echo -e "${GREEN}2.${NC} ⚡ Basic test (CPU + Disk + Network, no GB5)"
        echo -e "${GREEN}3.${NC} 💾 Disk + Network test (skip CPU benchmark)"
        echo -e "${GREEN}4.${NC} 📊 GeekBench 5 only test"
        echo -e "${GREEN}5.${NC} 💿 Disk I/O only test"
        echo -e "${GREEN}6.${NC} 🌐 Network speed only test"
        echo -e "${GREEN}7.${NC} ⚡ Quick CPU test"
        echo -e "${RED}0.${NC} Return to main menu"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo ""
        read -p "Please select test type [0-7]: " choice

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
                log_info "Returning to main menu"
                return
                ;;
            *)
                log_error "Invalid selection, please try again"
                sleep 2
                ;;
        esac

        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "Press Enter to continue..."
    done
}

# Main function
main() {
    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed, please install curl first"
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
            echo "Usage: $0 {full|basic|disk-network|geekbench|disk|network|quick|menu}"
            echo ""
            echo "Test types:"
            echo "  full         - Full test (including GeekBench 5)"
            echo "  basic        - Basic test (excluding GeekBench 5)"
            echo "  disk-network - Disk and network test"
            echo "  geekbench    - GeekBench 5 only test"
            echo "  disk         - Disk only test"
            echo "  network      - Network only test"
            echo "  quick        - Quick CPU test"
            echo "  menu         - Show interactive menu (default)"
            echo ""
            exit 1
            ;;
    esac
}

main "$@"
