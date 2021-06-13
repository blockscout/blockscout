#!/bin/bash
#
# Hyperledger Besu Private Network enode extracted
#
########################################################


function log_info()
{
  echo "[enode-extract-script] $1"
}

function log_error()
{
  log_info "ERROR: $1"
  exit 2
}

log_info "Starting to extract the enode from log"
rm -f /work/bootnode-enode.txt > /dev/null
for i in {1..60}
do
  grep -q "Enode URL" /opt/besu/besu.log && {
    grep "Enode URL" /opt/besu/besu.log | sed 's/.*Enode URL \(enode.*\)/\1/g' > /work/bootnode-enode.txt
    log_info "Extracted bootnode enode" 
    exit 0
  }

  log_info "Waiting..."
  sleep 1
done

# Exit with error
log_error "Could not retrieve bootnode enode"
