#!/bin/bash

echo "Avvio del pannello di amministrazione con le configurazioni corrette..."

# Assicura che il file .env.admin venga usato
export $(cat .env.admin | xargs)

# Riavvia solo i servizi admin
cd docker-compose
docker-compose -f docker-compose.local.yml -f admin-compose.yml stop admin-backend admin-frontend
docker-compose -f docker-compose.local.yml -f admin-compose.yml rm -f admin-backend admin-frontend
docker-compose -f docker-compose.local.yml -f admin-compose.yml up -d admin-backend admin-frontend

echo "Servizi admin avviati!"
echo "Frontend: http://localhost:3010"
echo "Backend: http://localhost:4010"
echo ""
echo "NOTA: Per accedere senza backend, usa:"
echo "- Email: test@dev.com"
echo "- Codice OTP: 123456"