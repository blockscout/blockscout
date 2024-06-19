#!/bin/bash

# Check if a domain is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
SSH_USER=$2
SSH_KEY=$3

# Resolve A records
IP_LIST=$(dig +short A $DOMAIN)
if [ -z "$IP_LIST" ]; then
  echo "No IPs found for domain $DOMAIN"
  exit 1
fi

MIN_LA=1000000
BEST_BUILDER=""

for IP in $IP_LIST; do
  # Check if the host is reachable via SSH
  ssh -o StrictHostKeychecking=no -o ConnectTimeout=5 -o BatchMode=yes -i $SSH_KEY $SSH_USER@$IP "exit" 2>/dev/null
  if [ $? -eq 0 ]; then
    # Get the load average
    LA=$(ssh -o StrictHostKeychecking=no -i $SSH_KEY $SSH_USER@$IP "uptime | awk -F'load average:' '{ print \$2 }' | cut -d, -f1" 2>/dev/null)
    if [ $? -eq 0 ]; then
      # Compare and find the minimum load average
      LA=$(echo $LA | xargs) # Trim whitespace
      if (( $(echo "$LA < $MIN_LA" | bc -l) )); then
        MIN_LA=$LA
        BEST_BUILDER=$IP
      fi
    fi
  fi
done

if [ -n "$BEST_BUILDER" ]; then
  echo "$BEST_BUILDER" | tr -d '[:space:]'
else
  echo "No reachable hosts found."
fi
