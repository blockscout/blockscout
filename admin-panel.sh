#!/bin/zsh

# Admin Panel Docker Helper Script

# Change to the docker-compose directory
cd "$(dirname "$0")/docker-compose"

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
  echo -e "${YELLOW}Usage:${NC}"
  echo "  $0 [command]"
  echo ""
  echo -e "${YELLOW}Commands:${NC}"
  echo "  start       - Start the admin panel services"
  echo "  stop        - Stop the admin panel services"
  echo "  restart     - Restart the admin panel services"
  echo "  build       - Rebuild the admin panel services"
  echo "  deps        - Update dependencies and rebuild"
  echo "  logs        - View logs from the admin panel services"
  echo "  status      - Check status of the admin panel services"
  echo "  clean       - Remove all containers and volumes"
  echo ""
}

# Show header
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}UOMI Explorer Admin Panel Tool${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""

# Check if command is provided
if [[ $# -eq 0 ]]; then
  show_usage
  exit 1
fi

# Process command
case "$1" in
  start)
    echo -e "${GREEN}Starting Admin Panel services...${NC}"
    docker-compose -f admin-compose.yml up -d
    echo -e "${GREEN}Services started!${NC}"
    echo -e "Backend URL: ${YELLOW}http://localhost:4010${NC}"
    echo -e "Frontend URL: ${YELLOW}http://localhost:3010${NC}"
    ;;
    
  stop)
    echo -e "${GREEN}Stopping Admin Panel services...${NC}"
    docker-compose -f admin-compose.yml down
    echo -e "${GREEN}Services stopped!${NC}"
    ;;
    
  restart)
    echo -e "${GREEN}Restarting Admin Panel services...${NC}"
    docker-compose -f admin-compose.yml down
    docker-compose -f admin-compose.yml up -d
    echo -e "${GREEN}Services restarted!${NC}"
    ;;
    
  build)
    echo -e "${GREEN}Rebuilding Admin Panel services...${NC}"
    docker-compose -f admin-compose.yml build --no-cache
    docker-compose -f admin-compose.yml up -d
    echo -e "${GREEN}Services rebuilt and started!${NC}"
    ;;
    
  deps)
    echo -e "${GREEN}Updating dependencies and rebuilding...${NC}"
    
    # Update frontend dependencies
    echo -e "${YELLOW}Installing frontend dependencies...${NC}"
    cd "../admin-frontend"
    npm install chart.js@4 --save
    npm install
    
    # Update backend dependencies
    echo -e "${YELLOW}Installing backend dependencies...${NC}"
    cd "../admin-backend"
    npm install
    
    # Go back and rebuild
    cd "../docker-compose"
    echo -e "${YELLOW}Rebuilding Docker containers...${NC}"
    docker-compose -f admin-compose.yml build --no-cache
    docker-compose -f admin-compose.yml up -d
    
    echo -e "${GREEN}Dependencies updated and services rebuilt!${NC}"
    ;;
    
  logs)
    echo -e "${GREEN}Showing logs for Admin Panel services...${NC}"
    docker-compose -f admin-compose.yml logs -f
    ;;
    
  status)
    echo -e "${GREEN}Admin Panel services status:${NC}"
    docker-compose -f admin-compose.yml ps
    ;;
    
  clean)
    echo -e "${YELLOW}WARNING: This will remove all Admin Panel containers and volumes.${NC}"
    read -p "Are you sure you want to continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${GREEN}Cleaning up Admin Panel services...${NC}"
      docker-compose -f admin-compose.yml down -v --remove-orphans
      echo -e "${GREEN}Cleanup complete!${NC}"
    else
      echo -e "${YELLOW}Operation cancelled.${NC}"
    fi
    ;;
    
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    show_usage
    exit 1
    ;;
esac

exit 0
