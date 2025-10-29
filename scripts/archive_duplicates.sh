#!/bin/bash

# Archive duplicate screenshot files (keeping the oldest occurrence of each)
# Usage: ./scripts/archive_duplicates.sh

SCREENSHOT_DIR="Resources/screenshots"
ARCHIVE_DIR="archive/$(date +%Y-%m-%d)/duplicate-screenshots"
REPORT_FILE="duplicates_report.txt"

if [ ! -f "$REPORT_FILE" ]; then
    echo "Error: $REPORT_FILE not found. Run ./scripts/find_duplicates.sh first"
    exit 1
fi

echo "Creating archive directory: $ARCHIVE_DIR"
mkdir -p "$ARCHIVE_DIR"

# Counter for tracking
ARCHIVED_COUNT=0
KEPT_COUNT=0

echo ""
echo "Processing duplicates (keeping oldest occurrence of each)..."
echo ""

# Parse the report and archive all but the first (oldest) occurrence
current_hash=""
first_file=""
declare -a dup_files

while IFS= read -r line; do
    if [[ $line =~ ^===\ Hash:\ ([a-f0-9]+)\ \(Count:\ ([0-9]+)\)\ ===$ ]]; then
        # Process previous group if exists
        if [ -n "$first_file" ]; then
            echo "Hash $current_hash: Keeping $first_file"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            
            for dup in "${dup_files[@]}"; do
                if [ -f "$dup" ]; then
                    # Create parent directory structure in archive
                    rel_path="${dup#Resources/screenshots/}"
                    dest_dir="$ARCHIVE_DIR/$(dirname "$rel_path")"
                    mkdir -p "$dest_dir"
                    
                    # Move duplicate to archive
                    mv "$dup" "$ARCHIVE_DIR/$rel_path"
                    echo "  Archived: $dup"
                    ARCHIVED_COUNT=$((ARCHIVED_COUNT + 1))
                fi
            done
            echo ""
        fi
        
        # Start new group
        current_hash="${BASH_REMATCH[1]}"
        first_file=""
        dup_files=()
    elif [[ $line =~ ^Resources/screenshots/ ]]; then
        if [ -z "$first_file" ]; then
            first_file="$line"
        else
            dup_files+=("$line")
        fi
    fi
done < "$REPORT_FILE"

# Process last group
if [ -n "$first_file" ]; then
    echo "Hash $current_hash: Keeping $first_file"
    KEPT_COUNT=$((KEPT_COUNT + 1))
    
    for dup in "${dup_files[@]}"; do
        if [ -f "$dup" ]; then
            rel_path="${dup#Resources/screenshots/}"
            dest_dir="$ARCHIVE_DIR/$(dirname "$rel_path")"
            mkdir -p "$dest_dir"
            
            mv "$dup" "$ARCHIVE_DIR/$rel_path"
            echo "  Archived: $dup"
            ARCHIVED_COUNT=$((ARCHIVED_COUNT + 1))
        fi
    done
    echo ""
fi

echo "============================================"
echo "Summary:"
echo "  Unique files kept: $KEPT_COUNT"
echo "  Duplicate files archived: $ARCHIVED_COUNT"
echo "  Archive location: $ARCHIVE_DIR"
echo "============================================"
