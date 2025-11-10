# VPS Quick Setup Script

Quickly install and configure common tools on newly purchased VPS servers.

## Quick Start

```bash
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

**Management Tools:**
- **[Server Traffic Reporter](https://github.com/uniquMonte/server-traffic-reporter)** - Automated traffic monitoring and reporting
- **[Server Backup](https://github.com/uniquMonte/server-backup)** - Encrypted automated backup solution with cloud storage support

Special thanks to the authors and contributors of these projects!

---

MIT License | [GitHub](https://github.com/uniquMonte/server-toolkit)
