#!/bin/bash

#######################################
# Network Quality Detection Script
# Based on NetQuality project
# Network Quality Check Script
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

# Display network quality test introduction
show_network_quality_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║          NetQuality - Network Quality Check Tool       ║${NC}"
    echo -e "${CYAN}║          Network Quality Check Script                 ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Detection Categories:${NC}"
    echo -e "  🌐 ${GREEN}Network Connectivity${NC}: Global multi-region network testing"
    echo -e "  ⚡ ${GREEN}Network Latency${NC}     : Ping latency testing"
    echo -e "  📊 ${GREEN}Bandwidth Speed${NC}     : Upload/download speed testing"
    echo -e "  🔍 ${GREEN}Route Tracing${NC}       : Network path analysis"
    echo -e "  📡 ${GREEN}DNS Resolution${NC}      : DNS response time testing"
    echo -e "  🌍 ${GREEN}Geolocation${NC}         : Network node location information"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo -e "  ⚠️  Testing requires connecting to multiple test nodes"
    echo -e "  ⏱️  Full test takes approximately 2-5 minutes"
    echo -e "  📝 Test results will be displayed in real-time"
    echo -e "  🌍 Supports IPv4 and IPv6 dual-stack detection"
    echo ""
}

# Dual-stack detection (default)
run_dual_stack_test() {
    log_info "Starting network quality detection (IPv4 + IPv6 dual-stack)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: IPv4 and IPv6 dual-stack network detection${NC}"
    echo -e "${PURPLE}Estimated time: 2-5 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    log_info "Running test..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place); then
        echo ""
        log_success "Test complete!"
    else
        echo ""
        log_error "Test failed, please check network connection"
    fi
}

# IPv4 only detection
run_ipv4_test() {
    log_info "Starting network quality detection (IPv4 only)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: IPv4 network only${NC}"
    echo -e "${PURPLE}Estimated time: 1-3 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    log_info "Running test..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place) -4; then
        echo ""
        log_success "Test complete!"
    else
        echo ""
        log_error "Test failed, server may not support IPv4 or network connection error"
    fi
}

# IPv6 only detection
run_ipv6_test() {
    log_info "Starting network quality detection (IPv6 only)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test content: IPv6 network only${NC}"
    echo -e "${PURPLE}Estimated time: 1-3 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    read -p "Confirm to start test? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Test cancelled"
        return
    fi

    log_info "Running test..."
    echo ""

    if bash <(curl -Ls https://Net.Check.Place) -6; then
        echo ""
        log_success "Test complete!"
    else
        echo ""
        log_error "Test failed, server may not support IPv6 or network connection error"
    fi
}

# Check network connection status
check_network_status() {
    log_info "Checking current network connection status..."
    echo ""

    # Check IPv4 connectivity
    echo -e "${BLUE}━━━ IPv4 Connectivity Test ━━━${NC}"
    if ping -4 -c 3 -W 3 8.8.8.8 &>/dev/null; then
        echo -e "  IPv4 connection: ${GREEN}Normal ✓${NC}"

        # Get IPv4 address
        if ipv4=$(curl -s -4 -m 5 https://api.ipify.org 2>/dev/null); then
            if [ -n "$ipv4" ]; then
                echo -e "  IPv4 address: ${GREEN}${ipv4}${NC}"
            fi
        fi

        # Test latency
        if ping_result=$(ping -4 -c 3 8.8.8.8 2>/dev/null | tail -1); then
            echo -e "  Latency (Google DNS): ${GREEN}${ping_result}${NC}"
        fi
    else
        echo -e "  IPv4 connection: ${YELLOW}Unavailable${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━ IPv6 Connectivity Test ━━━${NC}"
    # Check IPv6 connectivity
    if ping -6 -c 3 -W 3 2001:4860:4860::8888 &>/dev/null; then
        echo -e "  IPv6 connection: ${GREEN}Normal ✓${NC}"

        # Get IPv6 address
        if ipv6=$(curl -s -6 -m 5 https://api64.ipify.org 2>/dev/null); then
            if [ -n "$ipv6" ]; then
                echo -e "  IPv6 address: ${GREEN}${ipv6}${NC}"
            fi
        fi

        # Test latency
        if ping_result=$(ping -6 -c 3 2001:4860:4860::8888 2>/dev/null | tail -1); then
            echo -e "  Latency (Google DNS): ${GREEN}${ping_result}${NC}"
        fi
    else
        echo -e "  IPv6 connection: ${YELLOW}Not configured or unavailable${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━ DNS Resolution Test ━━━${NC}"
    # DNS test
    if nslookup google.com &>/dev/null || host google.com &>/dev/null; then
        echo -e "  DNS resolution: ${GREEN}Normal ✓${NC}"
    else
        echo -e "  DNS resolution: ${RED}Failed${NC}"
    fi

    echo ""
}

# Network quality test menu
test_menu() {
    while true; do
        show_network_quality_info

        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           Network Quality Test Options        ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}1.${NC} 🌐 Dual-stack detection (IPv4 + IPv6, recommended)"
        echo -e "${GREEN}2.${NC} 4️⃣  IPv4 only detection"
        echo -e "${GREEN}3.${NC} 6️⃣  IPv6 only detection"
        echo -e "${GREEN}4.${NC} 🔍 View network connection status"
        echo -e "${RED}0.${NC} Return to main menu"
        echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
        echo ""
        read -p "Please select test type [0-4]: " choice

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

# Display help
show_help() {
    echo "Usage: $0 {dual|ipv4|ipv6|check|menu}"
    echo ""
    echo "Commands:"
    echo "  dual    - Dual-stack detection (IPv4 + IPv6)"
    echo "  ipv4    - IPv4 only detection"
    echo "  ipv6    - IPv6 only detection"
    echo "  check   - View network connection status"
    echo "  menu    - Show interactive menu (default)"
    echo ""
}

# Main function
main() {
    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed, please install curl first"
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
