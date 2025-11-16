#!/bin/bash

#######################################
# Xray Reality Diagnostic Script
# Helps diagnose connection issues
#######################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}        Xray Reality Connection Diagnostics        ${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check 1: Xray service status
echo -e "${BLUE}[1/7]${NC} Checking Xray service status..."
if systemctl is-active --quiet xray; then
    echo -e "  ${GREEN}✓${NC} Xray service is running"
    systemctl status xray --no-pager -l | head -10
else
    echo -e "  ${RED}✗${NC} Xray service is NOT running"
    echo -e "  ${YELLOW}Fix:${NC} sudo systemctl start xray"
    echo ""
    echo -e "${YELLOW}Recent logs:${NC}"
    journalctl -u xray -n 20 --no-pager
    exit 1
fi
echo ""

# Check 2: Xray configuration validity
echo -e "${BLUE}[2/7]${NC} Testing Xray configuration..."
if xray -test -config /usr/local/etc/xray/config.json &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Configuration is valid"
else
    echo -e "  ${RED}✗${NC} Configuration has errors"
    xray -test -config /usr/local/etc/xray/config.json
    exit 1
fi
echo ""

# Check 3: Port 443 listening status
echo -e "${BLUE}[3/7]${NC} Checking if port 443 is listening..."
if netstat -tlnp 2>/dev/null | grep -q ":443 " || ss -tlnp 2>/dev/null | grep -q ":443 "; then
    echo -e "  ${GREEN}✓${NC} Port 443 is listening"
    netstat -tlnp 2>/dev/null | grep ":443 " || ss -tlnp 2>/dev/null | grep ":443 "
else
    echo -e "  ${RED}✗${NC} Port 443 is NOT listening"
    echo -e "  ${YELLOW}This is a critical issue!${NC}"
    exit 1
fi
echo ""

# Check 4: Firewall rules
echo -e "${BLUE}[4/7]${NC} Checking firewall status..."

# Check UFW
if command -v ufw &>/dev/null; then
    ufw_status=$(ufw status | grep -i status | awk '{print $2}')
    echo -e "  ${CYAN}UFW Status:${NC} $ufw_status"
    if [ "$ufw_status" = "active" ]; then
        if ufw status | grep -q "443"; then
            echo -e "  ${GREEN}✓${NC} Port 443 is allowed in UFW"
            ufw status | grep 443
        else
            echo -e "  ${RED}✗${NC} Port 443 is NOT allowed in UFW"
            echo -e "  ${YELLOW}Fix:${NC} sudo ufw allow 443/tcp"
        fi
    fi
fi

# Check iptables
if command -v iptables &>/dev/null; then
    echo -e "  ${CYAN}Checking iptables rules...${NC}"
    if iptables -L INPUT -n | grep -q "dpt:443"; then
        echo -e "  ${GREEN}✓${NC} Port 443 allowed in iptables"
    else
        if iptables -L INPUT -n | grep -q "DROP\|REJECT"; then
            echo -e "  ${YELLOW}⚠${NC} Warning: iptables has DROP/REJECT rules, port 443 may be blocked"
            echo -e "  ${YELLOW}Fix:${NC} sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT"
        fi
    fi
fi

# Check firewalld
if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld; then
    echo -e "  ${CYAN}Firewalld Status:${NC} active"
    if firewall-cmd --list-ports | grep -q "443"; then
        echo -e "  ${GREEN}✓${NC} Port 443 is allowed in firewalld"
    else
        echo -e "  ${RED}✗${NC} Port 443 is NOT allowed in firewalld"
        echo -e "  ${YELLOW}Fix:${NC} sudo firewall-cmd --permanent --add-port=443/tcp && sudo firewall-cmd --reload"
    fi
fi
echo ""

# Check 5: Deployment configuration
echo -e "${BLUE}[5/7]${NC} Checking deployment configuration..."
if [ -f /etc/lightpath/deployment.conf ]; then
    echo -e "  ${GREEN}✓${NC} Deployment config exists"
    source /etc/lightpath/deployment.conf
    echo -e "  ${CYAN}Deployment Type:${NC} $DEPLOYMENT_TYPE"
    echo -e "  ${CYAN}Server IP:${NC} $SERVER_IP"
    echo -e "  ${CYAN}Port:${NC} $PORT"
    echo -e "  ${CYAN}UUID:${NC} $UUID"
    echo -e "  ${CYAN}Destination:${NC} $DEST_DOMAIN"
    echo -e "  ${CYAN}Public Key:${NC} $PUBLIC_KEY"
else
    echo -e "  ${RED}✗${NC} Deployment config not found"
    exit 1
fi
echo ""

# Check 6: Test destination domain connectivity
echo -e "${BLUE}[6/7]${NC} Testing destination domain connectivity..."
if timeout 5 openssl s_client -connect ${DEST_DOMAIN}:443 -servername ${DEST_DOMAIN} </dev/null &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Can connect to destination domain: $DEST_DOMAIN"
else
    echo -e "  ${RED}✗${NC} Cannot connect to destination domain: $DEST_DOMAIN"
    echo -e "  ${YELLOW}Warning:${NC} This may affect Reality protocol functionality"
fi
echo ""

# Check 7: Xray error logs
echo -e "${BLUE}[7/7]${NC} Checking recent Xray logs..."
if [ -f /var/log/xray/error.log ]; then
    error_count=$(wc -l < /var/log/xray/error.log 2>/dev/null || echo 0)
    if [ "$error_count" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} Found $error_count lines in error log (last 10):"
        tail -10 /var/log/xray/error.log
    else
        echo -e "  ${GREEN}✓${NC} No errors in log file"
    fi
else
    echo -e "  ${CYAN}ℹ${NC} Error log file not found (this is normal if no errors occurred)"
fi
echo ""

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Diagnostic Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}To test connectivity from outside:${NC}"
echo -e "  ${CYAN}1.${NC} From another machine: telnet $SERVER_IP 443"
echo -e "  ${CYAN}2.${NC} Online tool: https://www.yougetsignal.com/tools/open-ports/"
echo -e "  ${CYAN}3.${NC} Or use: nc -zv $SERVER_IP 443"
echo ""
echo -e "${YELLOW}Client configuration:${NC}"
echo -e "  Server: ${GREEN}$SERVER_IP${NC}"
echo -e "  Port: ${GREEN}$PORT${NC}"
echo -e "  UUID: ${GREEN}$UUID${NC}"
echo -e "  SNI/ServerName: ${GREEN}$DEST_DOMAIN${NC}"
echo -e "  Public Key: ${GREEN}$PUBLIC_KEY${NC}"
echo -e "  Flow: ${GREEN}xtls-rprx-vision${NC}"
echo ""
echo -e "${YELLOW}Common issues and fixes:${NC}"
echo -e "  ${CYAN}•${NC} Firewall blocking: Check cloud provider's security group/firewall"
echo -e "  ${CYAN}•${NC} Wrong server IP: Make sure using public IP, not private IP"
echo -e "  ${CYAN}•${NC} Client config error: Regenerate config using option 4 in menu"
echo -e "  ${CYAN}•${NC} Time sync issue: Check if server time is correct (date)"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
