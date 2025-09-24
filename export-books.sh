#!/bin/bash

# Sugjester Book Export Script
# Uses AppleScript to extract book lists from OmniFocus and converts to JSON
# Based on Jon's proven approach for OmniFocus automation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
APPLESCRIPT="$SCRIPT_DIR/export-books.applescript"
LOG_FILE="$DATA_DIR/export.log"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to convert AppleScript date to ISO format
convert_date() {
    local apple_date="$1"
    if [[ -z "$apple_date" ]]; then
        echo "null"
    else
        # AppleScript dates are like "Wednesday, September 24, 2025 at 1:05:23 PM"
        # Convert to ISO format using date command
        local iso_date
        if iso_date=$(date -j -f "%A, %B %d, %Y at %I:%M:%S %p" "$apple_date" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null); then
            echo "\"$iso_date\""
        else
            echo "null"
        fi
    fi
}

# Function to clean task name (remove priority markers)
clean_task_name() {
    local name="$1"
    # Remove ⭐️ and @high-priority markers
    name=$(echo "$name" | sed 's/⭐️//g' | sed 's/@high-priority//g' | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
    echo "$name"
}

# Function to escape JSON strings
escape_json() {
    local str="$1"
    # Remove control characters and escape JSON special characters
    str=$(printf '%s' "$str" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "$str"
}

# Function to convert tags string to JSON array
tags_to_json() {
    local tags_str="$1"
    if [[ -z "$tags_str" ]]; then
        echo "[]"
        return
    fi
    
    local json_array="["
    IFS=',' read -ra tags <<< "$tags_str"
    local first=true
    for tag in "${tags[@]}"; do
        tag=$(echo "$tag" | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
        if [[ -n "$tag" ]]; then
            if [[ "$first" == false ]]; then
                json_array="$json_array, "
            fi
            json_array="$json_array\"$(escape_json "$tag")\""
            first=false
        fi
    done
    json_array="$json_array]"
    echo "$json_array"
}

# Function to process AppleScript output and generate JSON
process_export_data() {
    local raw_data="$1"
    local current_project=""
    local current_language=""
    local current_project_id=""
    local english_books=()
    local japanese_books=()
    local english_buckets=""
    local japanese_buckets=""
    local total_books=0
    
    # Parse the raw data line by line
    while IFS='|' read -r type field1 field2 field3 field4 field5 field6 field7 field8; do
        case "$type" in
            "EXPORT_SUMMARY")
                total_books="$field1"
                ;;
            "PROJECT_START")
                current_project="$field1"
                current_language="$field2"
                current_project_id="$field3"
                log "Processing project: $current_project ($current_language)"
                ;;
            "PROJECT_END")
                current_project=""
                current_language=""
                current_project_id=""
                ;;
            "BOOK")
                if [[ -n "$current_project" ]]; then
                    local task_id="$field1"
                    local task_name="$field2"
                    local priority="$field3"
                    local date_added="$field4"
                    local notes="$field5"
                    local tags="$field6"
                    local defer_date="$field7"
                    local due_date="$field8"
                    
                    # Clean the task name
                    local clean_name
                    clean_name=$(clean_task_name "$task_name")
                    
                    # Convert dates
                    local iso_added
                    local iso_defer
                    local iso_due
                    iso_added=$(convert_date "$date_added")
                    iso_defer=$(convert_date "$defer_date")
                    iso_due=$(convert_date "$due_date")
                    
                    # Convert tags to JSON array
                    local tags_json
                    tags_json=$(tags_to_json "$tags")
                    
                    # Create book JSON object
                    local book_json
                    book_json=$(cat << EOF
{
  "title": "$(escape_json "$clean_name")",
  "project": "$(escape_json "$current_project")",
  "bucket": "$(escape_json "$current_project")",
  "priority": "$priority",
  "dateAdded": $iso_added,
  "notes": "$(escape_json "$notes")",
  "tags": $tags_json,
  "deferDate": $iso_defer,
  "dueDate": $iso_due,
  "projectId": "omnifocus:///project/$current_project_id"
}
EOF
                    )
                    
                    # Add to appropriate language array
                    if [[ "$current_language" == "english" ]]; then
                        english_books+=("$book_json")
                    elif [[ "$current_language" == "japanese" ]]; then
                        japanese_books+=("$book_json")
                    fi
                fi
                ;;
        esac
    done <<< "$raw_data"
    
    # Generate unified export with all books
    local total_books=$((${#english_books[@]} + ${#japanese_books[@]}))
    
    if [[ $total_books -gt 0 ]]; then
        # Group English books by bucket
        local books_to_consider=""
        local books_owned=""
        local first_consider=true
        local first_owned=true
        
        for book in "${english_books[@]}"; do
            if echo "$book" | grep -q '"project": "Books to consider"'; then
                if [[ "$first_consider" == false ]]; then
                    books_to_consider="$books_to_consider, "
                fi
                books_to_consider="$books_to_consider$book"
                first_consider=false
            elif echo "$book" | grep -q '"project": "Books owned to read"'; then
                if [[ "$first_owned" == false ]]; then
                    books_owned="$books_owned, "
                fi
                books_owned="$books_owned$book"
                first_owned=false
            fi
        done
        
        # Group Japanese books
        local japanese_books_list=""
        local first_japanese=true
        for book in "${japanese_books[@]}"; do
            if [[ "$first_japanese" == false ]]; then
                japanese_books_list="$japanese_books_list, "
            fi
            japanese_books_list="$japanese_books_list$book"
            first_japanese=false
        done

        # Create unified JSON structure
        cat > "$DATA_DIR/books-to-consider.json" << EOF
{
  "exportDate": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "totalBooks": $total_books,
  "sourceProjects": [
    { "name": "Books to consider", "id": "omnifocus:///project/aCuCB0X3CYn" },
    { "name": "Books owned to read", "id": "omnifocus:///project/gipgWMqDMdb" },
    { "name": "Japanese books to consider", "id": "omnifocus:///project/bPvbY14zt9G" }
  ],
  "buckets": {
    "Books to consider": [$books_to_consider],
    "Books owned to read": [$books_owned],
    "Japanese books to consider": [$japanese_books_list]
  }
}
EOF
        log "Generated unified export with $total_books books (${#english_books[@]} English, ${#japanese_books[@]} Japanese)"
    fi
    
    # Generate summary
    cat > "$DATA_DIR/export-summary.json" << EOF
{
  "exportDate": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "unified": {
    "totalBooks": $total_books,
    "filePath": "$DATA_DIR/books-to-consider.json",
    "languages": {
      "english": ${#english_books[@]},
      "japanese": ${#japanese_books[@]}
    }
  },
  "sourceProjects": {
    "Books to consider": "omnifocus:///project/aCuCB0X3CYn",
    "Books owned to read": "omnifocus:///project/gipgWMqDMdb", 
    "Japanese books to consider": "omnifocus:///project/bPvbY14zt9G"
  }
}
EOF
    
    log "Export summary: $total_books total books (${#english_books[@]} English, ${#japanese_books[@]} Japanese)"
}

# Main execution
main() {
    log "Starting Sugjester book export..."
    
    # Check if OmniFocus is running
    if ! pgrep -x "OmniFocus" > /dev/null; then
        log "OmniFocus is not running. Attempting to launch..."
        open -a "OmniFocus 4"
        sleep 5
    fi
    
    # Run AppleScript to get book data
    log "Querying OmniFocus for book data..."
    
    if [[ ! -f "$APPLESCRIPT" ]]; then
        log "ERROR: AppleScript not found: $APPLESCRIPT"
        exit 1
    fi
    
    local export_data
    export_data=$(osascript "$APPLESCRIPT" 2>&1)
    
    # Check for errors
    if [[ "$export_data" == ERROR:* ]]; then
        log "AppleScript error: $export_data"
        exit 1
    fi
    
    # Process the data and generate JSON files
    log "Converting to JSON format..."
    process_export_data "$export_data"
    
    # Optional: Git commit if this is a git repo
    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        cd "$SCRIPT_DIR"
        git add data/*.json 2>/dev/null || true
        if ! git diff --cached --exit-code > /dev/null 2>&1; then
            git commit -m "Auto-update book lists - $(date '+%Y-%m-%d %H:%M')" || log "Git commit failed"
            log "Changes committed to git"
        else
            log "No changes to commit"
        fi
    fi
    
    log "Book export completed successfully"
    
    # Show results
    local english_count
    local japanese_count
    english_count=$(jq -r '.results.english.count // 0' "$DATA_DIR/export-summary.json" 2>/dev/null || echo "0")
    japanese_count=$(jq -r '.results.japanese.count // 0' "$DATA_DIR/export-summary.json" 2>/dev/null || echo "0")
    
    echo ""
    echo "📚 Sugjester Book Export Complete!"
    echo "English books: $english_count"
    echo "Japanese books: $japanese_count"
    echo "Files saved to: $DATA_DIR"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
