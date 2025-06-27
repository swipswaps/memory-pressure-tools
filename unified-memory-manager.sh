#!/usr/bin/env bash
################################################################################
# unified-memory-manager.sh — Unified Multi-Tier Memory Protection Management
# WHAT: Manages and monitors all three tiers of memory protection
# WHY: Provides centralized control and status monitoring for comprehensive protection
# HOW: Coordinates earlyoom, nohang, systemd-oomd, and KDE Memory Guardian
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.local/share/kde-memory-guardian"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/unified-memory-$(date +%Y%m%d_%H%M%S).log"

# Service names for the three tiers
TIER1_SERVICE="earlyoom.service"
TIER2_SERVICE="nohang.service"
TIER3_SERVICE="systemd-oomd.service"
KDE_GUARDIAN_SERVICE="kde-memory-manager.service"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# ─── SYSTEM STATUS MONITORING ─────────────────────────────────────────────────
# WHAT: Check status of all memory protection services
# WHY: Provides comprehensive overview of protection status
# HOW: Query systemd service status and process information
check_service_status() {
    local service="$1"
    local tier_name="$2"
    
    local status="UNKNOWN"
    local pid=""
    local memory_usage=""
    local uptime=""
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        status="ACTIVE"
        
        # Get PID and process info
        local service_name="${service%.service}"
        if pgrep -f "$service_name" >/dev/null; then
            pid=$(pgrep -f "$service_name" | head -1)
            
            # Get memory usage in MB
            local rss
            rss=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}')
            if [[ -n "$rss" ]]; then
                memory_usage="$((rss / 1024))MB"
            fi
            
            # Get uptime
            uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
        fi
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        status="ENABLED_INACTIVE"
    else
        status="DISABLED"
    fi
    
    printf "%-20s %-15s %-8s %-8s %-10s\n" "$tier_name" "$status" "$pid" "$memory_usage" "$uptime"
}

# ─── MEMORY SYSTEM OVERVIEW ───────────────────────────────────────────────────
# WHAT: Display comprehensive memory protection status
# WHY: Provides at-a-glance view of all protection layers
# HOW: Combine service status with system memory information
show_status() {
    log_message "INFO" "📊 Displaying unified memory protection status"
    
    echo "=== UNIFIED MEMORY PROTECTION STATUS ==="
    echo ""
    
    # System memory overview
    echo "📊 SYSTEM MEMORY OVERVIEW:"
    local total_mem available_mem used_mem swap_total swap_used
    
    if [[ -f /proc/meminfo ]]; then
        total_mem=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
        available_mem=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
        used_mem=$((total_mem - available_mem))
        swap_total=$(awk '/SwapTotal:/ {print int($2/1024)}' /proc/meminfo)
        swap_used=$(awk '/SwapTotal:/ {total=$2} /SwapFree:/ {free=$2} END {print int((total-free)/1024)}' /proc/meminfo)
        
        local mem_percent=$((used_mem * 100 / total_mem))
        local swap_percent=0
        if [[ $swap_total -gt 0 ]]; then
            swap_percent=$((swap_used * 100 / swap_total))
        fi
        
        printf "  Memory: %d/%d MB (%d%% used)\n" "$used_mem" "$total_mem" "$mem_percent"
        printf "  Swap:   %d/%d MB (%d%% used)\n" "$swap_used" "$swap_total" "$swap_percent"
        echo ""
    fi
    
    # Protection tier status
    echo "🛡️ PROTECTION TIER STATUS:"
    printf "%-20s %-15s %-8s %-8s %-10s\n" "TIER" "STATUS" "PID" "MEMORY" "UPTIME"
    printf "%-20s %-15s %-8s %-8s %-10s\n" "----" "------" "---" "------" "------"
    
    check_service_status "$TIER1_SERVICE" "Tier 1 (earlyoom)"
    check_service_status "$TIER2_SERVICE" "Tier 2 (nohang)"
    check_service_status "$TIER3_SERVICE" "Tier 3 (systemd-oomd)"
    check_service_status "$KDE_GUARDIAN_SERVICE" "KDE Guardian"
    
    echo ""
    
    # Recent activity summary
    echo "📈 RECENT ACTIVITY (last 24 hours):"
    
    # Check for OOM kills in journal
    local oom_kills
    oom_kills=$(journalctl --since "24 hours ago" | grep -i "killed process\|oom-kill\|out of memory" | wc -l)
    echo "  OOM Events: $oom_kills"
    
    # Check for memory pressure events
    local pressure_events
    pressure_events=$(journalctl --since "24 hours ago" -u "$TIER1_SERVICE" -u "$TIER2_SERVICE" -u "$TIER3_SERVICE" | grep -i "memory\|pressure\|threshold" | wc -l)
    echo "  Memory Pressure Events: $pressure_events"
    
    echo ""
    echo "📄 Detailed logs: $LOG_FILE"
}

# ─── SERVICE MANAGEMENT ───────────────────────────────────────────────────────
# WHAT: Start, stop, restart, or reload memory protection services
# WHY: Provides centralized control over all protection tiers
# HOW: Execute systemctl commands with proper error handling
manage_services() {
    local action="$1"
    shift
    local services=("$@")
    
    if [[ ${#services[@]} -eq 0 ]]; then
        services=("$TIER1_SERVICE" "$TIER2_SERVICE" "$TIER3_SERVICE" "$KDE_GUARDIAN_SERVICE")
    fi
    
    log_message "ACTION" "🔧 ${action^}ing memory protection services: ${services[*]}"
    
    case "$action" in
        "start"|"stop"|"restart"|"reload")
            for service in "${services[@]}"; do
                echo "📋 ${action^}ing $service..."
                if sudo systemctl "$action" "$service"; then
                    log_message "OK" "✅ $service ${action}ed successfully"
                else
                    log_message "ERROR" "❌ Failed to $action $service"
                fi
            done
            ;;
        "enable"|"disable")
            for service in "${services[@]}"; do
                echo "📋 ${action^}ing $service..."
                if sudo systemctl "$action" "$service"; then
                    log_message "OK" "✅ $service ${action}d successfully"
                else
                    log_message "ERROR" "❌ Failed to $action $service"
                fi
            done
            ;;
        *)
            echo "❌ Unknown action: $action"
            echo "📝 Valid actions: start, stop, restart, reload, enable, disable"
            return 1
            ;;
    esac
}

# ─── INSTALLATION ORCHESTRATION ───────────────────────────────────────────────
# WHAT: Install all memory protection tiers in correct order
# WHY: Ensures proper dependencies and coordination between tiers
# HOW: Execute installation scripts in sequence with error handling
install_all_tiers() {
    log_message "START" "🚀 Installing all memory protection tiers"
    
    echo "=== INSTALLING UNIFIED MEMORY PROTECTION ==="
    echo "Installing all three tiers of memory protection..."
    echo ""
    
    # Tier 1: earlyoom (foundational protection)
    echo "🛡️ INSTALLING TIER 1: earlyoom (Proactive OOM Prevention)"
    if [[ -x "$SCRIPT_DIR/install-earlyoom.sh" ]]; then
        if "$SCRIPT_DIR/install-earlyoom.sh"; then
            log_message "OK" "✅ Tier 1 (earlyoom) installed successfully"
        else
            log_message "ERROR" "❌ Tier 1 (earlyoom) installation failed"
            echo "❌ Tier 1 installation failed - aborting"
            return 1
        fi
    else
        log_message "ERROR" "❌ earlyoom installer not found"
        echo "❌ earlyoom installer not found at $SCRIPT_DIR/install-earlyoom.sh"
        return 1
    fi
    
    echo ""
    
    # Tier 2: nohang (advanced management)
    echo "🧠 INSTALLING TIER 2: nohang (Advanced Memory Management)"
    if [[ -x "$SCRIPT_DIR/install-nohang.sh" ]]; then
        if "$SCRIPT_DIR/install-nohang.sh"; then
            log_message "OK" "✅ Tier 2 (nohang) installed successfully"
        else
            log_message "ERROR" "❌ Tier 2 (nohang) installation failed"
            echo "⚠️ Tier 2 installation failed - continuing with Tier 3"
        fi
    else
        log_message "WARN" "⚠️ nohang installer not found"
        echo "⚠️ nohang installer not found - skipping Tier 2"
    fi
    
    echo ""
    
    # Tier 3: systemd-oomd (emergency fallback)
    echo "🛡️ INSTALLING TIER 3: systemd-oomd (Emergency Fallback)"
    if [[ -x "$SCRIPT_DIR/configure-systemd-oomd.sh" ]]; then
        if "$SCRIPT_DIR/configure-systemd-oomd.sh"; then
            log_message "OK" "✅ Tier 3 (systemd-oomd) configured successfully"
        else
            log_message "WARN" "⚠️ Tier 3 (systemd-oomd) configuration failed"
            echo "⚠️ Tier 3 configuration failed - not critical"
        fi
    else
        log_message "WARN" "⚠️ systemd-oomd configurator not found"
        echo "⚠️ systemd-oomd configurator not found - skipping Tier 3"
    fi
    
    echo ""
    echo "=== INSTALLATION COMPLETE ==="
    echo "✅ Multi-tier memory protection installed"
    echo "🔄 Reboot recommended for full activation"
    echo ""
    
    # Show final status
    show_status
}

# ─── USAGE INFORMATION ────────────────────────────────────────────────────────
show_usage() {
    cat << 'EOF'
=== UNIFIED MEMORY PROTECTION MANAGER ===

USAGE:
  unified-memory-manager.sh [COMMAND] [OPTIONS]

COMMANDS:
  status                    Show comprehensive protection status
  install                   Install all memory protection tiers
  start [services...]       Start memory protection services
  stop [services...]        Stop memory protection services
  restart [services...]     Restart memory protection services
  enable [services...]      Enable services for automatic startup
  disable [services...]     Disable automatic startup
  logs [service]           Show logs for specific service

EXAMPLES:
  # Show current status
  ./unified-memory-manager.sh status
  
  # Install all protection tiers
  ./unified-memory-manager.sh install
  
  # Restart all services
  ./unified-memory-manager.sh restart
  
  # Start only Tier 1 and 2
  ./unified-memory-manager.sh start earlyoom.service nohang.service
  
  # View earlyoom logs
  ./unified-memory-manager.sh logs earlyoom

PROTECTION TIERS:
  Tier 1: earlyoom          - Proactive OOM prevention (15% threshold)
  Tier 2: nohang            - Advanced memory management (20% threshold)
  Tier 3: systemd-oomd      - Emergency fallback (80% pressure threshold)
  
SERVICES:
  earlyoom.service          - Tier 1 protection service
  nohang.service            - Tier 2 protection service
  systemd-oomd.service      - Tier 3 protection service
  kde-memory-manager.service - KDE Memory Guardian service
EOF
}

# ─── MAIN EXECUTION ───────────────────────────────────────────────────────────
main() {
    local command="${1:-status}"
    
    case "$command" in
        "status"|"show"|"info")
            show_status
            ;;
        "install"|"setup")
            install_all_tiers
            ;;
        "start"|"stop"|"restart"|"reload"|"enable"|"disable")
            shift
            manage_services "$command" "$@"
            ;;
        "logs"|"log")
            local service="${2:-earlyoom}"
            if [[ "$service" != *.service ]]; then
                service="${service}.service"
            fi
            echo "📄 Showing logs for $service:"
            journalctl -u "$service" -f
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            echo "❌ Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
