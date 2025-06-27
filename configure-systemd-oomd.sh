#!/usr/bin/env bash
################################################################################
# configure-systemd-oomd.sh — Tier 3 Memory Protection: systemd-oomd Emergency Fallback
# WHAT: Configures systemd-oomd as final emergency memory protection layer
# WHY: Provides kernel-level OOM protection when other tools fail
# HOW: Enables and configures systemd-oomd with KDE-optimized settings
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.local/share/kde-memory-guardian"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/systemd-oomd-config-$(date +%Y%m%d_%H%M%S).log"

# systemd-oomd configuration for emergency fallback
OOMD_MEMORY_PRESSURE_THRESHOLD=80      # Emergency threshold (80% memory pressure)
OOMD_SWAP_THRESHOLD=90                 # Emergency swap threshold
OOMD_CHECK_INTERVAL=10                 # Emergency check interval (10 seconds)

log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_message "START" "🛡️ systemd-oomd Configuration Started"

# ─── SYSTEMD VERSION VERIFICATION ─────────────────────────────────────────────
# WHAT: Check if systemd version supports oomd functionality
# WHY: systemd-oomd requires systemd 247+ for full functionality
# HOW: Parse systemd version and check feature availability
verify_systemd_oomd_support() {
    log_message "STEP" "🔍 Verifying systemd-oomd support..."
    
    # Check if systemd is available
    if ! command -v systemctl >/dev/null; then
        log_message "ERROR" "❌ systemd not found - this system doesn't use systemd"
        return 1
    fi
    
    # Get systemd version
    local systemd_version
    systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
    log_message "INFO" "📊 systemd version: $systemd_version"
    
    # Check if version supports oomd (247+)
    if [[ "$systemd_version" -lt 247 ]]; then
        log_message "WARN" "⚠️ systemd version $systemd_version < 247 - limited oomd support"
        echo "⚠️ systemd-oomd requires systemd 247+ for full functionality"
        echo "📊 Current version: $systemd_version"
        echo "🔄 Consider upgrading systemd or using only Tier 1+2 protection"
        return 1
    fi
    
    # Check if systemd-oomd binary exists
    if ! command -v systemd-oomd >/dev/null; then
        log_message "ERROR" "❌ systemd-oomd binary not found"
        echo "❌ systemd-oomd not available on this system"
        echo "📦 Install with: sudo dnf install systemd-oomd (Fedora)"
        echo "📦 Install with: sudo apt install systemd-oomd (Ubuntu 21.04+)"
        return 1
    fi
    
    log_message "OK" "✅ systemd-oomd support verified (version $systemd_version)"
    return 0
}

# ─── MEMORY PRESSURE CONFIGURATION ────────────────────────────────────────────
# WHAT: Configure memory pressure thresholds for desktop use
# WHY: Default systemd-oomd settings are too aggressive for desktop environments
# HOW: Create override configuration with KDE-optimized thresholds
configure_memory_pressure_thresholds() {
    log_message "STEP" "⚙️ Configuring memory pressure thresholds..."
    
    # Create systemd-oomd configuration directory
    local config_dir="/etc/systemd/oomd.conf.d"
    sudo mkdir -p "$config_dir"
    
    # Create KDE desktop configuration
    local config_file="$config_dir/kde-desktop.conf"
    
    log_message "ACTION" "📝 Creating KDE-optimized systemd-oomd configuration..."
    
    sudo tee "$config_file" > /dev/null << EOF
# systemd-oomd configuration for KDE Desktop Environment
# Emergency fallback protection (Tier 3)

[OOM]
# Memory pressure thresholds (emergency levels)
DefaultMemoryPressureThresholdPercent=${OOMD_MEMORY_PRESSURE_THRESHOLD}%
DefaultMemoryPressureLimitPercent=100%

# Swap thresholds (emergency levels)
SwapUsedLimitPercent=${OOMD_SWAP_THRESHOLD}%

# Timing configuration
IntervalSec=${OOMD_CHECK_INTERVAL}s

# KDE-specific process handling
# Prefer killing resource-heavy applications over system components
ManagedOOMPreference=kill

# Logging
LogLevel=info
LogTarget=journal
EOF
    
    log_message "OK" "✅ systemd-oomd configuration created"
    
    # Set appropriate permissions
    sudo chmod 644 "$config_file"
}

# ─── CGROUP CONFIGURATION ─────────────────────────────────────────────────────
# WHAT: Configure cgroup settings for optimal oomd operation
# WHY: systemd-oomd requires proper cgroup v2 configuration
# HOW: Enable memory accounting and pressure monitoring
configure_cgroup_settings() {
    log_message "STEP" "🔧 Configuring cgroup settings for systemd-oomd..."
    
    # Check if cgroup v2 is available
    if [[ ! -d /sys/fs/cgroup/memory.pressure ]]; then
        log_message "WARN" "⚠️ cgroup v2 memory pressure interface not available"
        
        # Check if we're using cgroup v1
        if [[ -d /sys/fs/cgroup/memory ]]; then
            log_message "INFO" "📊 System using cgroup v1 - limited oomd functionality"
            echo "⚠️ System using cgroup v1 - systemd-oomd functionality limited"
            echo "🔄 Consider enabling cgroup v2 for full functionality"
            echo "📝 Add 'systemd.unified_cgroup_hierarchy=1' to kernel parameters"
        fi
    else
        log_message "OK" "✅ cgroup v2 memory pressure interface available"
    fi
    
    # Enable memory accounting for user sessions
    local user_config_dir="/etc/systemd/user.conf.d"
    sudo mkdir -p "$user_config_dir"
    
    local user_config_file="$user_config_dir/memory-accounting.conf"
    
    log_message "ACTION" "📝 Enabling memory accounting for user sessions..."
    
    sudo tee "$user_config_file" > /dev/null << EOF
# Enable memory accounting for user sessions
# Required for systemd-oomd to monitor user processes

[Manager]
DefaultMemoryAccounting=yes
DefaultTasksAccounting=yes
DefaultIOAccounting=yes
EOF
    
    log_message "OK" "✅ Memory accounting configuration created"
    
    # Configure system-wide memory accounting
    local system_config_dir="/etc/systemd/system.conf.d"
    sudo mkdir -p "$system_config_dir"
    
    local system_config_file="$system_config_dir/memory-accounting.conf"
    
    log_message "ACTION" "📝 Enabling system-wide memory accounting..."
    
    sudo tee "$system_config_file" > /dev/null << EOF
# Enable system-wide memory accounting
# Required for systemd-oomd system monitoring

[Manager]
DefaultMemoryAccounting=yes
DefaultTasksAccounting=yes
DefaultIOAccounting=yes
EOF
    
    log_message "OK" "✅ System-wide memory accounting configuration created"
}

# ─── SERVICE COORDINATION ─────────────────────────────────────────────────────
# WHAT: Configure systemd-oomd to coordinate with other memory protection tools
# WHY: Prevents conflicts between different OOM protection mechanisms
# HOW: Set up service dependencies and ordering
configure_service_coordination() {
    log_message "STEP" "🔗 Configuring service coordination..."
    
    # Create systemd-oomd service override
    local override_dir="/etc/systemd/system/systemd-oomd.service.d"
    sudo mkdir -p "$override_dir"
    
    local override_file="$override_dir/kde-coordination.conf"
    
    log_message "ACTION" "📝 Creating service coordination configuration..."
    
    sudo tee "$override_file" > /dev/null << EOF
# systemd-oomd service coordination for KDE Memory Guardian
# Ensures proper ordering with other memory protection tools

[Unit]
# Start after other memory protection tools
After=earlyoom.service
After=nohang.service

# Don't conflict with other OOM tools - work as emergency fallback
Conflicts=

[Service]
# Restart policy for reliability
Restart=always
RestartSec=30

# Resource limits to prevent systemd-oomd from consuming too much memory
MemoryMax=50M
CPUQuota=5%

# Enhanced logging for debugging
Environment=SYSTEMD_LOG_LEVEL=info
EOF
    
    log_message "OK" "✅ Service coordination configuration created"
}

# ─── SERVICE ENABLEMENT AND VERIFICATION ──────────────────────────────────────
# WHAT: Enable systemd-oomd service and verify proper operation
# WHY: Ensures Tier 3 emergency protection is active
# HOW: Enable service, reload configuration, verify status
enable_and_verify_systemd_oomd() {
    log_message "STEP" "🚀 Enabling and verifying systemd-oomd service..."
    
    # Reload systemd configuration
    log_message "ACTION" "🔄 Reloading systemd configuration..."
    sudo systemctl daemon-reload
    
    # Enable systemd-oomd service
    log_message "ACTION" "🚀 Enabling systemd-oomd service..."
    if sudo systemctl enable systemd-oomd.service; then
        log_message "OK" "✅ systemd-oomd service enabled"
    else
        log_message "ERROR" "❌ Failed to enable systemd-oomd service"
        return 1
    fi
    
    # Start systemd-oomd service
    log_message "ACTION" "▶️ Starting systemd-oomd service..."
    if sudo systemctl start systemd-oomd.service; then
        log_message "OK" "✅ systemd-oomd service started"
    else
        log_message "ERROR" "❌ Failed to start systemd-oomd service"
        return 1
    fi
    
    # Wait for service to initialize
    sleep 3
    
    # Check service status
    local service_status
    service_status=$(systemctl is-active systemd-oomd.service 2>/dev/null || echo "inactive")
    
    if [[ "$service_status" == "active" ]]; then
        log_message "OK" "✅ systemd-oomd service is active and running"
    else
        log_message "ERROR" "❌ systemd-oomd service is not active (status: $service_status)"
        return 1
    fi
    
    # Verify process is running
    if pgrep -f "systemd-oomd" >/dev/null; then
        local pid
        pid=$(pgrep -f "systemd-oomd")
        log_message "OK" "✅ systemd-oomd process running (PID: $pid)"
        
        # Get memory usage
        local memory_usage
        memory_usage=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}')
        if [[ -n "$memory_usage" ]]; then
            local memory_mb=$((memory_usage / 1024))
            log_message "INFO" "📊 systemd-oomd memory usage: ${memory_mb}MB"
        fi
    else
        log_message "ERROR" "❌ systemd-oomd process not found"
        return 1
    fi
    
    return 0
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────
main() {
    log_message "START" "🎯 Starting systemd-oomd configuration..."
    
    echo "=== SYSTEMD-OOMD CONFIGURATION - TIER 3 EMERGENCY PROTECTION ==="
    echo "Configuring kernel-level OOM protection as emergency fallback"
    echo "Works with earlyoom (Tier 1) and nohang (Tier 2) for comprehensive protection"
    echo ""
    
    # Step 1: Verify systemd-oomd support
    if ! verify_systemd_oomd_support; then
        echo "❌ systemd-oomd not supported on this system"
        echo "🛡️ Tier 1 (earlyoom) and Tier 2 (nohang) protection still available"
        exit 1
    fi
    
    # Step 2: Configure memory pressure thresholds
    configure_memory_pressure_thresholds
    
    # Step 3: Configure cgroup settings
    configure_cgroup_settings
    
    # Step 4: Configure service coordination
    configure_service_coordination
    
    # Step 5: Enable and verify service
    if enable_and_verify_systemd_oomd; then
        echo "✅ systemd-oomd successfully configured and running"
    else
        log_message "ERROR" "❌ systemd-oomd configuration completed but service verification failed"
        echo "⚠️ systemd-oomd configured but may need manual verification"
        echo "📄 Check logs: journalctl -u systemd-oomd.service"
        exit 1
    fi
    
    log_message "COMPLETE" "🎉 systemd-oomd configuration complete!"
    
    echo ""
    echo "=== SYSTEMD-OOMD TIER 3 EMERGENCY PROTECTION ACTIVE ==="
    echo "✅ Emergency memory protection enabled"
    echo "✅ Memory pressure threshold: ${OOMD_MEMORY_PRESSURE_THRESHOLD}%"
    echo "✅ Swap threshold: ${OOMD_SWAP_THRESHOLD}%"
    echo "✅ Check interval: ${OOMD_CHECK_INTERVAL} seconds"
    echo "✅ Coordination with Tier 1+2 protection configured"
    echo "✅ cgroup v2 memory accounting enabled"
    echo ""
    echo "📊 Check status: systemctl status systemd-oomd.service"
    echo "📄 View logs: journalctl -u systemd-oomd.service"
    echo "📄 Configuration log: $LOG_FILE"
    echo ""
    echo "🛡️ Emergency fallback protection is now active!"
    echo "🔄 Reboot recommended to fully activate cgroup changes"
}

# Execute main function
main "$@"
