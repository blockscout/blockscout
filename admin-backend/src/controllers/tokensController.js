const { Pool } = require('pg');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const config = require('../config/config');

const pool = new Pool(config.db);

// Configurazione per l'upload delle immagini
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '../../uploads/token-icons');
    // Assicurati che la cartella esista
    if (!fs.existsSync(uploadDir)){
        fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueFilename = `${uuidv4()}${path.extname(file.originalname)}`;
    cb(null, uniqueFilename);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // Limite di 5MB
  fileFilter: function (req, file, cb) {
    // Accetta solo immagini
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Solo file immagine sono consentiti!'));
    }
    cb(null, true);
  }
});

// Helper per convertire l'indirizzo bytea in un formato esadecimale
function bytesToHex(bytes) {
  // Rimuovi il prefisso \x se presente
  if (typeof bytes === 'string' && bytes.startsWith('\\x')) {
    return '0x' + bytes.substring(2);
  }
  // Se già in formato stringa esadecimale, restituisci così com'è
  return bytes;
}

// Helper per convertire un indirizzo hex in formato bytea Postgres
function hexToBytes(hex) {
  if (hex.startsWith('0x')) {
    return '\\x' + hex.substring(2);
  }
  return '\\x' + hex;
}

// Ottieni la lista dei token con paginazione e filtri
exports.getTokens = async (req, res) => {
  try {
    const { page = 1, limit = 10, search = '', type = '', sortBy = 'updated_at', sortOrder = 'DESC' } = req.query;
    const offset = (page - 1) * limit;
    
    let queryParams = [];
    let queryText = `
      SELECT 
        t.contract_address_hash, 
        encode(t.contract_address_hash, 'hex') as address,
        t.name, 
        t.symbol, 
        t.total_supply, 
        t.decimals, 
        t.type,
        t.holder_count,
        t.icon_url,
        t.is_verified_via_admin_panel,
        t.updated_at
      FROM tokens t
      WHERE 1=1
    `;
    
    // Aggiunta filtri di ricerca
    if (search) {
      queryText += ` AND (t.name ILIKE $${queryParams.length + 1} OR t.symbol ILIKE $${queryParams.length + 1} OR encode(t.contract_address_hash, 'hex') ILIKE $${queryParams.length + 1})`;
      queryParams.push(`%${search}%`);
    }
    
    if (type) {
      queryText += ` AND t.type = $${queryParams.length + 1}`;
      queryParams.push(type);
    }
    
    // Conteggio totale per la paginazione
    const countResult = await pool.query(`SELECT COUNT(*) FROM tokens t WHERE 1=1 ${search ? ` AND (t.name ILIKE $1 OR t.symbol ILIKE $1 OR encode(t.contract_address_hash, 'hex') ILIKE $1)` : ''} ${type ? (search ? ` AND t.type = $2` : ` AND t.type = $1`) : ''}`, search ? (type ? [search, type] : [search]) : (type ? [type] : []));
    
    // Query principale con ordinamento e paginazione
    queryText += ` ORDER BY ${sortBy} ${sortOrder} LIMIT $${queryParams.length + 1} OFFSET $${queryParams.length + 2}`;
    queryParams.push(parseInt(limit), parseInt(offset));
    
    const result = await pool.query(queryText, queryParams);
    
    res.json({
      tokens: result.rows,
      pagination: {
        total: parseInt(countResult.rows[0].count),
        currentPage: parseInt(page),
        totalPages: Math.ceil(parseInt(countResult.rows[0].count) / limit),
        limit: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Errore nel recupero dei token:', error);
    res.status(500).json({ error: 'Errore nel recupero dei token', details: error.message });
  }
};

// Ottieni un singolo token per indirizzo
exports.getTokenByAddress = async (req, res) => {
  try {
    const { address } = req.params;
    const bytesAddress = hexToBytes(address);
    
    const query = `
      SELECT 
        t.contract_address_hash, 
        encode(t.contract_address_hash, 'hex') as address,
        t.name, 
        t.symbol, 
        t.total_supply, 
        t.decimals, 
        t.type,
        t.cataloged,
        t.holder_count,
        t.skip_metadata,
        t.fiat_value,
        t.circulating_market_cap,
        t.icon_url,
        t.is_verified_via_admin_panel,
        t.updated_at
      FROM tokens t
      WHERE t.contract_address_hash = $1
    `;
    
    const result = await pool.query(query, [bytesAddress]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Token non trovato' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Errore nel recupero del token:', error);
    res.status(500).json({ error: 'Errore nel recupero del token', details: error.message });
  }
};

// Aggiorna un token
exports.updateToken = async (req, res) => {
  try {
    const { address } = req.params;
    const { name, symbol, is_verified_via_admin_panel, skip_metadata } = req.body;
    const bytesAddress = hexToBytes(address);
    
    // Prepara le colonne da aggiornare
    const updateColumns = [];
    const values = [bytesAddress]; // Il primo parametro è sempre l'indirizzo
    let paramCounter = 2; // Iniziamo da 2 perché l'indirizzo è $1
    
    if (name !== undefined) {
      updateColumns.push(`name = $${paramCounter++}`);
      values.push(name);
    }
    
    if (symbol !== undefined) {
      updateColumns.push(`symbol = $${paramCounter++}`);
      values.push(symbol);
    }
    
    if (is_verified_via_admin_panel !== undefined) {
      updateColumns.push(`is_verified_via_admin_panel = $${paramCounter++}`);
      values.push(is_verified_via_admin_panel);
    }
    
    if (skip_metadata !== undefined) {
      updateColumns.push(`skip_metadata = $${paramCounter++}`);
      values.push(skip_metadata);
    }
    
    // Se c'è stato un caricamento di file nella richiesta
    if (req.file) {
      const iconUrl = `/uploads/token-icons/${req.file.filename}`;
      updateColumns.push(`icon_url = $${paramCounter++}`);
      values.push(iconUrl);
    }
    
    // Aggiungi sempre updated_at
    updateColumns.push(`updated_at = NOW()`);
    
    if (updateColumns.length === 0) {
      return res.status(400).json({ error: 'Nessun campo da aggiornare fornito' });
    }
    
    const query = `
      UPDATE tokens
      SET ${updateColumns.join(', ')}
      WHERE contract_address_hash = $1
      RETURNING 
        contract_address_hash, 
        encode(contract_address_hash, 'hex') as address,
        name, 
        symbol, 
        icon_url, 
        is_verified_via_admin_panel,
        skip_metadata,
        updated_at
    `;
    
    const result = await pool.query(query, values);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Token non trovato' });
    }
    
    res.json({
      message: 'Token aggiornato con successo',
      token: result.rows[0]
    });
  } catch (error) {
    console.error('Errore nell\'aggiornamento del token:', error);
    res.status(500).json({ error: 'Errore nell\'aggiornamento del token', details: error.message });
  }
};

// Middleware per gestire l'upload delle immagini
exports.uploadTokenIcon = upload.single('icon');

// Ottieni statistiche sui token
exports.getTokenStats = async (req, res) => {
  try {
    const statsQuery = `
      SELECT 
        COUNT(*) as total_tokens,
        COUNT(CASE WHEN icon_url IS NOT NULL THEN 1 END) as tokens_with_icons,
        COUNT(CASE WHEN is_verified_via_admin_panel = true THEN 1 END) as verified_tokens,
        COUNT(DISTINCT type) as token_types,
        MAX(updated_at) as last_updated
      FROM tokens
    `;
    
    const typeDistributionQuery = `
      SELECT 
        type, 
        COUNT(*) as count 
      FROM tokens 
      GROUP BY type 
      ORDER BY count DESC
    `;
    
    const recentTokensQuery = `
      SELECT 
        encode(contract_address_hash, 'hex') as address,
        name, 
        symbol, 
        type,
        icon_url,
        inserted_at
      FROM tokens
      ORDER BY inserted_at DESC
      LIMIT 5
    `;
    
    const [statsResult, typeDistResult, recentTokensResult] = await Promise.all([
      pool.query(statsQuery),
      pool.query(typeDistributionQuery),
      pool.query(recentTokensQuery)
    ]);
    
    res.json({
      stats: statsResult.rows[0],
      typeDistribution: typeDistResult.rows,
      recentTokens: recentTokensResult.rows
    });
  } catch (error) {
    console.error('Errore nel recupero delle statistiche dei token:', error);
    res.status(500).json({ error: 'Errore nel recupero delle statistiche dei token', details: error.message });
  }
};
