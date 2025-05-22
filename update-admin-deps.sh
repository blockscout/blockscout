#!/bin/zsh

# Update dependencies for admin panel components
# This script installs/updates dependencies for both admin-backend and admin-frontend

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Show header
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}UOMI Explorer Dependency Tool${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""

# Change to project root dir
PROJECT_ROOT="$(dirname "$0")"
cd "$PROJECT_ROOT"

# Update Frontend Dependencies
echo -e "${YELLOW}Updating admin-frontend dependencies...${NC}"
cd "$PROJECT_ROOT/admin-frontend"

# Check if package.json exists
if [ ! -f "package.json" ]; then
  echo -e "${RED}Error: package.json not found in $(pwd)${NC}"
  echo "Make sure you're running this script from the project root directory."
  exit 1
fi

# Install chart.js and other dependencies
echo -e "Installing chart.js and other dependencies..."
npm install chart.js@4 --save
npm install
echo -e "${GREEN}✅ Frontend dependencies installed${NC}"

# Update Backend Dependencies
echo -e "\n${YELLOW}Updating admin-backend dependencies...${NC}"
cd "$PROJECT_ROOT/admin-backend"

# Check if package.json exists
if [ ! -f "package.json" ]; then
  echo -e "${RED}Error: package.json not found in $(pwd)${NC}"
  echo "Make sure you're running this script from the project root directory."
  exit 1
fi

echo -e "Installing backend dependencies..."
npm install
echo -e "${GREEN}✅ Backend dependencies installed${NC}"

echo -e "\n${GREEN}All dependencies successfully updated!${NC}"
echo ""
echo -e "You can now start the services:"
echo -e "  Backend: ${YELLOW}cd admin-backend && npm start${NC}"
echo -e "  Frontend: ${YELLOW}cd admin-frontend && npm run dev${NC}"
echo ""
echo -e "Or use Docker: ${YELLOW}./admin-panel.sh start${NC}"
