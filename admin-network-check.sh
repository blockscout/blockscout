#!/bin/zsh

# Admin Panel Docker Network Diagnostics

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}Admin Panel Network Diagnostics${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}Error: Docker is not running or you don't have permissions.${NC}"
  echo "Please start Docker and try again, or run with sudo if needed."
  exit 1
fi

# Check if admin containers are running
echo -e "${YELLOW}Checking container status...${NC}"
BACKEND_RUNNING=$(docker ps -q -f name=admin-backend)
FRONTEND_RUNNING=$(docker ps -q -f name=admin-frontend)

if [[ -z "$BACKEND_RUNNING" ]]; then
  echo -e "${RED}❌ admin-backend container is not running${NC}"
else
  echo -e "${GREEN}✅ admin-backend container is running${NC}"
fi

if [[ -z "$FRONTEND_RUNNING" ]]; then
  echo -e "${RED}❌ admin-frontend container is not running${NC}"
else
  echo -e "${GREEN}✅ admin-frontend container is running${NC}"
fi

echo ""

# Check Docker networks
echo -e "${YELLOW}Checking Docker networks...${NC}"
if docker network ls | grep -q "admin-network"; then
  echo -e "${GREEN}✅ admin-network exists${NC}"
else
  echo -e "${RED}❌ admin-network does not exist${NC}"
fi

if docker network ls | grep -q "blockscout-network"; then
  echo -e "${GREEN}✅ blockscout-network exists${NC}"
else
  echo -e "${YELLOW}⚠️ blockscout-network does not exist. This may be OK if you're testing in isolation.${NC}"
fi

echo ""

# If containers are running, check connectivity
if [[ ! -z "$BACKEND_RUNNING" && ! -z "$FRONTEND_RUNNING" ]]; then
  echo -e "${YELLOW}Testing network connectivity...${NC}"
  
  # Check backend health endpoint
  echo -e "Testing backend health endpoint from host:"
  if curl -s http://localhost:4010/health > /dev/null; then
    echo -e "${GREEN}✅ Backend health endpoint accessible from host${NC}"
  else
    echo -e "${RED}❌ Backend health endpoint not accessible from host${NC}"
  fi
  
  # Check connectivity between containers
  echo -e "Testing connectivity from frontend to backend:"
  if docker exec admin-frontend wget -q -O- http://admin-backend:4010/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Frontend can connect to backend${NC}"
  else
    echo -e "${RED}❌ Frontend cannot connect to backend${NC}"
  fi
  
  # Check database connectivity
  echo -e "Testing backend connection to database:"
  if docker exec admin-backend curl -s http://localhost:4010/api/auth/status > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend can connect to database${NC}"
  else
    echo -e "${YELLOW}⚠️ Could not verify database connection${NC}"
  fi
fi

echo ""
echo -e "${GREEN}Diagnostics complete!${NC}"

# Show help if there are problems
if [[ -z "$BACKEND_RUNNING" || -z "$FRONTEND_RUNNING" ]]; then
  echo ""
  echo -e "${YELLOW}Suggestions:${NC}"
  echo "1. Start the containers with: ./admin-panel.sh start"
  echo "2. Check container logs with: ./admin-panel.sh logs"
  echo "3. Rebuild containers with: ./admin-panel.sh build"
fi
