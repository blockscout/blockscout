# Sistema di Cache per Token JWT Auth0

## Introduzione

Questo documento descrive il sistema di cache per i token JWT implementato nel backend dell'admin panel per ridurre le chiamate all'API di Auth0 e prevenire il rate-limiting.

## Problema Risolto

Auth0 applica limiti di rate-limiting sulle API, inclusa l'API userinfo utilizzata per verificare i token JWT. Prima dell'implementazione della cache, ogni richiesta API che richiedeva autenticazione comportava una chiamata all'API di Auth0 per verificare il token JWT, portando rapidamente al raggiungimento del rate limit.

## Soluzione

È stato implementato un sistema di cache in-memory per i token JWT verificati. Questo riduce significativamente il numero di chiamate ad Auth0, consentendo di:

1. Verificare un token una sola volta
2. Memorizzare in cache il risultato della verifica per un periodo limitato (default: 15 minuti)
3. Riutilizzare la verifica per le richieste successive che utilizzano lo stesso token

## Implementazione

### File Chiave

- `src/utils/tokenCache.js`: Implementazione della cache dei token
- `src/middleware/auth0.js`: Middleware di autenticazione modificato per utilizzare la cache

### Come Funziona

1. **Prima chiamata con un nuovo token**:
   - Il token viene verificato con l'API Auth0
   - I dati utente vengono memorizzati nella cache insieme al token
   - La risposta viene restituita al client

2. **Chiamate successive con lo stesso token**:
   - Il sistema verifica se il token è presente nella cache e non è scaduto
   - Se presente, utilizza i dati memorizzati senza chiamare Auth0
   - Se assente o scaduto, segue il processo della prima chiamata

### Caratteristiche

- **Time-To-Live (TTL)**: I token in cache scadono dopo 15 minuti (configurabile)
- **Dimensione massima della cache**: Limite di 1000 token (configurabile)
- **Pulizia automatica**: Rimozione automatica dei token scaduti ogni 30 minuti
- **Algoritmo LRU**: Rimozione dei token meno utilizzati di recente quando la cache raggiunge la dimensione massima
- **Statistiche**: Monitoraggio di hit, miss e altre metriche per valutare l'efficacia

## Endpoint di Gestione

### Statistiche della Cache

```
GET /api/auth/cache-stats
```

Restituisce statistiche dettagliate sulla cache dei token:
- Numero di hit e miss
- Rapporto di hit
- Dimensione attuale e massima della cache
- Ultimo cleanup effettuato

### Invalidazione Cache

```
POST /api/auth/invalidate-cache
```

Permette di:
- Invalidare il token corrente (`?current=true`)
- Eseguire una pulizia completa della cache rimuovendo tutti i token scaduti

## Benefici

1. **Riduzione del Rate-Limiting**: Minor numero di chiamate ad Auth0
2. **Miglioramento delle Performance**: Risposte più veloci per le richieste autenticate
3. **Maggiore Resilienza**: Il sistema continua a funzionare anche in caso di problemi temporanei con Auth0

## Configurazione

La cache può essere configurata modificando i parametri nel costruttore in `src/utils/tokenCache.js`:

```javascript
{
  ttl: 15 * 60 * 1000,         // 15 minuti in millisecondi
  maxSize: 1000,               // Numero massimo di token in cache
  cleanupInterval: 30 * 60 * 1000  // Intervallo di pulizia (30 minuti)
}
```

## Sicurezza

La cache conserva solo i token e i dati utente associati, ed è mantenuta solo in memoria. Quando l'applicazione viene riavviata, la cache viene automaticamente svuotata. Inoltre, un token viene automaticamente invalidato alla scadenza del TTL o quando l'utente effettua il logout.
