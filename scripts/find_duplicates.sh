#!/bin/bash

# Find duplicate screenshot files and prepare them for archival
# Usage: ./scripts/find_duplicates.sh

SCREENSHOT_DIR="Resources/screenshots"
ARCHIVE_DIR="archive/$(date +%Y-%m-%d)/duplicate-screenshots"

echo "Finding duplicate files in $SCREENSHOT_DIR..."

# Create a temporary file to store hash -> file mapping
TEMP_FILE=$(mktemp)

# Generate MD5 hashes for all PNG files
find "$SCREENSHOT_DIR" -type f -name "*.png" -exec md5 {} \; | while read line; do
    # Extract hash and filename from md5 output format: "MD5 (path) = hash"
    hash=$(echo "$line" | awk '{print $NF}')
    file=$(echo "$line" | sed 's/MD5 (\(.*\)) = .*/\1/')
    echo "$hash|$file" >> "$TEMP_FILE"
done

# Find duplicates and list all files with the same hash
echo ""
echo "Analyzing duplicates..."
echo ""

# Group by hash and find which have multiple files
sort "$TEMP_FILE" | awk -F'|' '{
    hash=$1
    file=$2
    if (hash in files) {
        files[hash] = files[hash] "\n" file
        counts[hash]++
    } else {
        files[hash] = file
        counts[hash] = 1
    }
}
END {
    for (hash in files) {
        if (counts[hash] > 1) {
            print "=== Hash: " hash " (Count: " counts[hash] ") ==="
            print files[hash]
            print ""
        }
    }
}' > duplicates_report.txt

# Count duplicates
TOTAL_DUPES=$(grep -c "=== Hash:" duplicates_report.txt)
echo "Found $TOTAL_DUPES sets of duplicate files"
echo ""
echo "Report saved to: duplicates_report.txt"
echo ""
echo "To archive duplicates (keeping the first occurrence of each):"
echo "  ./scripts/archive_duplicates.sh"

# Cleanup
rm "$TEMP_FILE"
