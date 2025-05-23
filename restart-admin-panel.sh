#!/bin/zsh

# Script per avviare o riavviare i servizi admin (frontend e backend)
echo "🚀 Riavvio del pannello amministrativo UOMI Explorer"

# Directory corrente
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR" || exit

# Ferma eventuali processi esistenti
echo "🛑 Arresto di eventuali processi esistenti..."
pkill -f "node.*admin-backend" 2>/dev/null
pkill -f "node.*admin-frontend" 2>/dev/null
pkill -f "next.*start" 2>/dev/null
pkill -f "next.*dev" 2>/dev/null

# Attendiamo che tutti i processi vengano terminati
echo "⏳ Attesa terminazione processi..."
sleep 3

# Pulisci eventuali cache di Next.js
echo "🧹 Pulizia cache Next.js..."
rm -rf admin-frontend/.next/cache/* 2>/dev/null

# Rimuovi i vecchi file di log se esistono
rm -f admin-frontend.log admin-backend.log

# Verifica che i file di configurazione siano presenti
if [ ! -f admin-frontend/.env.local ]; then
  echo "⚠️ ATTENZIONE: File .env.local non trovato nel frontend!"
  echo "Verifica che il file di configurazione sia presente."
fi

if [ ! -f admin-backend/.env ]; then
  echo "⚠️ ATTENZIONE: File .env non trovato nel backend!"
  echo "Verifica che il file di configurazione sia presente."
fi

echo "📦 Controllo delle dipendenze..."

# Controlla e installa le dipendenze del backend
cd admin-backend || exit
if [ ! -d "node_modules" ]; then
  echo "🔧 Installazione dipendenze backend..."
  npm install
else
  echo "✅ Dipendenze backend già installate."
fi

# Avvia il backend
echo "🌐 Avvio del backend (porta 4010)..."
npm start > ../admin-backend.log 2>&1 &
BACKEND_PID=$!
echo "Backend avviato con PID: $BACKEND_PID"

# Controlla e installa le dipendenze del frontend
cd ../admin-frontend || exit
if [ ! -d "node_modules" ]; then
  echo "🔧 Installazione dipendenze frontend..."
  npm install
else
  echo "✅ Dipendenze frontend già installate."
fi

# Avvia il frontend
echo "🖥️ Avvio del frontend (porta 3010)..."
npm run dev > ../admin-frontend.log 2>&1 &
FRONTEND_PID=$!
echo "Frontend avviato con PID: $FRONTEND_PID"

cd ..
echo "📋 Salvato log del backend in: admin-backend.log"
echo "📋 Salvato log del frontend in: admin-frontend.log"

echo "✨ Pannello amministrativo avviato con successo!"
echo "📊 Admin dashboard: http://localhost:3010"
echo "🔌 API backend: http://localhost:4010"
echo ""
echo "Premi Ctrl+C per terminare i servizi"

# Gestione terminazione script
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; echo '👋 Servizi terminati.'; exit" INT TERM EXIT

# Mantieni lo script attivo per mostrare gli ultimi log
tail -f admin-backend.log admin-frontend.log
