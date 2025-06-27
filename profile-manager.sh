#!/bin/bash
"""
Memory Protection Profile Manager
Manages different configuration profiles for various use cases
"""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROFILES_DIR="$REPO_ROOT/configs/profiles"
NOHANG_CONFIG="/usr/local/etc/nohang/nohang.conf"
BACKUP_DIR="$HOME/.config/kde-memory-guardian/backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== MEMORY PROTECTION PROFILE MANAGER ===${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    print_header
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list                    List available profiles"
    echo "  current                 Show current active profile"
    echo "  apply <profile>         Apply a specific profile"
    echo "  backup                  Backup current configuration"
    echo "  restore                 Restore from backup"
    echo "  status                  Show protection status"
    echo "  help                    Show this help message"
    echo ""
    echo "Available Profiles:"
    echo "  developer              Optimized for development work"
    echo "  gaming                 Optimized for gaming performance"
    echo "  server                 Conservative settings for servers"
    echo "  workstation            Balanced for general productivity"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 apply developer"
    echo "  $0 status"
}

list_profiles() {
    print_header
    echo "📋 Available Configuration Profiles:"
    echo ""
    
    if [ -d "$PROFILES_DIR" ]; then
        for profile in "$PROFILES_DIR"/*.conf; do
            if [ -f "$profile" ]; then
                profile_name=$(basename "$profile" .conf)
                description=$(grep "^# Description" -A 3 "$profile" | tail -1 | sed 's/^# //')
                echo -e "  ${GREEN}$profile_name${NC}: $description"
            fi
        done
    else
        print_warning "Profiles directory not found: $PROFILES_DIR"
    fi
}

show_current() {
    print_header
    echo "📊 Current Configuration Status:"
    echo ""
    
    if [ -f "$NOHANG_CONFIG" ]; then
        echo "Active config file: $NOHANG_CONFIG"
        
        # Extract key settings
        mem_min=$(grep "mem_min_percent" "$NOHANG_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        mem_max=$(grep "mem_max_percent" "$NOHANG_CONFIG" | cut -d'=' -f2 | tr -d ' ')
        
        echo "Memory thresholds: ${mem_min}% - ${mem_max}%"
        
        # Check if it matches any profile
        for profile in "$PROFILES_DIR"/*.conf; do
            if [ -f "$profile" ]; then
                profile_name=$(basename "$profile" .conf)
                if cmp -s "$profile" "$NOHANG_CONFIG" 2>/dev/null; then
                    print_success "Active profile: $profile_name"
                    return
                fi
            fi
        done
        
        print_warning "Custom configuration (not matching any profile)"
    else
        print_error "nohang configuration file not found"
    fi
}

backup_config() {
    print_header
    echo "💾 Backing up current configuration..."
    
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_file="$BACKUP_DIR/nohang_config_$timestamp.conf"
    
    if [ -f "$NOHANG_CONFIG" ]; then
        cp "$NOHANG_CONFIG" "$backup_file"
        print_success "Configuration backed up to: $backup_file"
    else
        print_error "No configuration file to backup"
        return 1
    fi
}

apply_profile() {
    local profile_name="$1"
    local profile_file="$PROFILES_DIR/$profile_name.conf"
    
    print_header
    echo "🔧 Applying profile: $profile_name"
    
    if [ ! -f "$profile_file" ]; then
        print_error "Profile not found: $profile_name"
        echo "Available profiles:"
        list_profiles
        return 1
    fi
    
    # Backup current config
    backup_config
    
    # Apply new profile
    echo "Applying profile configuration..."
    if sudo cp "$profile_file" "$NOHANG_CONFIG"; then
        print_success "Profile applied successfully"
        
        # Restart nohang service
        echo "Restarting nohang service..."
        if sudo systemctl restart nohang.service; then
            print_success "nohang service restarted"
        else
            print_warning "Failed to restart nohang service"
        fi
        
        # Show new status
        echo ""
        show_current
    else
        print_error "Failed to apply profile (check sudo permissions)"
        return 1
    fi
}

show_status() {
    print_header
    echo "🛡️ Memory Protection Status:"
    echo ""
    
    # Use unified manager
    if [ -f "$REPO_ROOT/tools/memory-pressure/unified-memory-manager.sh" ]; then
        "$REPO_ROOT/tools/memory-pressure/unified-memory-manager.sh" status
    else
        print_error "Unified memory manager not found"
    fi
}

# Main script logic
case "$1" in
    "list")
        list_profiles
        ;;
    "current")
        show_current
        ;;
    "apply")
        if [ -z "$2" ]; then
            print_error "Profile name required"
            echo "Usage: $0 apply <profile_name>"
            exit 1
        fi
        apply_profile "$2"
        ;;
    "backup")
        backup_config
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
