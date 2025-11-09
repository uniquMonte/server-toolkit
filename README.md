# VPS 一键部署脚本

一个功能强大的 VPS 自动化部署脚本，快速在新购买的 VPS 上安装和配置常用工具。

## 🚀 快速开始

```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)
```

## ✨ 功能特性

### 基础组件
- 🔄 **系统更新** - 更新系统并安装常用工具（curl、wget、git、vim、htop 等）
- 🔒 **UFW 防火墙** - 三种安装模式（仅安装/常用端口/自定义）
- 🐳 **Docker** - Docker Engine + Docker Compose
- 🌐 **Nginx** - Web 服务器 + 性能优化配置
- 🔐 **Certbot** - Let's Encrypt SSL 证书（可选）

### 安全工具
- 🛡️ **Fail2ban** - 防暴力破解，自动封禁恶意 IP
- 🔑 **SSH 安全** - 密钥登录、禁用密码、修改端口

### 测试工具
- 📊 **YABS** - 全面的性能测试（CPU、磁盘、网络、GeekBench）
- 🌍 **IP 质量** - IP 信誉、地理位置、黑名单检测
- 📡 **网络质量** - 连通性、延迟、带宽、DNS 测试

## 📋 交互式菜单

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

## 💡 使用示例

### 新 VPS 快速部署

```bash
# 1. 运行脚本
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)

# 2. 选择"1 - 一键安装所有组件"
# 3. 按照提示完成配置
```

### SSH 安全加固（推荐）

```bash
# 选择"7 - SSH 安全配置" → "5 - 完整安全配置"
# 系统会自动完成：
# - 配置 SSH 密钥登录
# - 修改 SSH 端口
# - 配置连接超时
# - 禁用 root 密码登录
```

### VPS 测试

```bash
# YABS 性能测试（选项 8）
./scripts/yabs_test.sh quick      # 快速测试

# IP 质量检测（选项 9）
./scripts/ip_quality_test.sh dual # 双栈检测

# 网络质量检测（选项 10）
./scripts/network_quality_test.sh dual # 双栈检测
```

## 🔧 独立运行

你也可以单独运行各个模块：

```bash
# 系统更新
sudo ./scripts/system_update.sh

# UFW 防火墙
sudo ./scripts/ufw_manager.sh install-common    # 常用端口

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

## 🛡️ 安全建议

1. **SSH 安全**
   - 修改默认 SSH 端口（推荐 10000-65000）
   - 禁用 root 密码登录
   - 使用 SSH 密钥认证

2. **防火墙配置**
   - 只开放必要的端口
   - 使用 fail2ban 防止暴力破解

3. **系统维护**
   - 定期更新系统
   - 监控系统日志

## 📋 支持的操作系统

- ✅ Ubuntu (18.04+)
- ✅ Debian (9+)
- ✅ CentOS (7+)
- ✅ Rocky Linux (8+)
- ✅ AlmaLinux (8+)
- ✅ Fedora

## ⚠️ 注意事项

1. **权限要求** - 必须使用 root 权限运行（`sudo`）
2. **防火墙配置** - 配置前确保不会锁定自己的 SSH 连接
3. **SSH 安全** - 配置完成后，先在新终端测试再断开当前连接
4. **数据备份** - 卸载组件前建议备份重要数据

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 👨‍💻 作者

**uniquMonte** - [GitHub](https://github.com/uniquMonte)

---

**免责声明**: 本脚本仅供学习和测试使用，使用前请仔细阅读代码。在生产环境使用时请自行承担风险。
