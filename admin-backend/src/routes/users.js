const express = require('express');
const router = express.Router();
const { 
  getUsers, 
  getUserById, 
  createUser, 
  updateUser, 
  deleteUser 
} = require('../controllers/users');
const { authorize } = require('../middleware/auth');

// @route   GET /api/users
// @desc    Get all users
// @access  Private (admin only)
router.get('/', authorize('admin'), getUsers);

// @route   GET /api/users/:id
// @desc    Get user by ID
// @access  Private (admin only)
router.get('/:id', authorize('admin'), getUserById);

// @route   POST /api/users
// @desc    Create a new user
// @access  Private (admin only)
router.post('/', authorize('admin'), createUser);

// @route   PUT /api/users/:id
// @desc    Update user
// @access  Private (admin only)
router.put('/:id', authorize('admin'), updateUser);

// @route   DELETE /api/users/:id
// @desc    Delete user
// @access  Private (admin only)
router.delete('/:id', authorize('admin'), deleteUser);

module.exports = router;
