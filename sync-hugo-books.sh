#!/bin/bash

# Sugjester Hugo Books Sync Script  
# Imports Hugo reading history and adds it to the book data for AI recommendations
# Gives Sugjester complete context of books read vs books to consider

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
LOG_FILE="$DATA_DIR/export.log"
HUGO_SHELF_PATH="/Users/fet/source/metalbat/metalbat-hugo/content/shelf"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] HUGO: $1" | tee -a "$LOG_FILE"
}

# Function to extract books from Hugo shelf with full metadata
extract_hugo_books() {
    if [[ ! -d "$HUGO_SHELF_PATH" ]]; then
        log "Hugo shelf directory not found: $HUGO_SHELF_PATH"
        return 1
    fi
    
    log "Extracting finished books from Hugo shelf..."
    
    # Create temp file for Hugo books JSON
    echo "[]" > "$DATA_DIR/hugo-books-temp.json"
    
    local count=0
    # Process all .md files except _index.md
    find "$HUGO_SHELF_PATH" -name "*.md" ! -name "_index.md" | while read -r file; do
        # Extract all relevant fields from YAML front matter
        local yaml_section
        yaml_section=$(sed -n '/^---$/,/^---$/p' "$file")
        
        local title=$(echo "$yaml_section" | grep '^title:' | sed 's/^title: *//' | sed 's/^["'"'"']\|["'"'"']$//g')
        local author=$(echo "$yaml_section" | grep '^author:' | sed 's/^author: *//' | sed 's/^["'"'"']\|["'"'"']$//g')
        local book_status=$(echo "$yaml_section" | grep '^status:' | sed 's/^status: *//')
        local finished_date=$(echo "$yaml_section" | grep '^finished:' | sed 's/^finished: *//')
        local tags=$(echo "$yaml_section" | grep '^tags:' | sed 's/^tags: *//')
        local isbn=$(echo "$yaml_section" | grep '^isbn:' | sed 's/^isbn: *//')
        
        # Only include books with status "Finished" and a non-empty title
        if [[ -n "$title" && "$book_status" == "Finished" ]]; then
            # Convert finished date to ISO format if possible
            local iso_date="null"
            if [[ -n "$finished_date" && "$finished_date" != "null" ]]; then
                # Try to convert the date (handles formats like "2013-11-18" and "2002ish")
                if [[ "$finished_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    iso_date="\"${finished_date}T00:00:00.000Z\""
                elif [[ "$finished_date" =~ ^[0-9]{4}ish$ ]]; then
                    local year="${finished_date%ish}"
                    iso_date="\"${year}-01-01T00:00:00.000Z\""
                fi
            fi
            
            # Convert tags to JSON array with validation
            local tags_json="[]"
            if [[ -n "$tags" ]]; then
                tags_json="[$(echo "$tags" | sed 's/,/", "/g' | sed 's/^/"/' | sed 's/$/"/' | sed 's/, *$//')]"
                # Validate the tags JSON
                if ! echo "$tags_json" | jq . > /dev/null 2>&1; then
                    tags_json="[]"  # Fall back to empty array if invalid
                fi
            fi
            
            # Escape strings for JSON and validate
            local escaped_title=$(printf '%s' "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
            local escaped_author=$(printf '%s' "$author" | sed 's/\\/\\\\/g; s/"/\\"/g') 
            local escaped_isbn=$(printf '%s' "$isbn" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            # Skip books with potentially problematic characters
            if [[ -z "$escaped_title" ]]; then
                continue
            fi
            
            # Try to add to the JSON array using jq with error handling
            if jq \
                --arg title "$escaped_title" \
                --arg author "$escaped_author" \
                --arg book_status "Finished" \
                --argjson finishedDate "$iso_date" \
                --argjson tags "$tags_json" \
                --arg isbn "$escaped_isbn" \
                --arg source "hugo-shelf" \
                '. += [{title: $title, author: $author, status: $book_status, finishedDate: $finishedDate, tags: $tags, isbn: $isbn, source: $source}]' \
                "$DATA_DIR/hugo-books-temp.json" > "$DATA_DIR/hugo-books-temp2.json" 2>/dev/null; then
                mv "$DATA_DIR/hugo-books-temp2.json" "$DATA_DIR/hugo-books-temp.json"
                ((count++))
            else
                # Skip this book if jq fails
                rm -f "$DATA_DIR/hugo-books-temp2.json"
            fi
        fi
    done
    
    local total_count
    total_count=$(jq '. | length' "$DATA_DIR/hugo-books-temp.json")
    log "Found $total_count finished books in Hugo shelf"
    
    return 0
}

# Function to add Hugo books to the main JSON structure
add_hugo_books_to_json() {
    local books_file="$DATA_DIR/books-to-consider.json"
    local hugo_books_file="$DATA_DIR/hugo-books-temp.json"
    
    if [[ ! -f "$books_file" ]]; then
        log "Books file not found: $books_file"
        return 1
    fi
    
    if [[ ! -f "$hugo_books_file" ]]; then
        log "Hugo books file not found: $hugo_books_file"
        return 1
    fi
    
    log "Adding Hugo reading history to book data..."
    
    # Use jq to add Hugo books as a new bucket
    jq --slurpfile hugo_books "$hugo_books_file" '
        # Add Hugo books as a new "Books read" bucket
        .buckets["Books read"] = $hugo_books[0] |
        
        # Update total book count to include Hugo books
        .totalBooks = ([.buckets[]] | add | length) |
        
        # Update export date
        .exportDate = (now | strftime("%Y-%m-%dT%H:%M:%S.000Z"))
        
    ' "$books_file" > "$DATA_DIR/books-with-hugo-temp.json"
    
    # Replace the original file
    mv "$DATA_DIR/books-with-hugo-temp.json" "$books_file"
    
    local hugo_count
    local new_total
    hugo_count=$(jq '. | length' "$hugo_books_file")
    new_total=$(jq '.totalBooks' "$books_file")
    
    log "Added $hugo_count finished books from Hugo shelf"
    log "Updated books-to-consider.json: total books now $new_total (including $hugo_count read)"
    
    # Clean up temp files
    rm -f "$hugo_books_file"
    
    return 0
}

# Main execution
main() {
    log "Starting Hugo books sync..."
    
    # Check if Hugo repo exists and is up to date
    if [[ -d "/Users/fet/source/metalbat/metalbat-hugo/.git" ]]; then
        log "Updating Hugo repo..."
        cd "/Users/fet/source/metalbat/metalbat-hugo"
        git fetch origin main --quiet 2>/dev/null || log "Git fetch failed (continuing anyway)"
        
        # Check if we're behind
        local behind_count
        behind_count=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")
        if [[ $behind_count -gt 0 ]]; then
            log "Hugo repo is $behind_count commits behind, pulling updates..."
            git pull origin main --quiet 2>/dev/null || log "Git pull failed (continuing with local data)"
        else
            log "Hugo repo is up to date"
        fi
    else
        log "Hugo repo not found or not a git repo, using local data"
    fi
    
    # Extract books from Hugo shelf
    if extract_hugo_books; then
        # Add Hugo books to the main JSON structure
        add_hugo_books_to_json
    else
        log "Failed to extract Hugo books"
        return 1
    fi
    
    log "Hugo books sync completed"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
