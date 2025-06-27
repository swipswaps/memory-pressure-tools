#!/bin/bash
# Install KDE Memory Management Solution
# This script sets up permanent system-wide fixes for KDE memory leaks

set -e

echo "🛠️  Installing KDE Memory Management Solution..."

# Create directories
mkdir -p ~/.local/bin
mkdir -p ~/.config/systemd/user
mkdir -p ~/.local/share

# Install the memory manager script
echo "📋 Installing memory manager script..."
cp kde-memory-manager.sh ~/.local/bin/
chmod +x ~/.local/bin/kde-memory-manager.sh

# Install the systemd service
echo "⚙️  Installing systemd service..."
cp kde-memory-manager.service ~/.config/systemd/user/

# Reload systemd and enable the service
echo "🔄 Enabling automatic startup..."
systemctl --user daemon-reload
systemctl --user enable kde-memory-manager.service
systemctl --user start kde-memory-manager.service

# Configure system-wide memory optimizations
echo "🔧 Configuring system memory optimizations..."

# Create sysctl configuration for better memory management
sudo tee /etc/sysctl.d/99-kde-memory-optimization.conf > /dev/null << 'EOF'
# KDE Memory Optimization Settings
# Reduce swappiness - prefer RAM over swap
vm.swappiness=10

# Improve memory reclaim behavior
vm.vfs_cache_pressure=50

# Reduce dirty page writeback time
vm.dirty_writeback_centisecs=1500

# Optimize memory overcommit
vm.overcommit_memory=1
vm.overcommit_ratio=50

# Improve memory compaction
vm.compact_memory=1
EOF

# Apply sysctl settings immediately
sudo sysctl -p /etc/sysctl.d/99-kde-memory-optimization.conf

# Create KDE configuration optimizations
echo "🎨 Optimizing KDE Plasma settings..."
mkdir -p ~/.config

# Optimize Plasma configuration
cat > ~/.config/plasmarc << 'EOF'
[PlasmaViews][Panel 1]
# Reduce panel memory usage
alignment=132
floating=0

[Theme]
# Use lighter theme to reduce memory
name=breeze

[General]
# Optimize animations to reduce memory usage
AnimationDurationFactor=0.5
EOF

# Create memory monitoring alias
echo "📊 Adding memory monitoring tools..."
cat >> ~/.bashrc << 'EOF'

# KDE Memory Management Aliases
alias memcheck='echo "=== Memory Usage ===" && free -h && echo -e "\n=== Top Memory Processes ===" && ps aux --sort=-%mem | head -10'
alias plasma-restart='killall plasmashell && kstart plasmashell'
alias kde-memory-status='systemctl --user status kde-memory-manager.service'
alias kde-memory-logs='journalctl --user -u kde-memory-manager.service -f'
EOF

# Create desktop notification script for memory warnings
cat > ~/.local/bin/kde-memory-notify.sh << 'EOF'
#!/bin/bash
# Send desktop notification for memory warnings
if command -v notify-send >/dev/null 2>&1; then
    notify-send "KDE Memory Manager" "$1" --icon=dialog-warning
fi
EOF
chmod +x ~/.local/bin/kde-memory-notify.sh

# Set up log rotation for memory manager logs
mkdir -p ~/.config/logrotate
cat > ~/.config/logrotate/kde-memory-manager << 'EOF'
/home/*/.*local/share/kde-memory-manager.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644
}
EOF

echo "✅ Installation complete!"
echo ""
echo "🎯 What was installed:"
echo "   • Automatic KDE memory monitoring service"
echo "   • System-wide memory optimizations"
echo "   • Plasma configuration optimizations"
echo "   • Memory monitoring aliases"
echo "   • Log rotation for memory manager"
echo ""
echo "📊 Useful commands:"
echo "   • memcheck                 - Check current memory usage"
echo "   • plasma-restart          - Manually restart Plasma"
echo "   • kde-memory-status       - Check service status"
echo "   • kde-memory-logs         - View real-time logs"
echo ""
echo "🔄 The service is now running and will:"
echo "   • Monitor memory usage every 5 minutes"
echo "   • Automatically restart Plasma if it uses > 1.5GB"
echo "   • Restart kglobalacceld if it uses > 1GB"
echo "   • Clear system caches when memory usage > 80%"
echo ""
echo "📝 Logs are saved to: ~/.local/share/kde-memory-manager.log"
echo ""
echo "⚠️  Please reboot or log out/in for all optimizations to take effect."
EOF
chmod +x install-kde-memory-fix.sh
