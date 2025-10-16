#!/bin/bash

echo "🏗️  Building and starting backend services..."
docker compose -f sepolia-backend-only.yml up --build -d

echo ""
echo "✅ Blockscout Backend Services are starting up!"
echo ""
echo "🔗 Backend API: http://localhost:4000"
echo "📊 Stats Service: http://localhost:8080"
echo "🎨 Visualizer: http://localhost:8081"
echo "🔍 Sig Provider: http://localhost:8082"
echo "👤 User Ops Indexer: http://localhost:8083"
echo ""
echo "📋 Service Status:"
docker compose -f sepolia-backend-only.yml ps



