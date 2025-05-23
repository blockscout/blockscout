const express = require('express');
const router = express.Router();
const { 
  getAllTags,
  getTagById,
  createTag,
  updateTag,
  deleteTag,
  getAddressesWithTags,
  getAddressTags,
  addTagToAddress,
  removeTagFromAddress,
  getTagStats
} = require('../controllers/addressTagsController');
const { 
  checkJwt,
  loadUserProfile,
  localAuthMiddleware,
  authorize
} = require('../middleware/auth0');

// Middleware di autenticazione per tutte le routes
router.use(checkJwt, loadUserProfile, localAuthMiddleware);

// Routes per i tag
router.get('/tags', getAllTags);
router.get('/tags/:id', getTagById);
router.post('/tags', authorize('admin'), createTag);
router.put('/tags/:id', authorize('admin'), updateTag);
router.delete('/tags/:id', authorize('admin'), deleteTag);

// Routes per le associazioni indirizzo-tag
router.get('/addresses', getAddressesWithTags);
router.get('/addresses/:address/tags', getAddressTags);
router.post('/addresses/:address/tags', authorize('admin'), addTagToAddress);
router.delete('/addresses/:address/tags/:tag_id', authorize('admin'), removeTagFromAddress);

// Statistiche
router.get('/stats', getTagStats);

module.exports = router;
