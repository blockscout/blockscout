const { Pool } = require('pg');
const config = require('../config/config');
const logger = require('../utils/logger');

const pool = new Pool(config.db);

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

// Ottieni tutti i tag disponibili
exports.getAllTags = async (req, res) => {
  try {
    const query = `
      SELECT 
        id, 
        label, 
        display_name,
        inserted_at,
        updated_at
      FROM address_tags
      ORDER BY display_name ASC
    `;
    
    const result = await pool.query(query);
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Errore nel recupero dei tag degli indirizzi:', error);
    res.status(500).json({ 
      error: 'Errore nel recupero dei tag degli indirizzi', 
      details: error.message 
    });
  }
};

// Ottieni un singolo tag per ID
exports.getTagById = async (req, res) => {
  try {
    const { id } = req.params;
    
    const query = `
      SELECT 
        id, 
        label, 
        display_name,
        inserted_at,
        updated_at
      FROM address_tags
      WHERE id = $1
    `;
    
    const result = await pool.query(query, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tag non trovato' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    logger.error('Errore nel recupero del tag:', error);
    res.status(500).json({ 
      error: 'Errore nel recupero del tag', 
      details: error.message 
    });
  }
};

// Crea un nuovo tag
exports.createTag = async (req, res) => {
  try {
    const { label, display_name } = req.body;
    
    if (!label || !display_name) {
      return res.status(400).json({ 
        error: 'I campi label e display_name sono obbligatori' 
      });
    }
    
    const query = `
      INSERT INTO address_tags (label, display_name, inserted_at, updated_at)
      VALUES ($1, $2, NOW(), NOW())
      RETURNING id, label, display_name, inserted_at, updated_at
    `;
    
    const result = await pool.query(query, [label, display_name]);
    
    res.status(201).json({
      message: 'Tag creato con successo',
      tag: result.rows[0]
    });
  } catch (error) {
    logger.error('Errore nella creazione del tag:', error);
    res.status(500).json({ 
      error: 'Errore nella creazione del tag', 
      details: error.message 
    });
  }
};

// Aggiorna un tag esistente
exports.updateTag = async (req, res) => {
  try {
    const { id } = req.params;
    const { label, display_name } = req.body;
    
    if (!label && !display_name) {
      return res.status(400).json({ 
        error: 'Devi fornire almeno un campo da aggiornare' 
      });
    }
    
    let query = 'UPDATE address_tags SET updated_at = NOW()';
    const queryParams = [];
    
    if (label) {
      queryParams.push(label);
      query += `, label = $${queryParams.length}`;
    }
    
    if (display_name) {
      queryParams.push(display_name);
      query += `, display_name = $${queryParams.length}`;
    }
    
    queryParams.push(id);
    query += ` WHERE id = $${queryParams.length} RETURNING id, label, display_name, inserted_at, updated_at`;
    
    const result = await pool.query(query, queryParams);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tag non trovato' });
    }
    
    res.json({
      message: 'Tag aggiornato con successo',
      tag: result.rows[0]
    });
  } catch (error) {
    logger.error('Errore nell\'aggiornamento del tag:', error);
    res.status(500).json({ 
      error: 'Errore nell\'aggiornamento del tag', 
      details: error.message 
    });
  }
};

// Elimina un tag
exports.deleteTag = async (req, res) => {
  try {
    const { id } = req.params;
    
    // Prima rimuovi tutte le associazioni in address_to_tags
    await pool.query('DELETE FROM address_to_tags WHERE tag_id = $1', [id]);
    
    // Poi rimuovi il tag
    const result = await pool.query('DELETE FROM address_tags WHERE id = $1 RETURNING id', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tag non trovato' });
    }
    
    res.json({
      message: 'Tag eliminato con successo',
      id: result.rows[0].id
    });
  } catch (error) {
    logger.error('Errore nell\'eliminazione del tag:', error);
    res.status(500).json({ 
      error: 'Errore nell\'eliminazione del tag', 
      details: error.message 
    });
  }
};

// Ottieni tutti gli indirizzi con tag
exports.getAddressesWithTags = async (req, res) => {
  try {
    const { page = 1, limit = 10, search = '' } = req.query;
    const offset = (page - 1) * limit;
    
    let queryText = `
      SELECT 
        encode(a.hash, 'hex') as address,
        a.transactions_count,
        a.token_transfers_count,
        a.fetched_coin_balance,
        ARRAY_AGG(json_build_object(
          'id', t.id,
          'label', t.label,
          'display_name', t.display_name
        )) as tags
      FROM addresses a
      JOIN address_to_tags att ON a.hash = att.address_hash
      JOIN address_tags t ON att.tag_id = t.id
    `;
    
    if (search) {
      queryText += ` WHERE encode(a.hash, 'hex') ILIKE $1`;
    }
    
    queryText += `
      GROUP BY a.hash, a.transactions_count, a.token_transfers_count, a.fetched_coin_balance
      ORDER BY a.transactions_count DESC
      LIMIT $${search ? 2 : 1} OFFSET $${search ? 3 : 2}
    `;
    
    // Conteggio totale per la paginazione
    let countQuery = `
      SELECT COUNT(DISTINCT a.hash) 
      FROM addresses a
      JOIN address_to_tags att ON a.hash = att.address_hash
      JOIN address_tags t ON att.tag_id = t.id
    `;
    
    if (search) {
      countQuery += ` WHERE encode(a.hash, 'hex') ILIKE $1`;
    }
    
    const params = search ? [`%${search}%`, parseInt(limit), parseInt(offset)] : [parseInt(limit), parseInt(offset)];
    const countParams = search ? [`%${search}%`] : [];
    
    const [result, countResult] = await Promise.all([
      pool.query(queryText, params),
      pool.query(countQuery, countParams)
    ]);
    
    // Formatta gli indirizzi
    const addressesWithTags = result.rows.map(row => ({
      ...row,
      address: '0x' + row.address,
      tags: row.tags.filter(tag => tag !== null) // Rimuove eventuali tag null
    }));
    
    res.json({
      addresses: addressesWithTags,
      pagination: {
        total: parseInt(countResult.rows[0].count),
        currentPage: parseInt(page),
        totalPages: Math.ceil(parseInt(countResult.rows[0].count) / limit),
        limit: parseInt(limit)
      }
    });
  } catch (error) {
    logger.error('Errore nel recupero degli indirizzi con tag:', error);
    res.status(500).json({ 
      error: 'Errore nel recupero degli indirizzi con tag', 
      details: error.message 
    });
  }
};

// Ottieni i tag associati a un indirizzo specifico
exports.getAddressTags = async (req, res) => {
  try {
    const { address } = req.params;
    const bytesAddress = hexToBytes(address);
    
    const query = `
      SELECT 
        t.id,
        t.label,
        t.display_name,
        t.inserted_at,
        t.updated_at
      FROM address_tags t
      JOIN address_to_tags att ON t.id = att.tag_id
      WHERE att.address_hash = $1
      ORDER BY t.display_name ASC
    `;
    
    const result = await pool.query(query, [bytesAddress]);
    
    res.json(result.rows);
  } catch (error) {
    logger.error('Errore nel recupero dei tag dell\'indirizzo:', error);
    res.status(500).json({ 
      error: 'Errore nel recupero dei tag dell\'indirizzo', 
      details: error.message 
    });
  }
};

// Associa un tag a un indirizzo
exports.addTagToAddress = async (req, res) => {
  try {
    const { address } = req.params;
    const { tag_id } = req.body;
    
    if (!tag_id) {
      return res.status(400).json({ 
        error: 'Il campo tag_id è obbligatorio' 
      });
    }
    
    const bytesAddress = hexToBytes(address);
    
    // Verifica che l'indirizzo esista
    const addressExists = await pool.query('SELECT hash FROM addresses WHERE hash = $1', [bytesAddress]);
    
    if (addressExists.rows.length === 0) {
      return res.status(404).json({ error: 'Indirizzo non trovato' });
    }
    
    // Verifica che il tag esista
    const tagExists = await pool.query('SELECT id FROM address_tags WHERE id = $1', [tag_id]);
    
    if (tagExists.rows.length === 0) {
      return res.status(404).json({ error: 'Tag non trovato' });
    }
    
    // Verifica se l'associazione esiste già
    const existingAssociation = await pool.query(
      'SELECT id FROM address_to_tags WHERE address_hash = $1 AND tag_id = $2',
      [bytesAddress, tag_id]
    );
    
    if (existingAssociation.rows.length > 0) {
      return res.status(409).json({ error: 'Il tag è già associato a questo indirizzo' });
    }
    
    // Crea l'associazione
    const query = `
      INSERT INTO address_to_tags (address_hash, tag_id, inserted_at, updated_at)
      VALUES ($1, $2, NOW(), NOW())
      RETURNING id
    `;
    
    const result = await pool.query(query, [bytesAddress, tag_id]);
    
    // Recupera il dettaglio completo del tag
    const tagDetails = await pool.query(
      'SELECT id, label, display_name FROM address_tags WHERE id = $1',
      [tag_id]
    );
    
    res.status(201).json({
      message: 'Tag associato all\'indirizzo con successo',
      association_id: result.rows[0].id,
      tag: tagDetails.rows[0],
      address: '0x' + address.replace(/^0x/, '')
    });
  } catch (error) {
    logger.error('Errore nell\'associazione del tag all\'indirizzo:', error);
    res.status(500).json({ 
      error: 'Errore nell\'associazione del tag all\'indirizzo', 
      details: error.message 
    });
  }
};

// Rimuove un tag da un indirizzo
exports.removeTagFromAddress = async (req, res) => {
  try {
    const { address, tag_id } = req.params;
    const bytesAddress = hexToBytes(address);
    
    const result = await pool.query(
      'DELETE FROM address_to_tags WHERE address_hash = $1 AND tag_id = $2 RETURNING id',
      [bytesAddress, tag_id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Associazione tag-indirizzo non trovata' 
      });
    }
    
    res.json({
      message: 'Tag rimosso dall\'indirizzo con successo',
      address: '0x' + address.replace(/^0x/, ''),
      tag_id: parseInt(tag_id)
    });
  } catch (error) {
    logger.error('Errore nella rimozione del tag dall\'indirizzo:', error);
    res.status(500).json({ 
      error: 'Errore nella rimozione del tag dall\'indirizzo', 
      details: error.message 
    });
  }
};

// Statistiche sui tag
exports.getTagStats = async (req, res) => {
  try {
    // Conteggio dei tag
    const tagCountQuery = 'SELECT COUNT(*) FROM address_tags';
    
    // Conteggio degli indirizzi taggati
    const addressCountQuery = 'SELECT COUNT(DISTINCT address_hash) FROM address_to_tags';
    
    // Tag più utilizzati
    const topTagsQuery = `
      SELECT 
        t.id,
        t.label, 
        t.display_name, 
        COUNT(att.address_hash) as usage_count
      FROM address_tags t
      JOIN address_to_tags att ON t.id = att.tag_id
      GROUP BY t.id, t.label, t.display_name
      ORDER BY usage_count DESC
      LIMIT 10
    `;
    
    // Indirizzi con più tag
    const topAddressesQuery = `
      SELECT 
        encode(a.hash, 'hex') as address,
        COUNT(att.tag_id) as tag_count
      FROM addresses a
      JOIN address_to_tags att ON a.hash = att.address_hash
      GROUP BY a.hash
      ORDER BY tag_count DESC
      LIMIT 10
    `;
    
    const [
      tagCountResult,
      addressCountResult,
      topTagsResult,
      topAddressesResult
    ] = await Promise.all([
      pool.query(tagCountQuery),
      pool.query(addressCountQuery),
      pool.query(topTagsQuery),
      pool.query(topAddressesQuery)
    ]);
    
    // Formatta gli indirizzi
    const topAddresses = topAddressesResult.rows.map(row => ({
      address: '0x' + row.address,
      tag_count: row.tag_count
    }));
    
    res.json({
      total_tags: parseInt(tagCountResult.rows[0].count),
      total_tagged_addresses: parseInt(addressCountResult.rows[0].count),
      top_tags: topTagsResult.rows,
      top_addresses: topAddresses
    });
  } catch (error) {
    logger.error('Errore nel recupero delle statistiche sui tag:', error);
    res.status(500).json({ 
      error: 'Errore nel recupero delle statistiche sui tag', 
      details: error.message 
    });
  }
};
