# VPS Quick Setup Script

Quickly install and configure common tools on newly purchased VPS servers.

## Quick Start

### One-line Installation (Recommended)

**Smart installer (works on fresh systems):**
```bash
command -v curl >/dev/null 2>&1 || { command -v apt-get >/dev/null 2>&1 && apt-get update -qq && apt-get install -y curl || yum install -y curl || dnf install -y curl; } && bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

This command will:
1. Check if curl is installed
2. Auto-install curl if missing (based on your OS)
3. Download and run the installation script

### Alternative Methods

**If you have curl already installed:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

**Using wget instead:**
```bash
bash <(wget -qO- https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

### Manual Installation (If automatic fails)

If the smart installer doesn't work, manually install curl first:

**For Debian/Ubuntu:**
```bash
apt update && apt install -y curl
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

**For CentOS/Rocky Linux/AlmaLinux:**
```bash
yum install -y curl
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

**For Fedora:**
```bash
dnf install -y curl
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
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

## Supported Systems

Ubuntu • Debian • CentOS • Rocky Linux • AlmaLinux • Fedora

## Acknowledgments

This script integrates the following excellent open-source projects:

**Testing Tools:**
- **[YABS](https://github.com/masonr/yet-another-bench-script)** - Yet Another Bench Script for VPS performance testing
- **[IPQuality](https://github.com/xykt/IPQuality)** - IP quality and reputation detection tool
- **[NetQuality](https://github.com/xykt/NetQuality)** - Network quality check script

**System Tools:**
- **[Reinstall](https://github.com/bin456789/reinstall)** - One-click reinstallation script for VPS operating systems

Special thanks to the authors and contributors of these projects!

---

MIT License | [GitHub](https://github.com/uniquMonte/server-toolkit)
