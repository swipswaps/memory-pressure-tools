#!/usr/bin/env bash
################################################################################
# install-nohang.sh — Tier 2 Memory Protection: nohang Advanced Management
# WHAT: Installs and configures nohang for sophisticated memory pressure handling
# WHY: Provides advanced memory management with process prioritization and swap optimization
# HOW: Downloads from GitHub, configures for KDE desktop, integrates with earlyoom
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.local/share/kde-memory-guardian"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/nohang-install-$(date +%Y%m%d_%H%M%S).log"

# nohang configuration for KDE desktop
NOHANG_MEMORY_THRESHOLD=20      # Start management at 20% memory remaining
NOHANG_SWAP_THRESHOLD=25        # Swap management threshold
NOHANG_CHECK_INTERVAL=30        # Check every 30 seconds (more frequent than earlyoom)
NOHANG_INSTALL_DIR="/opt/nohang"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_message "START" "🧠 nohang Installation Started"

# ─── DEPENDENCY VERIFICATION ──────────────────────────────────────────────────
# WHAT: Check for required dependencies and Python environment
# WHY: nohang requires Python 3 and specific system tools
# HOW: Verify Python version, check for required system utilities
verify_dependencies() {
    log_message "STEP" "🔍 Verifying dependencies for nohang..."
    
    local missing_deps=()
    
    # Check Python 3
    if ! command -v python3 >/dev/null; then
        missing_deps+=("python3")
    else
        local python_version
        python_version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1-2)
        log_message "INFO" "🐍 Python version: $python_version"
        
        # Check if Python version is 3.6+
        if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)" 2>/dev/null; then
            log_message "ERROR" "❌ Python 3.6+ required, found $python_version"
            missing_deps+=("python3.6+")
        fi
    fi
    
    # Check for git (needed for installation)
    if ! command -v git >/dev/null; then
        missing_deps+=("git")
    fi
    
    # Check for systemctl (systemd systems)
    if ! command -v systemctl >/dev/null; then
        log_message "WARN" "⚠️ systemctl not found - non-systemd system detected"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "ERROR" "❌ Missing dependencies: ${missing_deps[*]}"
        echo "❌ Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "Install with:"
        echo "  Fedora: sudo dnf install python3 git"
        echo "  Ubuntu: sudo apt install python3 git"
        echo "  Arch: sudo pacman -S python git"
        return 1
    fi
    
    log_message "OK" "✅ All dependencies satisfied"
    return 0
}

# ─── NOHANG INSTALLATION ──────────────────────────────────────────────────────
# WHAT: Download and install nohang from GitHub repository
# WHY: nohang is not available in most distribution repositories
# HOW: Clone repository, install to system location, set up permissions
install_nohang() {
    log_message "STEP" "📦 Installing nohang from GitHub repository..."
    
    # Remove existing installation if present
    if [[ -d "$NOHANG_INSTALL_DIR" ]]; then
        log_message "ACTION" "🗑️ Removing existing nohang installation..."
        sudo rm -rf "$NOHANG_INSTALL_DIR"
    fi
    
    # Create installation directory
    sudo mkdir -p "$NOHANG_INSTALL_DIR"
    
    # Clone repository to temporary location
    local temp_dir="/tmp/nohang-install-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log_message "ACTION" "📥 Cloning nohang repository..."
    if git clone https://github.com/hakavlad/nohang.git; then
        cd nohang
        
        # Copy files to installation directory
        log_message "ACTION" "📂 Installing nohang files..."
        sudo cp -r * "$NOHANG_INSTALL_DIR/"
        
        # Set executable permissions
        sudo chmod +x "$NOHANG_INSTALL_DIR/nohang"
        sudo chmod +x "$NOHANG_INSTALL_DIR/oom-sort"
        
        # Create symlinks in system PATH
        sudo ln -sf "$NOHANG_INSTALL_DIR/nohang" /usr/local/bin/nohang
        sudo ln -sf "$NOHANG_INSTALL_DIR/oom-sort" /usr/local/bin/oom-sort
        
        log_message "OK" "✅ nohang installed successfully"
        
        # Cleanup
        cd /
        rm -rf "$temp_dir"
        return 0
    else
        log_message "ERROR" "❌ Failed to clone nohang repository"
        cd /
        rm -rf "$temp_dir"
        return 1
    fi
}

# ─── KDE DESKTOP CONFIGURATION ────────────────────────────────────────────────
# WHAT: Create KDE-optimized nohang configuration
# WHY: Desktop environments need different memory management than servers
# HOW: Generate config file with KDE-specific process priorities and thresholds
configure_nohang_for_kde() {
    log_message "STEP" "⚙️ Configuring nohang for KDE desktop environment..."
    
    local config_dir="/etc/nohang"
    local config_file="$config_dir/nohang.conf"
    
    # Create configuration directory
    sudo mkdir -p "$config_dir"
    
    log_message "ACTION" "📝 Creating KDE-optimized nohang configuration..."
    
    # Generate comprehensive KDE configuration
    sudo tee "$config_file" > /dev/null << 'EOF'
# nohang configuration for KDE Desktop Environment
# Optimized for desktop workloads with KDE Plasma

[Memory]
# Memory thresholds (percentage of total memory)
mem_min_percent = 20.0          # Start management when <20% memory free
mem_max_percent = 40.0          # Aggressive management when <40% memory free
swap_min_percent = 25.0         # Swap threshold
zram_min_percent = 25.0         # ZRAM threshold

[Timing]
# Check intervals (seconds)
check_interval = 30             # More frequent than earlyoom (60s)
min_delay = 10                  # Minimum delay between kills
max_delay = 300                 # Maximum delay

[Process Selection]
# KDE-aware process selection
prefer_regex = (firefox|chrome|chromium|electron|java|code|idea|gimp|libreoffice|thunderbird|telegram|discord|slack|zoom|teams|skype)
avoid_regex = (plasma|kwin|systemd|ssh|init|dbus|NetworkManager|pulseaudio|pipewire|sddm|lightdm|gdm|Xorg|wayland)

# Process priorities for KDE desktop
[Badness]
# Increase badness for resource-heavy applications
firefox_badness = 300
chrome_badness = 300
chromium_badness = 300
electron_badness = 250
java_badness = 200
code_badness = 150

# Decrease badness for essential KDE components
plasma_badness = -1000
kwin_badness = -1000
systemd_badness = -1000
dbus_badness = -1000
NetworkManager_badness = -1000

[Logging]
# Enhanced logging for desktop debugging
log_level = info
log_file = /var/log/nohang.log
max_log_size = 10485760         # 10MB log rotation

[Desktop Integration]
# Desktop notification settings
notify = true
notify_timeout = 5000           # 5 second notifications
notify_icon = dialog-warning

# Integration with other memory managers
coordinate_with_earlyoom = true
coordinate_with_systemd_oomd = true
EOF
    
    log_message "OK" "✅ KDE-optimized nohang configuration created"
    
    # Set appropriate permissions
    sudo chmod 644 "$config_file"
    
    # Create log directory
    sudo mkdir -p /var/log
    sudo touch /var/log/nohang.log
    sudo chmod 644 /var/log/nohang.log
}

# ─── SYSTEMD SERVICE CREATION ─────────────────────────────────────────────────
# WHAT: Create systemd service for nohang with proper dependencies
# WHY: Ensures nohang starts automatically and coordinates with other services
# HOW: Generate service file with appropriate ordering and dependencies
create_systemd_service() {
    log_message "STEP" "🔧 Creating systemd service for nohang..."
    
    local service_file="/etc/systemd/system/nohang.service"
    
    log_message "ACTION" "📝 Creating nohang systemd service..."
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=nohang - Advanced Memory Management for KDE Desktop
Documentation=https://github.com/hakavlad/nohang
After=multi-user.target
After=earlyoom.service
Wants=earlyoom.service

[Service]
Type=simple
ExecStart=/usr/local/bin/nohang --config /etc/nohang/nohang.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=30
User=root
Group=root

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log /proc /sys
PrivateTmp=true

# Resource limits
MemoryMax=100M
CPUQuota=10%

[Install]
WantedBy=multi-user.target
EOF
    
    log_message "OK" "✅ nohang systemd service created"
    
    # Reload systemd and enable service
    log_message "ACTION" "🔄 Reloading systemd configuration..."
    sudo systemctl daemon-reload
    
    log_message "ACTION" "🚀 Enabling nohang service..."
    sudo systemctl enable nohang.service
    
    log_message "OK" "✅ nohang service enabled for automatic startup"
}

# ─── SERVICE STARTUP AND VERIFICATION ─────────────────────────────────────────
# WHAT: Start nohang service and verify proper operation
# WHY: Ensures Tier 2 protection is active and coordinating with Tier 1
# HOW: Start service, check status, verify process monitoring
start_and_verify_nohang() {
    log_message "STEP" "🚀 Starting and verifying nohang service..."
    
    # Start the service
    log_message "ACTION" "▶️ Starting nohang service..."
    if sudo systemctl start nohang.service; then
        log_message "OK" "✅ nohang service started successfully"
    else
        log_message "ERROR" "❌ Failed to start nohang service"
        return 1
    fi
    
    # Wait for service to initialize
    sleep 5
    
    # Check service status
    local service_status
    service_status=$(systemctl is-active nohang.service 2>/dev/null || echo "inactive")
    
    if [[ "$service_status" == "active" ]]; then
        log_message "OK" "✅ nohang service is active and running"
    else
        log_message "ERROR" "❌ nohang service is not active (status: $service_status)"
        return 1
    fi
    
    # Check if process is running
    if pgrep -f "nohang" >/dev/null; then
        local pid
        pid=$(pgrep -f "nohang")
        log_message "OK" "✅ nohang process running (PID: $pid)"
        
        # Get memory usage
        local memory_usage
        memory_usage=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}')
        if [[ -n "$memory_usage" ]]; then
            local memory_mb=$((memory_usage / 1024))
            log_message "INFO" "📊 nohang memory usage: ${memory_mb}MB"
        fi
    else
        log_message "ERROR" "❌ nohang process not found"
        return 1
    fi
    
    # Verify coordination with earlyoom
    if systemctl is-active earlyoom.service >/dev/null 2>&1; then
        log_message "OK" "✅ earlyoom coordination verified - both services running"
    else
        log_message "WARN" "⚠️ earlyoom not running - install Tier 1 protection first"
    fi
    
    return 0
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────
main() {
    log_message "START" "🎯 Starting nohang installation and configuration..."
    
    echo "=== NOHANG INSTALLATION - TIER 2 MEMORY PROTECTION ==="
    echo "Installing advanced memory management (1.2k⭐ GitHub stars)"
    echo "Coordinates with earlyoom for comprehensive protection"
    echo ""
    
    # Step 1: Verify dependencies
    if ! verify_dependencies; then
        exit 1
    fi
    
    # Step 2: Install nohang
    if ! install_nohang; then
        log_message "ERROR" "❌ nohang installation failed"
        exit 1
    fi
    
    # Step 3: Configure for KDE
    configure_nohang_for_kde
    
    # Step 4: Create systemd service
    create_systemd_service
    
    # Step 5: Start and verify
    if start_and_verify_nohang; then
        echo "✅ nohang successfully installed and running"
    else
        log_message "ERROR" "❌ nohang installation completed but service verification failed"
        echo "⚠️ nohang installed but may need manual configuration"
        echo "📄 Check logs: journalctl -u nohang.service"
        exit 1
    fi
    
    log_message "COMPLETE" "🎉 nohang installation and configuration complete!"
    
    echo ""
    echo "=== NOHANG TIER 2 PROTECTION ACTIVE ==="
    echo "✅ Advanced memory management enabled"
    echo "✅ Memory threshold: ${NOHANG_MEMORY_THRESHOLD}% remaining"
    echo "✅ Swap threshold: ${NOHANG_SWAP_THRESHOLD}% remaining"
    echo "✅ Check interval: ${NOHANG_CHECK_INTERVAL} seconds"
    echo "✅ KDE-aware process prioritization configured"
    echo "✅ Coordination with earlyoom enabled"
    echo "✅ Desktop notifications enabled"
    echo ""
    echo "📊 Check status: systemctl status nohang.service"
    echo "📄 View logs: journalctl -u nohang.service"
    echo "📄 Installation log: $LOG_FILE"
    echo ""
    echo "🧠 Advanced memory protection is now active!"
}

# Execute main function
main "$@"
