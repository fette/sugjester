#!/bin/bash

# Sugjester OmniFocus Export Automation Script
# This script triggers the OmniFocus export and can be scheduled to run automatically

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_FILE="$DATA_DIR/export.log"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Sugjester book export automation..."

# Check if OmniFocus is running
if ! pgrep -x "OmniFocus" > /dev/null; then
    log "OmniFocus is not running. Attempting to launch..."
    open -a "OmniFocus 3"
    sleep 5
fi

# Trigger the OmniFocus automation using AppleScript
# This will execute our Omni Automation plugin
osascript << 'EOF'
tell application "OmniFocus 3"
    activate
    tell front document
        -- Execute our custom export action
        -- Note: The actual command will depend on how the plugin is registered
        try
            execute action "Export Books for Sugjester"
        on error errMsg
            display alert "Export Error" message errMsg
        end try
    end tell
end tell
EOF

export_result=$?

if [ $export_result -eq 0 ]; then
    log "Export completed successfully"
    
    # Check if files were created
    if [ -f "$DATA_DIR/english-books-to-consider.json" ] && [ -f "$DATA_DIR/japanese-books-to-consider.json" ]; then
        log "Both English and Japanese export files found"
        
        # Optional: Git commit the changes if this is a git repo
        if [ -d "$SCRIPT_DIR/.git" ]; then
            cd "$SCRIPT_DIR"
            git add data/*.json
            if ! git diff --cached --exit-code > /dev/null; then
                git commit -m "Auto-update book consideration lists - $(date '+%Y-%m-%d %H:%M')"
                log "Changes committed to git"
            else
                log "No changes to commit"
            fi
        fi
        
        # Optional: Trigger any downstream processing
        # You could add webhook calls, file copying, etc. here
        
    else
        log "Warning: Expected export files not found"
    fi
else
    log "Export failed with exit code: $export_result"
fi

log "Export automation completed"
