#!/bin/bash
# KDE Memory Manager - Permanent solution for KDE Plasma memory leaks
# Monitors and automatically restarts KDE services when memory usage gets too high

# Configuration
MEMORY_THRESHOLD=80  # Restart plasmashell if system memory usage > 80%
PLASMA_MEMORY_THRESHOLD=1500000  # Restart plasmashell if it uses > 1.5GB (in KB)
KGLOBAL_MEMORY_THRESHOLD=1000000  # Restart kglobalacceld if it uses > 1GB (in KB)
LOG_FILE="$HOME/.local/share/kde-memory-manager.log"
CHECK_INTERVAL=300  # Check every 5 minutes

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_process_memory() {
    local process_name="$1"
    ps -eo pid,rss,comm | grep "$process_name" | grep -v grep | awk '{sum+=$2} END {print sum+0}'
}

get_system_memory_usage() {
    free | grep '^Mem:' | awk '{printf "%.0f", $3/$2 * 100}'
}

restart_plasmashell() {
    log_message "Restarting plasmashell due to high memory usage"
    killall plasmashell 2>/dev/null
    sleep 2
    kstart plasmashell &
    log_message "Plasmashell restarted successfully"
}

restart_kglobalacceld() {
    log_message "Restarting kglobalacceld due to high memory usage"
    killall kglobalacceld 2>/dev/null
    sleep 1
    # kglobalacceld will auto-restart via KDE
    log_message "kglobalacceld restarted"
}

clear_system_caches() {
    log_message "Clearing system caches"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || sudo sysctl vm.drop_caches=3 2>/dev/null
}

check_and_manage_memory() {
    local system_mem_usage=$(get_system_memory_usage)
    local plasma_memory=$(get_process_memory "plasmashell")
    local kglobal_memory=$(get_process_memory "kglobalacceld")
    
    log_message "Memory check - System: ${system_mem_usage}%, Plasma: ${plasma_memory}KB, KGlobal: ${kglobal_memory}KB"
    
    local restart_needed=false
    
    # Check plasmashell memory usage
    if [ "$plasma_memory" -gt "$PLASMA_MEMORY_THRESHOLD" ]; then
        log_message "Plasmashell memory usage too high: ${plasma_memory}KB > ${PLASMA_MEMORY_THRESHOLD}KB"
        restart_plasmashell
        restart_needed=true
    fi
    
    # Check kglobalacceld memory usage
    if [ "$kglobal_memory" -gt "$KGLOBAL_MEMORY_THRESHOLD" ]; then
        log_message "kglobalacceld memory usage too high: ${kglobal_memory}KB > ${KGLOBAL_MEMORY_THRESHOLD}KB"
        restart_kglobalacceld
        restart_needed=true
    fi
    
    # Check overall system memory usage
    if [ "$system_mem_usage" -gt "$MEMORY_THRESHOLD" ]; then
        log_message "System memory usage too high: ${system_mem_usage}% > ${MEMORY_THRESHOLD}%"
        if [ "$restart_needed" = false ]; then
            restart_plasmashell
        fi
        clear_system_caches
    fi
}

# Main monitoring loop
main() {
    log_message "KDE Memory Manager started (PID: $$)"
    log_message "Configuration: Memory threshold: ${MEMORY_THRESHOLD}%, Plasma threshold: ${PLASMA_MEMORY_THRESHOLD}KB, KGlobal threshold: ${KGLOBAL_MEMORY_THRESHOLD}KB"
    
    while true; do
        check_and_manage_memory
        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals gracefully
trap 'log_message "KDE Memory Manager stopped"; exit 0' SIGTERM SIGINT

# Start the main loop
main
