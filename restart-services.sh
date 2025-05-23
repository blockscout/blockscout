#!/bin/bash

# Script per riavviare i servizi admin-frontend e admin-backend
# e applicare le modifiche alla configurazione

echo "=== Riavvio servizi Admin Panel ==="
echo ""

# Verifica configurazione JWT nel backend
if grep -q "JWT_SECRET" /Users/jacopomosconi/UOMI-Project/uomi-explorer/admin-backend/.env; then
  echo "✅ JWT_SECRET configurato nel backend"
else
  echo "⚠️ JWT_SECRET non trovato nel file .env del backend!"
  echo "Aggiungiamo la configurazione JWT_SECRET..."
  echo "JWT_SECRET=BlockscoutAdminSecretFIRVBxO03lrrZ5RWnhbBdEHYwN" >> /Users/jacopomosconi/UOMI-Project/uomi-explorer/admin-backend/.env
  echo "✅ JWT_SECRET aggiunto nel file .env del backend"
fi

# Riavvio del backend
echo ""
echo "Riavvio del servizio admin-backend..."
cd /Users/jacopomosconi/UOMI-Project/uomi-explorer/admin-backend
npm run dev &
BACKEND_PID=$!
echo "✅ admin-backend avviato (PID: $BACKEND_PID)"

# Riavvio del frontend
echo ""
echo "Riavvio del servizio admin-frontend..."
cd /Users/jacopomosconi/UOMI-Project/uomi-explorer/admin-frontend
npm run dev &
FRONTEND_PID=$!
echo "✅ admin-frontend avviato (PID: $FRONTEND_PID)"

echo ""
echo "=== Servizi riavviati con successo ==="
echo "admin-backend: http://localhost:4010"
echo "admin-frontend: http://localhost:3010"
echo ""
echo "Per fermare i servizi, esegui:"
echo "kill $BACKEND_PID $FRONTEND_PID"
