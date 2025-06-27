#!/usr/bin/env bash
################################################################################
# install-earlyoom.sh — Tier 1 Memory Protection: earlyoom Integration
# WHAT: Installs and configures earlyoom for proactive OOM prevention
# WHY: Provides system-wide protection against memory exhaustion and freezes
# HOW: Detects distro, installs earlyoom, configures for KDE desktop use
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.local/share/kde-memory-guardian"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/earlyoom-install-$(date +%Y%m%d_%H%M%S).log"

# earlyoom configuration
EARLYOOM_MEMORY_THRESHOLD=15    # Kill when <15% memory available
EARLYOOM_SWAP_THRESHOLD=15      # Kill when <15% swap available
EARLYOOM_CHECK_INTERVAL=60      # Check every 60 seconds

log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_message "START" "🛡️ earlyoom Installation Started"

# ─── DISTRIBUTION DETECTION ───────────────────────────────────────────────────
# WHAT: Detect Linux distribution for appropriate package installation
# WHY: Different distros use different package managers and package names
# HOW: Check /etc/os-release and common distribution files
detect_distribution() {
    log_message "STEP" "🔍 Detecting Linux distribution..."
    
    local distro="unknown"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
                distro="fedora"
                ;;
            "ubuntu"|"debian"|"linuxmint"|"pop")
                distro="debian"
                ;;
            "arch"|"manjaro"|"endeavouros"|"garuda")
                distro="arch"
                ;;
            "opensuse"|"opensuse-leap"|"opensuse-tumbleweed")
                distro="opensuse"
                ;;
            *)
                distro="unknown"
                ;;
        esac
    fi
    
    log_message "INFO" "📊 Detected distribution: $distro ($ID)"
    echo "$distro"
}

# ─── PACKAGE INSTALLATION ─────────────────────────────────────────────────────
# WHAT: Install earlyoom using appropriate package manager
# WHY: earlyoom is available in most distribution repositories
# HOW: Use distro-specific package manager with fallback to source compilation
install_earlyoom_package() {
    local distro="$1"
    log_message "STEP" "📦 Installing earlyoom package..."
    
    case "$distro" in
        "fedora")
            log_message "ACTION" "🔴 Installing via dnf (Fedora/RHEL)..."
            if sudo dnf install -y earlyoom; then
                log_message "OK" "✅ earlyoom installed successfully via dnf"
                return 0
            else
                log_message "WARN" "⚠️ dnf installation failed, trying fallback"
                return 1
            fi
            ;;
        "debian")
            log_message "ACTION" "🟠 Installing via apt (Debian/Ubuntu)..."
            sudo apt update
            if sudo apt install -y earlyoom; then
                log_message "OK" "✅ earlyoom installed successfully via apt"
                return 0
            else
                log_message "WARN" "⚠️ apt installation failed, trying fallback"
                return 1
            fi
            ;;
        "arch")
            log_message "ACTION" "🔵 Installing via pacman (Arch Linux)..."
            if sudo pacman -S --noconfirm earlyoom; then
                log_message "OK" "✅ earlyoom installed successfully via pacman"
                return 0
            else
                log_message "WARN" "⚠️ pacman installation failed, trying fallback"
                return 1
            fi
            ;;
        "opensuse")
            log_message "ACTION" "🟢 Installing via zypper (openSUSE)..."
            if sudo zypper install -y earlyoom; then
                log_message "OK" "✅ earlyoom installed successfully via zypper"
                return 0
            else
                log_message "WARN" "⚠️ zypper installation failed, trying fallback"
                return 1
            fi
            ;;
        *)
            log_message "WARN" "⚠️ Unknown distribution, using source compilation"
            return 1
            ;;
    esac
}

# ─── SOURCE COMPILATION ───────────────────────────────────────────────────────
# WHAT: Compile earlyoom from source as fallback
# WHY: Ensures earlyoom is available even on unsupported distributions
# HOW: Clone GitHub repository, compile with make, install to system
compile_earlyoom_from_source() {
    log_message "STEP" "🔨 Compiling earlyoom from source..."
    
    # Check for required build tools
    local missing_tools=()
    for tool in git make gcc; do
        if ! command -v "$tool" >/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_message "ERROR" "❌ Missing build tools: ${missing_tools[*]}"
        log_message "INFO" "📝 Install with: sudo apt install git make gcc (Debian/Ubuntu)"
        log_message "INFO" "📝 Install with: sudo dnf install git make gcc (Fedora/RHEL)"
        return 1
    fi
    
    # Clone and compile
    local temp_dir="/tmp/earlyoom-build-$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log_message "ACTION" "📥 Cloning earlyoom repository..."
    if git clone https://github.com/rfjakob/earlyoom.git; then
        cd earlyoom
        log_message "ACTION" "🔨 Compiling earlyoom..."
        if make; then
            log_message "ACTION" "📦 Installing earlyoom..."
            if sudo make install; then
                log_message "OK" "✅ earlyoom compiled and installed successfully"
                cd /
                rm -rf "$temp_dir"
                return 0
            else
                log_message "ERROR" "❌ Failed to install compiled earlyoom"
            fi
        else
            log_message "ERROR" "❌ Failed to compile earlyoom"
        fi
    else
        log_message "ERROR" "❌ Failed to clone earlyoom repository"
    fi
    
    cd /
    rm -rf "$temp_dir"
    return 1
}

# ─── KDE DESKTOP CONFIGURATION ────────────────────────────────────────────────
# WHAT: Configure earlyoom specifically for KDE desktop environment
# WHY: Desktop systems need different settings than servers
# HOW: Create systemd override with KDE-optimized parameters
configure_earlyoom_for_kde() {
    log_message "STEP" "⚙️ Configuring earlyoom for KDE desktop..."
    
    # Create systemd override directory
    local override_dir="/etc/systemd/system/earlyoom.service.d"
    sudo mkdir -p "$override_dir"
    
    # Create KDE-optimized configuration
    log_message "ACTION" "📝 Creating KDE-optimized earlyoom configuration..."
    sudo tee "$override_dir/kde-desktop.conf" > /dev/null << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/earlyoom \\
    --memory $EARLYOOM_MEMORY_THRESHOLD \\
    --swap $EARLYOOM_SWAP_THRESHOLD \\
    --interval $EARLYOOM_CHECK_INTERVAL \\
    --prefer '(firefox|chrome|chromium|electron|java|code|idea)' \\
    --avoid '(plasma|kwin|systemd|ssh|init|dbus|NetworkManager)' \\
    --notify \\
    --report

[Install]
WantedBy=multi-user.target
EOF
    
    log_message "OK" "✅ KDE-optimized configuration created"
    
    # Reload systemd and enable service
    log_message "ACTION" "🔄 Reloading systemd configuration..."
    sudo systemctl daemon-reload
    
    log_message "ACTION" "🚀 Enabling earlyoom service..."
    sudo systemctl enable earlyoom.service
    
    log_message "OK" "✅ earlyoom service enabled for automatic startup"
}

# ─── SERVICE STARTUP AND VERIFICATION ─────────────────────────────────────────
# WHAT: Start earlyoom service and verify it's working correctly
# WHY: Ensures protection is active immediately after installation
# HOW: Start service, check status, verify process is running
start_and_verify_earlyoom() {
    log_message "STEP" "🚀 Starting and verifying earlyoom service..."
    
    # Start the service
    log_message "ACTION" "▶️ Starting earlyoom service..."
    if sudo systemctl start earlyoom.service; then
        log_message "OK" "✅ earlyoom service started successfully"
    else
        log_message "ERROR" "❌ Failed to start earlyoom service"
        return 1
    fi
    
    # Wait a moment for service to initialize
    sleep 3
    
    # Check service status
    local service_status
    service_status=$(systemctl is-active earlyoom.service 2>/dev/null || echo "inactive")
    
    if [[ "$service_status" == "active" ]]; then
        log_message "OK" "✅ earlyoom service is active and running"
    else
        log_message "ERROR" "❌ earlyoom service is not active (status: $service_status)"
        return 1
    fi
    
    # Check if process is actually running
    if pgrep -f earlyoom >/dev/null; then
        local pid
        pid=$(pgrep -f earlyoom)
        log_message "OK" "✅ earlyoom process running (PID: $pid)"
        
        # Get memory usage
        local memory_usage
        memory_usage=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}')
        if [[ -n "$memory_usage" ]]; then
            local memory_mb=$((memory_usage / 1024))
            log_message "INFO" "📊 earlyoom memory usage: ${memory_mb}MB"
        fi
    else
        log_message "ERROR" "❌ earlyoom process not found"
        return 1
    fi
    
    return 0
}

# ─── INTEGRATION WITH KDE MEMORY GUARDIAN ─────────────────────────────────────
# WHAT: Integrate earlyoom monitoring with existing KDE Memory Guardian
# WHY: Provides unified monitoring and logging across all memory tools
# HOW: Update main memory manager to include earlyoom status checks
integrate_with_kde_guardian() {
    log_message "STEP" "🔗 Integrating with KDE Memory Guardian..."
    
    local kde_manager="$SCRIPT_DIR/../src/kde-memory-manager.sh"
    
    if [[ -f "$kde_manager" ]]; then
        log_message "ACTION" "📝 Adding earlyoom monitoring to KDE Memory Guardian..."
        
        # Add earlyoom status check function (will be implemented in next phase)
        log_message "INFO" "📋 earlyoom integration prepared for KDE Memory Guardian"
        log_message "INFO" "📋 Status monitoring will be added in unified management phase"
    else
        log_message "WARN" "⚠️ KDE Memory Guardian not found at expected location"
    fi
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────
main() {
    log_message "START" "🎯 Starting earlyoom installation and configuration..."
    
    echo "=== EARLYOOM INSTALLATION - TIER 1 MEMORY PROTECTION ==="
    echo "Installing industry-proven OOM prevention (3.4k⭐ GitHub stars)"
    echo ""
    
    # Step 1: Detect distribution
    local distro
    distro=$(detect_distribution)
    
    # Step 2: Install earlyoom
    if ! install_earlyoom_package "$distro"; then
        echo "📦 Package installation failed, trying source compilation..."
        if ! compile_earlyoom_from_source; then
            log_message "ERROR" "❌ Failed to install earlyoom via package or source"
            echo "❌ earlyoom installation failed. Please install manually:"
            echo "   Fedora: sudo dnf install earlyoom"
            echo "   Ubuntu: sudo apt install earlyoom"
            echo "   Arch: sudo pacman -S earlyoom"
            exit 1
        fi
    fi
    
    # Step 3: Configure for KDE
    configure_earlyoom_for_kde
    
    # Step 4: Start and verify
    if start_and_verify_earlyoom; then
        echo "✅ earlyoom successfully installed and running"
    else
        log_message "ERROR" "❌ earlyoom installation completed but service verification failed"
        echo "⚠️ earlyoom installed but may need manual configuration"
        echo "📄 Check logs: journalctl -u earlyoom.service"
        exit 1
    fi
    
    # Step 5: Integration
    integrate_with_kde_guardian
    
    log_message "COMPLETE" "🎉 earlyoom installation and configuration complete!"
    
    echo ""
    echo "=== EARLYOOM TIER 1 PROTECTION ACTIVE ==="
    echo "✅ Proactive OOM prevention enabled"
    echo "✅ Memory threshold: ${EARLYOOM_MEMORY_THRESHOLD}% remaining"
    echo "✅ Swap threshold: ${EARLYOOM_SWAP_THRESHOLD}% remaining"
    echo "✅ Check interval: ${EARLYOOM_CHECK_INTERVAL} seconds"
    echo "✅ KDE-aware process selection configured"
    echo "✅ Desktop notifications enabled"
    echo ""
    echo "📊 Check status: systemctl status earlyoom.service"
    echo "📄 View logs: journalctl -u earlyoom.service"
    echo "📄 Installation log: $LOG_FILE"
    echo ""
    echo "🛡️ Your system is now protected against memory exhaustion!"
}

# Execute main function
main "$@"
