# VPS Quick Setup Script

Quickly install and configure common tools on newly purchased VPS servers.

## Quick Start

### One-line Installation

**Using curl (recommended):**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

**Using wget (alternative):**
```bash
bash <(wget -qO- https://raw.githubusercontent.com/uniquMonte/server-toolkit/main/install.sh)
```

### Fresh System Installation

If your VPS is freshly installed and doesn't have curl or wget, install one first:

**For Debian/Ubuntu:**
```bash
apt update && apt install -y curl
```

**For CentOS/Rocky Linux/AlmaLinux:**
```bash
yum install -y curl
```

**For Fedora:**
```bash
dnf install -y curl
```

Then run the one-line installation command above.

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
