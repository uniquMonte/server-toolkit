# VPS 一键部署脚本

一个功能强大的 VPS 自动化部署脚本集合，可快速在新购买的 VPS 上安装和配置常用工具。

## ✨ 功能特性

- 🔄 **系统更新** - 自动更新系统软件包并安装常用工具
- 🔒 **UFW 防火墙** - 安装和配置防火墙规则
- 🐳 **Docker** - 安装 Docker 和 Docker Compose
- 🌐 **Nginx** - 安装 Nginx Web 服务器
- 🔐 **Certbot** - 安装 Let's Encrypt SSL 证书工具
- ✅ **安装/卸载** - 所有组件都支持完整的安装和卸载功能

## 🚀 快速开始

### 一键安装（推荐）

使用以下命令直接从 GitHub 运行脚本：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)
```

或者使用 wget：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)
```

### 本地安装

1. 克隆仓库：

```bash
git clone https://github.com/uniquMonte/vps-setup.git
cd vps-setup
```

2. 运行安装脚本：

```bash
chmod +x install.sh
sudo ./install.sh
```

## 📋 支持的操作系统

- ✅ Ubuntu (18.04+)
- ✅ Debian (9+)
- ✅ CentOS (7+)
- ✅ Rocky Linux (8+)
- ✅ AlmaLinux (8+)
- ✅ Fedora

## 🎯 功能说明

### 1. 系统更新

自动更新系统软件包并安装以下常用工具：
- curl, wget, git
- vim, nano
- htop, net-tools
- 其他系统必需工具

### 2. UFW 防火墙

安装和配置 UFW 防火墙，支持：
- 自定义 SSH 端口
- HTTP/HTTPS 端口配置
- 自定义端口规则
- 完整的卸载功能

### 3. Docker

安装最新版本的 Docker，包括：
- Docker Engine
- Docker CLI
- Docker Compose Plugin
- 可选的镜像加速配置
- 用户组权限配置

### 4. Nginx

安装和配置 Nginx Web 服务器：
- 性能优化配置
- 安全 Headers 配置
- Gzip 压缩
- 防火墙规则配置

### 5. Certbot

安装 Let's Encrypt SSL 证书工具：
- 自动续期配置
- Nginx 插件支持
- 简单的证书申请流程

## 🔧 使用方法

### 交互式菜单

运行主脚本后会显示交互式菜单：

```
═══════════════════════════════════════
           主菜单 Main Menu
═══════════════════════════════════════
1. 一键安装所有组件
2. 系统更新
3. UFW 防火墙管理
4. Docker 管理
5. Nginx 管理
0. 退出
═══════════════════════════════════════
```

### 独立运行模块

你也可以单独运行各个模块：

#### 系统更新
```bash
sudo ./scripts/system_update.sh
```

#### UFW 防火墙
```bash
# 安装
sudo ./scripts/ufw_manager.sh install

# 卸载
sudo ./scripts/ufw_manager.sh uninstall
```

#### Docker
```bash
# 安装 Docker
sudo ./scripts/docker_manager.sh install

# 安装 Docker + Docker Compose
sudo ./scripts/docker_manager.sh install-compose

# 卸载
sudo ./scripts/docker_manager.sh uninstall
```

#### Nginx
```bash
# 安装 Nginx
sudo ./scripts/nginx_manager.sh install

# 安装 Nginx + Certbot
sudo ./scripts/nginx_manager.sh install-certbot

# 卸载
sudo ./scripts/nginx_manager.sh uninstall
```

## 📝 使用示例

### 场景 1: 新 VPS 完整部署

```bash
# 一键运行
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/vps-setup/main/install.sh)

# 选择菜单选项 1 - 一键安装所有组件
# 按照提示配置各个组件
```

### 场景 2: 只安装 Docker

```bash
# 克隆仓库
git clone https://github.com/uniquMonte/vps-setup.git
cd vps-setup

# 安装 Docker 和 Docker Compose
sudo ./scripts/docker_manager.sh install-compose
```

### 场景 3: 配置 Nginx + SSL

```bash
# 运行主脚本
sudo ./install.sh

# 选择菜单选项 5 - Nginx 管理
# 选择安装 Nginx + Certbot
# 安装完成后，申请 SSL 证书：
sudo certbot --nginx -d your-domain.com
```

## 🛡️ 安全建议

1. **SSH 安全**
   - 修改默认 SSH 端口
   - 禁用 root 密码登录
   - 使用 SSH 密钥认证

2. **防火墙配置**
   - 只开放必要的端口
   - 定期审查防火墙规则
   - 使用 fail2ban 防止暴力破解

3. **系统维护**
   - 定期更新系统
   - 监控系统日志
   - 设置自动备份

## ❗ 注意事项

1. **权限要求**
   - 所有脚本必须使用 root 权限运行
   - 建议使用 `sudo` 命令运行

2. **防火墙配置**
   - 配置 UFW 时请确保不会锁定自己的 SSH 连接
   - 建议先配置 SSH 端口规则

3. **数据备份**
   - 卸载组件前建议备份重要数据
   - 卸载 Docker 会删除所有容器和镜像

4. **系统兼容性**
   - 脚本在主流 Linux 发行版上测试通过
   - 在生产环境使用前建议先在测试环境验证

## 🔍 故障排除

### 问题 1: 脚本下载失败

```bash
# 检查网络连接
ping raw.githubusercontent.com

# 尝试使用代理或修改 DNS
# 或者直接克隆仓库后本地运行
```

### 问题 2: Docker 安装失败

```bash
# 检查系统是否支持
uname -r  # 内核版本应该 >= 3.10

# 检查是否有旧版本残留
docker --version
sudo apt remove docker docker-engine docker.io containerd runc
```

### 问题 3: UFW 配置后无法连接 SSH

```bash
# 通过 VPS 控制台连接
# 检查 UFW 状态
sudo ufw status

# 允许 SSH 端口
sudo ufw allow 22/tcp

# 或者临时禁用 UFW
sudo ufw disable
```

## 📚 相关资源

- [Docker 官方文档](https://docs.docker.com/)
- [Nginx 官方文档](https://nginx.org/en/docs/)
- [UFW 使用指南](https://help.ubuntu.com/community/UFW)
- [Let's Encrypt 文档](https://letsencrypt.org/docs/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 👨‍💻 作者

- **uniquMonte** - [GitHub](https://github.com/uniquMonte)

## 🌟 Star History

如果这个项目对你有帮助，请给个 Star ⭐

---

**免责声明**: 本脚本仅供学习和测试使用，使用前请仔细阅读代码。在生产环境使用时请自行承担风险。
