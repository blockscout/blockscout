const { User } = require('../models');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

// @desc    Get all users
// @route   GET /api/users
// @access  Private (admin only)
exports.getUsers = async (req, res, next) => {
  try {
    // Get all users except the current user
    const users = await User.findAll({
      where: {
        id: {
          [sequelize.Op.ne]: req.user.id
        }
      },
      attributes: { exclude: ['password'] }
    });
    
    res.json(users);
  } catch (error) {
    logger.error('Get users error:', error);
    next(error);
  }
};

// @desc    Get user by ID
// @route   GET /api/users/:id
// @access  Private (admin only)
exports.getUserById = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id, {
      attributes: { exclude: ['password'] }
    });
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    res.json(user);
  } catch (error) {
    logger.error('Get user by ID error:', error);
    next(error);
  }
};

// @desc    Create a new user
// @route   POST /api/users
// @access  Private (admin only)
exports.createUser = async (req, res, next) => {
  try {
    const { email, username, password, role } = req.body;
    
    // Validate input
    if (!email || !username || !password) {
      return res.status(400).json({ 
        message: 'Please provide email, username, and password' 
      });
    }
    
    // Check if user already exists
    const existingUser = await User.findOne({ where: { email } });
    
    if (existingUser) {
      return res.status(409).json({ message: 'User with this email already exists' });
    }
    
    // Create new user
    const user = await User.create({
      email,
      username,
      password,
      role: role || 'viewer'
    });
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user.get({ plain: true });
    
    res.status(201).json(userWithoutPassword);
  } catch (error) {
    logger.error('Create user error:', error);
    next(error);
  }
};

// @desc    Update user
// @route   PUT /api/users/:id
// @access  Private (admin only)
exports.updateUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Prevent admin from disabling their own account
    if (user.id === req.user.id && req.body.isActive === false) {
      return res.status(400).json({ 
        message: 'You cannot disable your own account' 
      });
    }
    
    // Update fields
    const { username, email, role, isActive } = req.body;
    
    if (username) user.username = username;
    if (email) user.email = email;
    if (role) user.role = role;
    if (isActive !== undefined) user.isActive = isActive;
    
    // If password is provided, hash it
    if (req.body.password) {
      const salt = await bcrypt.genSalt(10);
      user.password = await bcrypt.hash(req.body.password, salt);
    }
    
    await user.save();
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user.get({ plain: true });
    
    res.json(userWithoutPassword);
  } catch (error) {
    logger.error('Update user error:', error);
    next(error);
  }
};

// @desc    Delete user
// @route   DELETE /api/users/:id
// @access  Private (admin only)
exports.deleteUser = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.params.id);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Prevent admin from deleting their own account
    if (user.id === req.user.id) {
      return res.status(400).json({ 
        message: 'You cannot delete your own account' 
      });
    }
    
    await user.destroy();
    
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    logger.error('Delete user error:', error);
    next(error);
  }
};
