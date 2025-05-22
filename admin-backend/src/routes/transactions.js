const express = require('express');
const router = express.Router();
const { 
  getTransactions, 
  getTransactionById, 
  getRecentTransactions 
} = require('../controllers/transactions');

// @route   GET /api/transactions
// @desc    Get all transactions with pagination
// @access  Private
router.get('/', getTransactions);

// @route   GET /api/transactions/recent
// @desc    Get recent transactions
// @access  Private
router.get('/recent', getRecentTransactions);

// @route   GET /api/transactions/:hash
// @desc    Get transaction by hash
// @access  Private
router.get('/:hash', getTransactionById);

module.exports = router;
