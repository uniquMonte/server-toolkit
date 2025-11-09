# VPS Quick Setup Script

Quickly install and configure common tools on newly purchased VPS servers.

## Quick Start

```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)
```

## Menu Options

```
═══════════════════════════════════════
           Main Menu
═══════════════════════════════════════
1. Install All Components
2. System Update
3. UFW Firewall Management
4. Docker Management
5. Nginx Management
6. Fail2ban Anti-Brute Force
7. SSH Security Configuration
8. YABS Performance Test
9. IP Quality Check
10. Network Quality Test
0. Exit
═══════════════════════════════════════
```

## Standalone Usage

```bash
# System Update
sudo ./scripts/system_update.sh

# UFW Firewall
sudo ./scripts/ufw_manager.sh install-common

# Docker
sudo ./scripts/docker_manager.sh install-compose

# Nginx + Certbot
sudo ./scripts/nginx_manager.sh install-certbot

# Fail2ban
sudo ./scripts/fail2ban_manager.sh install

# SSH Security
sudo ./scripts/ssh_security.sh full

# YABS Test
./scripts/yabs_test.sh menu

# IP Quality Check
./scripts/ip_quality_test.sh menu

# Network Quality Test
./scripts/network_quality_test.sh menu
```

## Supported Systems

Ubuntu • Debian • CentOS • Rocky Linux • AlmaLinux • Fedora

---

MIT License | [GitHub](https://github.com/uniquMonte/vps-setup)
