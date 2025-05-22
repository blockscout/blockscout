const express = require('express');
const router = express.Router();
const { getBlocks, getBlockById } = require('../controllers/blocks');

// @route   GET /api/blocks
// @desc    Get all blocks with pagination
// @access  Private
router.get('/', getBlocks);

// @route   GET /api/blocks/:number
// @desc    Get block by number
// @access  Private
router.get('/:number', getBlockById);

module.exports = router;
