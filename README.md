# VPS 一键部署脚本

快速在新购买的 VPS 上安装和配置常用工具。

## 快速开始

```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)
```

## 功能菜单

```
═══════════════════════════════════════
           主菜单 Main Menu
═══════════════════════════════════════
1. 一键安装所有组件
2. 系统更新
3. UFW 防火墙管理
4. Docker 管理
5. Nginx 管理
6. Fail2ban 防暴力破解
7. SSH 安全配置
8. YABS 性能测试
9. IP 质量检测
10. 网络质量检测
0. 退出
═══════════════════════════════════════
```

## 独立运行

```bash
# 系统更新
sudo ./scripts/system_update.sh

# UFW 防火墙
sudo ./scripts/ufw_manager.sh install-common

# Docker
sudo ./scripts/docker_manager.sh install-compose

# Nginx + Certbot
sudo ./scripts/nginx_manager.sh install-certbot

# Fail2ban
sudo ./scripts/fail2ban_manager.sh install

# SSH 安全
sudo ./scripts/ssh_security.sh full

# YABS 测试
./scripts/yabs_test.sh menu

# IP 质量检测
./scripts/ip_quality_test.sh menu

# 网络质量检测
./scripts/network_quality_test.sh menu
```

## 支持系统

Ubuntu • Debian • CentOS • Rocky Linux • AlmaLinux • Fedora

---

MIT License | [GitHub](https://github.com/uniquMonte/vps-setup)
