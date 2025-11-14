#!/bin/bash

#######################################
# Streaming and AI Unlock Detection Script
# Based on unlockcheck project
# Project: https://github.com/uniquMonte/unlockcheck
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

# Display unlock check introduction
show_unlock_check_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}║      Streaming & AI Unlock Detection Tool             ║${NC}"
    echo -e "${CYAN}║      流媒体及AI解锁检测工具                              ║${NC}"
    echo -e "${CYAN}║                                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Detection Categories:${NC}"
    echo -e "  📺 ${GREEN}Streaming Services${NC}: Netflix, Disney+, YouTube Premium, etc."
    echo -e "  🤖 ${GREEN}AI Services${NC}       : ChatGPT, Claude, Gemini, etc."
    echo -e "  🌍 ${GREEN}Regional Access${NC}   : TikTok, Bilibili, and other regional platforms"
    echo -e "  📡 ${GREEN}Network Detection${NC} : IPv4/IPv6 dual-stack support"
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo -e "  ⚠️  Detection requires connecting to multiple service platforms"
    echo -e "  ⏱️  Full detection takes approximately 1-3 minutes"
    echo -e "  📝 Results will be displayed in real-time"
    echo -e "  🌐 Supports IPv4 and IPv6 separate or dual-stack detection"
    echo ""
}

# Helper function to safely run unlockcheck
run_unlock_check_safely() {
    local params="$1"

    log_info "Running streaming and AI unlock detection..."
    echo ""

    if [ -n "$params" ]; then
        bash <(curl -Ls unlockcheck.mlkit.workers.dev) $params
    else
        bash <(curl -Ls unlockcheck.mlkit.workers.dev)
    fi

    return $?
}

# Dual-stack detection (default)
run_dual_stack_test() {
    log_info "Starting streaming and AI unlock detection (IPv4 + IPv6 dual-stack)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test mode: IPv4 and IPv6 dual-stack detection${NC}"
    echo -e "${PURPLE}Estimated time: 1-3 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_warning "⚠️  This detection will download and execute scripts from unlockcheck.mlkit.workers.dev"
    echo ""

    read -p "Confirm to start detection? [Y/n] (press Enter to start): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Detection cancelled"
        return
    fi

    echo ""
    run_unlock_check_safely ""

    if [ $? -eq 0 ]; then
        echo ""
        log_success "Detection completed!"
    else
        echo ""
        log_error "Detection failed or was interrupted"
    fi
}

# IPv4 only detection
run_ipv4_test() {
    log_info "Starting streaming and AI unlock detection (IPv4 only)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test mode: IPv4 only detection${NC}"
    echo -e "${PURPLE}Estimated time: 1-2 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_warning "⚠️  This detection will download and execute scripts from unlockcheck.mlkit.workers.dev"
    echo ""

    read -p "Confirm to start detection? [Y/n] (press Enter to start): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Detection cancelled"
        return
    fi

    echo ""
    run_unlock_check_safely "-4"

    if [ $? -eq 0 ]; then
        echo ""
        log_success "Detection completed!"
    else
        echo ""
        log_error "Detection failed or was interrupted"
    fi
}

# IPv6 only detection
run_ipv6_test() {
    log_info "Starting streaming and AI unlock detection (IPv6 only)..."
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}Test mode: IPv6 only detection${NC}"
    echo -e "${PURPLE}Estimated time: 1-2 minutes${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log_warning "⚠️  This detection will download and execute scripts from unlockcheck.mlkit.workers.dev"
    echo ""

    read -p "Confirm to start detection? [Y/n] (press Enter to start): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        log_info "Detection cancelled"
        return
    fi

    echo ""
    run_unlock_check_safely "-6"

    if [ $? -eq 0 ]; then
        echo ""
        log_success "Detection completed!"
    else
        echo ""
        log_error "Detection failed or was interrupted"
    fi
}

# Show menu
show_menu() {
    while true; do
        show_unlock_check_info

        echo -e "${CYAN}Available Options:${NC}"
        echo -e "${GREEN}1.${NC} Run dual-stack detection (IPv4 + IPv6) [Default]"
        echo -e "${GREEN}2.${NC} Run IPv4 only detection"
        echo -e "${GREEN}3.${NC} Run IPv6 only detection"
        echo -e "${RED}0.${NC} Return to main menu"
        echo ""
        read -p "Please select an option [0-3, or press Enter for option 1]: " choice

        # Default to option 1 if Enter is pressed
        choice=${choice:-1}

        case $choice in
            1)
                run_dual_stack_test
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            2)
                run_ipv4_test
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            3)
                run_ipv6_test
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            0)
                log_info "Returning to main menu"
                break
                ;;
            *)
                log_error "Invalid selection, please try again"
                sleep 1
                clear
                ;;
        esac
    done
}

# Main entry point
main() {
    case "${1:-menu}" in
        menu)
            show_menu
            ;;
        dual|"")
            run_dual_stack_test
            ;;
        ipv4|-4)
            run_ipv4_test
            ;;
        ipv6|-6)
            run_ipv6_test
            ;;
        *)
            log_error "Unknown option: $1"
            log_info "Usage: $0 [menu|dual|ipv4|ipv6]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
