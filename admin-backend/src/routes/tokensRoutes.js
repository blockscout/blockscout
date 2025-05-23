const express = require('express');
const router = express.Router();
const tokensController = require('../controllers/tokensController');
const authMiddleware = require('../middleware/auth0');

// // Applica il middleware di autenticazione a tutte le route
// router.use(authMiddleware);

// Route per ottenere statistiche sui token
router.get('/stats', tokensController.getTokenStats);

// Route per ottenere la lista dei token con paginazione e filtri
router.get('/', tokensController.getTokens);

// Route per ottenere un singolo token per indirizzo
router.get('/:address', tokensController.getTokenByAddress);

// Route per aggiornare un token, incluso l'upload dell'icona
router.put('/:address',authorize('admin'), tokensController.uploadTokenIcon, tokensController.updateToken);

module.exports = router;
