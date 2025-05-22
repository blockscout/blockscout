const { DataTypes } = require('sequelize');
const bcrypt = require('bcryptjs');

module.exports = (sequelize) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true,
    },
    username: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true
    },
    password_hash: {
      type: DataTypes.STRING,
      allowNull: true // Can be null for Auth0 users
    },
    auth0_id: {
      type: DataTypes.STRING,
      allowNull: true
    },
    last_login: {
      type: DataTypes.DATE,
      allowNull: true
    }
  }, {
    tableName: 'users',
    timestamps: true,
    createdAt: 'inserted_at',
    updatedAt: 'updated_at'
  });

  // Method to check password
  User.prototype.checkPassword = async function(enteredPassword) {
    if (this.password_hash) {
      return await bcrypt.compare(enteredPassword, this.password_hash);
    }
    return false;
  };

  return User;
};
