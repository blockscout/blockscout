#!/bin/bash

# Exit on error
set -e

# Files to manage
FILES=(
    "apps/indexer/lib/indexer/block/realtime/fetcher.ex"
    "apps/indexer/lib/indexer/fetcher/token_balance.ex"
    "apps/indexer/lib/indexer/fetcher/token.ex"
    "apps/indexer/lib/indexer/transform/token_transfers.ex"
    "apps/indexer/lib/indexer/block/catchup/bound_interval_supervisor.ex"
)

# Configuration variables with defaults
WORKSPACE=${WORKSPACE:-/workspace}
REDUCED_FETCHERS_BRANCH=${REDUCED_FETCHERS_BRANCH:-origin/no-merge/reduce-fetchers}

# Function to check if branch exists
check_branch() {
    if ! git rev-parse --verify "${REDUCED_FETCHERS_BRANCH}" >/dev/null 2>&1; then
        echo "Error: Branch '${REDUCED_FETCHERS_BRANCH}' not found"
        exit 1
    fi
}

# Function to ensure directory exists
ensure_dir() {
    local dir=$(dirname "$1")
    mkdir -p "$dir"
}

# Default mode: copy files and mark as assume-unchanged
copy_and_mark_files() {
    echo "Copying files from ${REDUCED_FETCHERS_BRANCH}..."

    cd "$WORKSPACE"
    
    for file in "${FILES[@]}"; do
        echo "Processing $file..."
        
        # Ensure target directory exists
        ensure_dir "$file"
        
        # Copy file from the branch
        git show "${REDUCED_FETCHERS_BRANCH}:$file" > "$file"
        
        # Mark as assume-unchanged
        git update-index --assume-unchanged "$file"
        
        echo "✓ Copied and marked"
    done
    
    echo "All files processed successfully"
}

# Rollback mode
rollback_files() {
    echo "Rolling back files..."
    local modified_files=()

    cd "$WORKSPACE"
    
    for file in "${FILES[@]}"; do
        echo "Processing $file..."
        
        # Remove assume-unchanged flag
        git update-index --no-assume-unchanged "$file"
        
        # Check if file differs from the branch version
        if ! git diff --quiet "${REDUCED_FETCHERS_BRANCH}" -- "$file"; then
            modified_files+=("$file")
            echo "! File has been modified"
        else
            # File unchanged, safe to checkout
            git checkout -- "$file"
            echo "✓ Restored"
        fi
    done
    
    # Report modified files
    if [ ${#modified_files[@]} -gt 0 ]; then
        echo -e "\nThe following files were modified and not rolled back:"
        for file in "${modified_files[@]}"; do
            echo "- $file"
        done
        echo "Please handle these files manually"
    else
        echo -e "\nAll files successfully rolled back"
    fi
}

# Main script logic
main() {
    # Check if branch exists
    check_branch
    
    if [ "$1" = "--rollback" ]; then
        rollback_files
    else
        copy_and_mark_files
    fi
}

# Execute main with all arguments
main "$@"