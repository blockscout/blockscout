#!/bin/bash

# Usage: ./token_fetcher_timer.sh [elixir|rust]

# Check if the fetcher type is provided
if [ -z "$1" ]; then
    echo "Usage: $0 [elixir|rust]"
    exit 1
fi

FETCHER_TYPE="$1"

# Desired total number of uncataloged tokens (excluding those with skip_metadata = true)
TARGET_UNCATALOGED_COUNT=1000

# Log file for fetcher output
LOG_FILE="fetcher_output.log"

echo "Calculating number of tokens to reset..."

# SQL query to count current uncataloged tokens where skip_metadata != true
SQL_COUNT_UNCATALOGED="SELECT COUNT(*) FROM tokens WHERE cataloged != true AND skip_metadata != true;"

# Get the current count of uncataloged tokens
CURRENT_UNCATALOGED_COUNT=$(psql -A -t -q -X -c "$SQL_COUNT_UNCATALOGED" | tr -d '[:space:]')

echo "Current uncataloged tokens: $CURRENT_UNCATALOGED_COUNT"

# Calculate the number of tokens to reset
TOKENS_TO_RESET=$((TARGET_UNCATALOGED_COUNT - CURRENT_UNCATALOGED_COUNT))

# Ensure that the number of tokens to reset is not negative
if [ "$TOKENS_TO_RESET" -le 0 ]; then
    echo "No tokens need to be reset. There are already $CURRENT_UNCATALOGED_COUNT uncataloged tokens."
else
    echo "Resetting $TOKENS_TO_RESET tokens..."

    # SQL query to reset the required number of tokens
    SQL_UPDATE="UPDATE tokens SET cataloged = false, skip_metadata = NULL WHERE contract_address_hash IN (
        SELECT contract_address_hash FROM tokens WHERE cataloged = true AND skip_metadata != true LIMIT $TOKENS_TO_RESET
    );"

    # Execute the SQL update command
    psql -q -X -c "$SQL_UPDATE"

    echo "Tokens reset."
fi

echo "Starting the $FETCHER_TYPE fetcher..."

# Start the appropriate fetcher and redirect output to log file
if [ "$FETCHER_TYPE" = "elixir" ]; then
    # Start the Elixir fetcher
    mix phx.server > $LOG_FILE 2>&1 &
elif [ "$FETCHER_TYPE" = "rust" ]; then
    # Start the Rust fetcher
    just run > $LOG_FILE 2>&1 &
else
    echo "Invalid fetcher type. Use 'elixir' or 'rust'."
    exit 1
fi

# Get the PID of the fetcher process
FETCHER_PID=$!

echo "$FETCHER_TYPE fetcher started with PID $FETCHER_PID. Waiting for start time in logs..."

# Wait for the "FETCHING START TIME IS {UNIX_TIME}" message and extract the Unix time
START_EPOCH=""

while [ -z "$START_EPOCH" ]; do
    # Use grep to find the line with the start time
    START_TIME_LINE=$(grep "FETCHING START TIME IS" $LOG_FILE)
    if [ ! -z "$START_TIME_LINE" ]; then
        # Extract the Unix timestamp from the log line
        START_EPOCH=$(echo "$START_TIME_LINE" | grep -oP 'FETCHING START TIME IS \K\d+')
    else
        sleep 1
    fi
done

echo "Start time found: $START_EPOCH (Unix timestamp)"

echo "Monitoring tokens processing..."

# Periodically check if all relevant tokens have been cataloged or skipped
while true; do
    # Execute the SQL count command and get the result
    TOKEN_COUNT_REMAINING=$(psql -A -t -q -X -c "$SQL_COUNT_UNCATALOGED" | tr -d '[:space:]')

    echo "Tokens remaining: $TOKEN_COUNT_REMAINING"

    if [ "$TOKEN_COUNT_REMAINING" -eq 0 ]; then
        # All relevant tokens have been cataloged or skipped
        END_EPOCH=$(date +"%s")
        break
    else
        sleep 1
    fi
done

echo "End time: $END_EPOCH (Unix timestamp)"

# Calculate the total processing time in seconds
TOTAL_TIME=$((END_EPOCH - START_EPOCH))

# Convert total time to hours, minutes, and seconds
HOURS=$((TOTAL_TIME / 3600))
MINUTES=$(((TOTAL_TIME % 3600) / 60))
SECONDS=$((TOTAL_TIME % 60))

echo "Total processing time: $HOURS hours, $MINUTES minutes, $SECONDS seconds"

# Stop the fetcher process
kill $FETCHER_PID
