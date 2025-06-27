# 🔧 Memory Pressure Tools

🛡️ **Comprehensive Linux memory management and system stability suite** - Professional tools for preventing OOM kills, managing memory pressure, and maintaining system responsiveness under heavy loads.

## 🚀 Features

### **🎯 Memory Pressure Management**
- **Unified memory manager** with multiple backend support
- **SystemD-OOMD configuration** and optimization
- **EarlyOOM integration** for proactive memory management
- **NoHang installation** and configuration automation

### **⚙️ System Integration**
- **KDE memory management** with Plasma-specific optimizations
- **SystemD services** for automated memory monitoring
- **Profile management** for different system configurations
- **Automatic restart services** for critical system components

### **🔍 Multi-Distribution Support**
- **Fedora** (dnf package management)
- **Ubuntu/Debian** (apt package management)
- **Arch Linux** (pacman package management)
- **Generic Linux** (manual installation fallbacks)

## 📁 Repository Structure

```
memory-pressure-tools/
├── unified-memory-manager.sh         # Core memory management system
├── configure-systemd-oomd.sh         # SystemD OOMD automation
├── install-earlyoom.sh               # EarlyOOM setup and config
├── install-nohang.sh                 # NoHang integration
├── kde-memory-manager.sh             # KDE-specific memory management
├── install-kde-memory-fix.sh         # KDE memory issue fixes
├── profile-manager.sh                # System profile management
├── kde-memory-manager.service        # SystemD service for KDE
├── simple-plasma-restart.service     # Plasma restart service
└── simple-plasma-restart.timer       # Automated restart timer
```

## 🛠️ Installation

### **Quick Start**
```bash
# Clone the repository
git clone https://github.com/swipswaps/memory-pressure-tools.git
cd memory-pressure-tools

# Make scripts executable
chmod +x *.sh

# Install unified memory management (recommended)
sudo ./unified-memory-manager.sh

# Or install individual components
sudo ./install-earlyoom.sh
sudo ./install-nohang.sh
sudo ./configure-systemd-oomd.sh
```

### **KDE Plasma Users**
```bash
# Install KDE-specific memory management
sudo ./install-kde-memory-fix.sh

# Install SystemD services
sudo cp kde-memory-manager.service /etc/systemd/system/
sudo cp simple-plasma-restart.* /etc/systemd/system/
sudo systemctl enable kde-memory-manager.service
sudo systemctl enable simple-plasma-restart.timer
```

## 📈 Usage Examples

### **Unified Memory Management**
```bash
# Install all memory management tools
sudo ./unified-memory-manager.sh

# Check installation status
systemctl status earlyoom
systemctl status systemd-oomd
```

### **EarlyOOM Configuration**
```bash
# Install and configure EarlyOOM
sudo ./install-earlyoom.sh

# Customize memory thresholds (edit the script)
# Default: 10% memory, 5% swap remaining
```

### **SystemD OOMD Setup**
```bash
# Configure SystemD Out-of-Memory Daemon
sudo ./configure-systemd-oomd.sh

# Verify configuration
sudo systemctl status systemd-oomd
```

### **Profile Management**
```bash
# Create system profiles for different scenarios
./profile-manager.sh create gaming
./profile-manager.sh create development
./profile-manager.sh create server

# Switch between profiles
./profile-manager.sh activate gaming
```

## 🎯 Key Benefits

- **🛡️ Prevents System Freezes**: Proactive memory management before OOM conditions
- **⚡ Maintains Responsiveness**: System stays interactive under memory pressure
- **🔧 Multi-Backend Support**: EarlyOOM, SystemD-OOMD, NoHang integration
- **🖥️ Desktop Optimized**: Special handling for KDE Plasma environments
- **📊 Configurable Thresholds**: Customizable memory and swap limits
- **🔄 Automatic Recovery**: SystemD services for automatic restart and monitoring

## ⚙️ Configuration

### **Memory Thresholds**
```bash
# EarlyOOM default settings
MEMORY_THRESHOLD=10    # Kill processes when <10% memory free
SWAP_THRESHOLD=5       # Kill processes when <5% swap free

# SystemD-OOMD settings
DefaultMemoryPressureDurationSec=20s
DefaultMemoryPressureLimit=80%
```

### **KDE Plasma Settings**
```bash
# Plasma restart intervals
RESTART_INTERVAL=3600  # Restart plasma every hour if needed
MEMORY_LIMIT=2048      # Restart if plasma uses >2GB RAM
```

## 🧪 Testing & Verification

```bash
# Test memory pressure simulation
stress --vm 2 --vm-bytes 1G --timeout 60s

# Monitor memory management
journalctl -u earlyoom -f
journalctl -u systemd-oomd -f

# Check system responsiveness
./profile-manager.sh status
```

## 🔧 Advanced Configuration

### **Custom Memory Policies**
```bash
# Edit unified-memory-manager.sh for custom policies
AGGRESSIVE_MODE=true
DESKTOP_OPTIMIZED=true
SERVER_MODE=false
```

### **Integration with Monitoring**
```bash
# Enable detailed logging
export MEMORY_TOOLS_DEBUG=1
./unified-memory-manager.sh

# Integration with system monitoring
systemctl enable kde-memory-manager.service
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/memory-optimization`)
3. Commit your changes (`git commit -m 'Add memory optimization feature'`)
4. Push to the branch (`git push origin feature/memory-optimization`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [kde-memory-guardian](https://github.com/swipswaps/kde-memory-guardian) - Comprehensive KDE memory management
- [performance-monitoring-suite](https://github.com/swipswaps/performance-monitoring-suite) - System performance analysis
- [rust-clipboard-suite](https://github.com/swipswaps/rust-clipboard-suite) - Advanced clipboard management

## 📞 Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Built with ❤️ for Linux system stability and performance**
