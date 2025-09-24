#!/bin/bash

# OmniFocus Change Tracker
# Detects and logs changes in OmniFocus database hourly

set -e

# Configuration
SYNC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVITY_DIR="$SYNC_ROOT/activity"
CHANGES_DIR="$ACTIVITY_DIR/changes"
STATE_DIR="$ACTIVITY_DIR/state"
APPLESCRIPT="$SYNC_ROOT/scripts/change-tracker.applescript"
LOG_FILE="/tmp/omnifocus-sync.log"

# Ensure directories exist
mkdir -p "$CHANGES_DIR" "$STATE_DIR"

# Get today's files
TODAY=$(date +%Y-%m-%d)
TODAY_LOG="$CHANGES_DIR/$TODAY.log"
CURRENT_STATE="$STATE_DIR/current.txt"
LAST_STATE="$STATE_DIR/last.txt"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to compare states and generate change log
generate_change_log() {
    local changes=""
    local change_count=0
    
    # Header for today's changes
    if [[ ! -f "$TODAY_LOG" ]]; then
        echo "# OmniFocus Changes - $TODAY" > "$TODAY_LOG"
        echo "" >> "$TODAY_LOG"
    fi
    
    # Start this sync's entry
    echo "## $(date '+%H:%M') Sync" >> "$TODAY_LOG"
    
    # Simple diff-based approach
    if [[ -f "$LAST_STATE" ]]; then
        # Get new lines (tasks/projects added)
        local new_items=$(comm -13 <(grep "^TASK\|^PROJECT" "$LAST_STATE" | sort) <(grep "^TASK\|^PROJECT" "$CURRENT_STATE" | sort))
        
        # Get removed lines (tasks/projects deleted)
        local removed_items=$(comm -23 <(grep "^TASK\|^PROJECT" "$LAST_STATE" | sort) <(grep "^TASK\|^PROJECT" "$CURRENT_STATE" | sort))
        
        # Process new items
        if [[ -n "$new_items" ]]; then
            echo "### New Items" >> "$TODAY_LOG"
            while IFS='|' read -r type id name project_or_date mod_date; do
                if [[ "$type" == "TASK" ]]; then
                    echo "- Task: \"$name\" in $project_or_date" >> "$TODAY_LOG"
                    ((change_count++))
                elif [[ "$type" == "PROJECT" ]]; then
                    echo "- Project: \"$name\"" >> "$TODAY_LOG"
                    ((change_count++))
                fi
            done <<< "$new_items"
        fi
        
        # Process removed items
        if [[ -n "$removed_items" ]]; then
            echo "### Deleted Items" >> "$TODAY_LOG"
            while IFS='|' read -r type id name project_or_date mod_date; do
                if [[ "$type" == "TASK" ]]; then
                    echo "- Task: \"$name\" (was in $project_or_date)" >> "$TODAY_LOG"
                    ((change_count++))
                elif [[ "$type" == "PROJECT" ]]; then
                    echo "- Project: \"$name\"" >> "$TODAY_LOG"
                    ((change_count++))
                fi
            done <<< "$removed_items"
        fi
        
        # Get completed tasks from current state
        local completed_tasks=$(grep "^COMPLETED" "$CURRENT_STATE" || true)
        if [[ -n "$completed_tasks" ]]; then
            echo "### Completed Tasks" >> "$TODAY_LOG"
            while IFS='|' read -r type id name project completion_date; do
                echo "- Task: \"$name\" in $project (completed recently)" >> "$TODAY_LOG"
                ((change_count++))
            done <<< "$completed_tasks"
        fi
        
        # Get task and project counts
        local task_count=$(grep "^SUMMARY" "$CURRENT_STATE" | cut -d'|' -f2)
        local project_count=$(grep "^SUMMARY" "$CURRENT_STATE" | cut -d'|' -f3)
        
        # Summary
        echo "### Summary" >> "$TODAY_LOG"
        echo "$change_count changes detected • $task_count active tasks • $project_count active projects" >> "$TODAY_LOG"
        echo "" >> "$TODAY_LOG"
        
        log "Logged $change_count changes to $TODAY_LOG"
    else
        # First run
        log "First run - establishing baseline state"
        local task_count=$(grep "^SUMMARY" "$CURRENT_STATE" | cut -d'|' -f2)
        local project_count=$(grep "^SUMMARY" "$CURRENT_STATE" | cut -d'|' -f3)
        
        echo "## $(date '+%H:%M') Initial Sync" >> "$TODAY_LOG"
        echo "Baseline established: $task_count active tasks, $project_count active projects" >> "$TODAY_LOG"
        echo "" >> "$TODAY_LOG"
    fi
}

# Main execution
main() {
    log "Starting OmniFocus sync..."
    
    # Run AppleScript to get current state
    log "Querying OmniFocus database..."
    current_data=$(osascript "$APPLESCRIPT" 2>&1)
    
    # Check for errors
    if [[ "$current_data" == ERROR:* ]]; then
        log "AppleScript error: $current_data"
        exit 1
    fi
    
    # Save current state for comparison
    echo "$current_data" > "$CURRENT_STATE"
    
    # Get task and project counts for logging
    local task_count=$(echo "$current_data" | grep "^SUMMARY" | cut -d'|' -f2)
    local project_count=$(echo "$current_data" | grep "^SUMMARY" | cut -d'|' -f3)
    local completed_count=$(echo "$current_data" | grep -c "^COMPLETED" || echo "0")
    
    log "Found $task_count tasks, $project_count projects, $completed_count recent completions"
    
    # Generate change log
    generate_change_log
    
    # Update last state for next run
    cp "$CURRENT_STATE" "$LAST_STATE"
    
    log "Sync completed successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi