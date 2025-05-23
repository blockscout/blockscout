/**
 * Classe per la cache dei token JWT Auth0 per evitare chiamate ripetute all'API Auth0
 * e prevenire il rate-limiting.
 */
class TokenCache {
  constructor(options = {}) {
    // Una map che memorizza i token e i relativi dati utente
    this.cache = new Map();
    
    // Durata predefinita della cache in millisecondi (15 minuti)
    this.ttl = options.ttl || 15 * 60 * 1000;
    
    // Dimensione massima della cache
    this.maxSize = options.maxSize || 1000;
    
    // Intervallo per la pulizia automatica (30 minuti)
    this.cleanupInterval = options.cleanupInterval || 30 * 60 * 1000;
    
    // Statistiche della cache
    this.stats = {
      hits: 0,
      misses: 0,
      sets: 0,
      invalidations: 0,
      lastCleanup: null
    };
    
    // Avvia la pulizia periodica della cache
    this.startCleanupInterval();
  }
  
  /**
   * Ottiene un utente dalla cache in base al token JWT
   * @param {string} token - Il token JWT da cercare
   * @returns {object|null} - I dati utente se presenti in cache, altrimenti null
   */
  get(token) {
    if (!token) return null;
    
    const cacheItem = this.cache.get(token);
    
    // Se il token non è in cache o è scaduto, restituisci null
    if (!cacheItem) {
      this.stats.misses++;
      return null;
    }
    
    // Controlla se il token è scaduto
    if (Date.now() > cacheItem.expiresAt) {
      this.cache.delete(token);
      this.stats.misses++;
      return null;
    }
    
    // Cache hit!
    this.stats.hits++;
    
    // Aggiorna il timestamp "last accessed" per l'algoritmo LRU
    cacheItem.lastAccessed = Date.now();
    
    return cacheItem.userData;
  }
  
  /**
   * Memorizza un utente nella cache in base al token JWT
   * @param {string} token - Il token JWT da memorizzare
   * @param {object} userData - I dati utente da associare al token
   */
  set(token, userData) {
    if (!token || !userData) return;
    
    // Se la cache ha raggiunto la dimensione massima, rimuovi i token meno usati recentemente
    if (this.cache.size >= this.maxSize) {
      this.evictLRU();
    }
    
    this.stats.sets++;
    
    this.cache.set(token, {
      userData,
      expiresAt: Date.now() + this.ttl,
      lastAccessed: Date.now()
    });
  }
  
  /**
   * Invalida un token specifico dalla cache
   * @param {string} token - Il token da invalidare
   */
  invalidate(token) {
    if (token) {
      if (this.cache.has(token)) {
        this.stats.invalidations++;
      }
      this.cache.delete(token);
    }
  }
  
  /**
   * Rimuove il token meno usato recentemente dalla cache (algoritmo LRU)
   */
  evictLRU() {
    if (this.cache.size === 0) return;
    
    let oldestAccess = Date.now();
    let oldestToken = null;
    
    // Trova il token con il timestamp "last accessed" più vecchio
    for (const [token, data] of this.cache.entries()) {
      if (data.lastAccessed < oldestAccess) {
        oldestAccess = data.lastAccessed;
        oldestToken = token;
      }
    }
    
    // Rimuovi il token più vecchio
    if (oldestToken) {
      this.cache.delete(oldestToken);
    }
  }
  
  /**
   * Rimuove tutti i token scaduti dalla cache
   */
  cleanup() {
    const now = Date.now();
    let removedCount = 0;
    
    for (const [token, data] of this.cache.entries()) {
      if (now > data.expiresAt) {
        this.cache.delete(token);
        removedCount++;
      }
    }
    
    this.stats.lastCleanup = {
      timestamp: now,
      removedCount: removedCount
    };
    
    return {
      removed: removedCount,
      remaining: this.cache.size
    };
  }
  
  /**
   * Avvia un intervallo per la pulizia automatica della cache
   */
  startCleanupInterval() {
    this.cleanupTimer = setInterval(() => {
      this.cleanup();
    }, this.cleanupInterval);
    
    // Assicurati che il timer non impedisca al processo di terminare
    if (this.cleanupTimer.unref) {
      this.cleanupTimer.unref();
    }
  }
  
  /**
   * Ferma l'intervallo di pulizia automatica
   */
  stopCleanupInterval() {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
    }
  }
  
  /**
   * Ottiene le statistiche correnti della cache
   * @returns {Object} Statistiche della cache
   */
  getStats() {
    return {
      ...this.stats,
      size: this.cache.size,
      maxSize: this.maxSize,
      ttlMs: this.ttl,
      hitRatio: this.stats.hits + this.stats.misses > 0 
        ? (this.stats.hits / (this.stats.hits + this.stats.misses)).toFixed(2)
        : 0
    };
  }
}

// Esporta un'istanza singleton della cache
module.exports = new TokenCache();
